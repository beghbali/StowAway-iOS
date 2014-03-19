//
//  MeetCrewMapViewManager.m
//  StowAway
//
//  Created by Vin Pallen on 3/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "MeetCrewMapViewManager.h"
#import "StowawayConstants.h"
#import <CoreLocation/CoreLocation.h>
#import "PTPusherChannel.h"
#import "PTPusher.h"
#import "PTPusherEvent.h"
#import "Reachability.h"
#import "PTPusherErrors.h"
#import "PTPusherConnection.h"

@interface MeetCrewMapViewManager ()<CLLocationManagerDelegate, MKMapViewDelegate, PTPusherDelegate>

@property (strong, nonatomic) NSDictionary *suggestedLocations;

@property (strong, nonatomic) NSString * locationChannel;
@property (strong, nonatomic) PTPusher * pusher;

@property (weak, nonatomic) MKMapView * mapView;

@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew; //index 0 being self and upto 3, this class will also add the MKPointAnnotation; this is copy of the original so we can compare when crew changes

@property BOOL inAutoCheckinModeNow;

@property (nonatomic, strong) MKPointAnnotation * pickUpAnnotation;
@property (nonatomic, strong) MKPointAnnotation * dropOffAnnotation;

@property (strong, nonatomic) CLLocationManager * locationManager;

@property (strong, nonatomic) NSString *userID;
@property (strong, nonatomic) NSString *requestID;

@end


@implementation MeetCrewMapViewManager

//called anytime a stowaways gets updated
-(void)setCrew:(NSMutableArray *)newCrew
{
    //for the first time, just copy the crew
    if ( !self.crew )
    {
        self.crew = [NSMutableArray arrayWithArray:newCrew];
        
        //get self user id
        self.requestID = [[newCrew objectAtIndex:0]objectForKey:kRequestPublicId];
        self.userID = [[newCrew objectAtIndex:0]objectForKey:kUserPublicId];
        
        return;
    }
    
    //compare with the existing crew and remove any old map annotations; as at this point you cannot add a new member
    for ( int i = 1; i < self.crew.count ; i++ )
    {
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:i];
        NSString * existingUserId = [crewMember objectForKey:kUserPublicId];
        BOOL found = NO;
        
        for ( int j = 1; j < newCrew.count; j++)
        {
            NSDictionary * newCrewMember = [newCrew objectAtIndex:j];
            NSString * newUserId = [newCrewMember objectForKey:kUserPublicId];
            
            if ( [newUserId isEqualToString:existingUserId] ) {
                found = YES;
                break;
            }
        }
        
        if ( !found )
        {
            //delete this crew member and remove its annotation from map
            MKPointAnnotation * mapPoint = [crewMember objectForKey:kMKPointAnnotation];
            [self.mapView removeAnnotation:mapPoint];
            [self.crew removeObjectAtIndex:i];
            i--;
        }
    }
}

//called when 5mins timer expires
-(void)setAutoCheckinMode:(BOOL)inAutoCheckinModeNow
{
    //change the location activity mode to give us auto navigation location updates
    self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
}

//called once when meet your crew view is loaded
-(void)startUpdatingMapView:(MKMapView *)mapView
     withSuggestedLocations:(NSDictionary *)suggestedLocations
           andPusherChannel:(NSString *)locationChannel
{
    //set class properties
    self.mapView = mapView;
    self.mapView.delegate = self;
    self.suggestedLocations = suggestedLocations;
    self.locationChannel = locationChannel;
    
    //show suggested locations map annotations
    [self showDropOffLocation];
    [self showPickUpLocation];
    [self zoomToFitMapAnnotations];
    
    //start location updates
    [self startLocationUpdates];

    //subscribe to pusher channel
    [self startPusherUpdates];
}

#pragma mark - Core Location

-(void) startLocationUpdates
{
    // start by locating user's current position
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
    self.locationManager.activityType = CLActivityTypeFitness;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	[self.locationManager startUpdatingLocation];
}

-(void) stopLocationUpdates
{
    // start by locating user's current position
	[self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"loc update - %@", locations);
    CLLocation * newLocation = [locations lastObject];
    [self sendDataToPusher:newLocation.coordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    // report any errors returned back from Location Services
    NSLog(@"loc manager failed - %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    //re-start loc services if needed
    [self startLocationUpdates];
}


-(BOOL) isLocationEnabled
{
    NSString *causeStr = nil;
    
    // check whether location services are enabled on the device
    if ([CLLocationManager locationServicesEnabled] == NO)
    {
        causeStr = @"device";
    }
    // check the application’s explicit authorization status:
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
    {
        causeStr = @"app";
    }
    
    if (causeStr != nil)
    {
        NSString *alertMessage = [NSString stringWithFormat:@"You currently have location services disabled for this %@. Please turn it on at \"Settings > Privacy > Location Services\"", causeStr];
        
        UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                                                        message:alertMessage
                                                                       delegate:nil
                                                              cancelButtonTitle:@"OK"
                                                              otherButtonTitles:nil];
        [servicesDisabledAlert show];
        return NO;
    }
    
    return YES;
}

#pragma mark Pusher

- (void)handleCrewLocationUpdate:(PTPusherEvent *)event
{
    NSDictionary * locationUpdate = event.data;
    
    NSString * userID = [locationUpdate objectForKey:kUserPublicId];
    
    //if one of the crew member id, match this one, update its location on the map
    for (int i = 1; i < self.crew.count; i++)
    {
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:i];
        NSString * crewId = [crewMember objectForKey:kUserPublicId];
        if ( [crewId isEqualToString:userID])
        {
            CLLocationCoordinate2D newCoordinates = CLLocationCoordinate2DMake([[locationUpdate objectForKey:@"lat"] doubleValue] , [[locationUpdate objectForKey:@"long"]doubleValue]);
            
            //we found the crew whose location needs to be updated
            MKPointAnnotation * mapPoint = [crewMember objectForKey:kMKPointAnnotation];
            if ( !mapPoint )
            {
                //this is the first time we have known about this crew members location
                mapPoint = [[MKPointAnnotation alloc]init];
                
                mapPoint.title = [crewMember objectForKey:kCrewFbName];
                
                if ([[crewMember objectForKey:kIsCaptain] boolValue])
                    mapPoint.subtitle = @"Captain";
                else
                    mapPoint.subtitle = @"Stowaway";
                
                mapPoint.coordinate = newCoordinates;
                
                [self.mapView addAnnotation:mapPoint];
                [self.mapView selectAnnotation:mapPoint animated:YES];
                
                [crewMember setValue:mapPoint forKey:kMKPointAnnotation];
            }
            
            mapPoint.coordinate = newCoordinates;
            
            break;
        }
    }
    
    [self zoomToFitMapAnnotations];
}

-(void)sendDataToPusher:(CLLocationCoordinate2D )locationCoordinates
{
    PTPusherConnection * connection = self.pusher.connection;
    
    NSDictionary * locationUpdate = @{@"lat": [NSNumber numberWithDouble:locationCoordinates.latitude],
                                      @"long": [NSNumber numberWithDouble:locationCoordinates.longitude],
                                      kUserPublicId: self.userID,
                                      kRequestPublicId: self.requestID};
    
    [connection send:locationUpdate];
}

-(void)startPusherUpdates
{
    //create pusher
    self.pusher = [PTPusher pusherWithKey:kPusherApiKey delegate:self encrypted:YES];
    
    //TODO: authorise for private channel
    //self.client.authorizationURL = [NSURL URLWithString:@"https://api.getstowaway.com/pusher/auth"];
    
    [self.pusher connect];
    
    //subscribe to location channel created by server
    //TODO: use subscribeToPresenceChannelNamed
    PTPusherChannel *channel = [self.pusher subscribeToChannelNamed:self.locationChannel];
    
    [channel bindToEventNamed:kPusherCrewLocationEvent target:self action:@selector(handleCrewLocationUpdate:)];
}

-(void)stopPusherUpdates
{
    PTPusherChannel *channel = [self.pusher channelNamed:self.locationChannel];
    [channel unsubscribe];
    
}

- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel withRequest:(NSMutableURLRequest *)request
{
    //TODO: fill in right credentials
    [request setValue:@"afbadb4ff8485c0adcba486b4ca90cc4" forHTTPHeaderField:@"X-MyCustom-AuthTokenHeader"];
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection failedWithError:(NSError *)error
{
    [self handleDisconnectionWithError:error];
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error willAttemptReconnect:(BOOL)willAttemptReconnect
{
    if (!willAttemptReconnect) {
        [self handleDisconnectionWithError:error];
    }
}

- (void)handleDisconnectionWithError:(NSError *)error
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    
    if (error && [error.domain isEqualToString:PTPusherErrorDomain]) {
        NSLog(@"FATAL PUSHER ERROR, COULD NOT CONNECT! %@", error);
    }
    else {
        if ([reachability isReachable]) {
            // we do have reachability so let's wait for a set delay before trying again
            [self.pusher performSelector:@selector(connect) withObject:nil afterDelay:5];
        }
        else {
            // we need to wait for reachability to change
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(_reachabilityChanged:)
                                                         name:kReachabilityChangedNotification
                                                       object:reachability];
            
            [reachability startNotifier];
        }
    }
}

- (void)_reachabilityChanged:(NSNotification *)note
{
    Reachability *reachability = [note object];
    if ([reachability isReachable]) {
        // we're reachable, we can try and reconnect, otherwise keep waiting
        [self.pusher connect];
        
        // stop watching for reachability changes
        [reachability stopNotifier];
        
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:kReachabilityChangedNotification
         object:reachability];
    }
}

#pragma mark - map annotations

-(void)showDropOffLocation
{
    if ( !self.dropOffAnnotation )
    {
        self.dropOffAnnotation = [[MKPointAnnotation alloc]init];
        self.dropOffAnnotation.title = @"Drop-Off point";
    }
    
    self.dropOffAnnotation.coordinate = CLLocationCoordinate2DMake([[self.suggestedLocations objectForKey:kSuggestedDropOffLat] doubleValue],
                                                                   [[self.suggestedLocations objectForKey:kSuggestedDropOffLong] doubleValue]);

    self.dropOffAnnotation.subtitle = [self.suggestedLocations objectForKey:kSuggestedDropOffAddr];
    
    [self.mapView addAnnotation:self.dropOffAnnotation];
    [self.mapView selectAnnotation:self.dropOffAnnotation animated:YES];
}


-(void)showPickUpLocation
{
    if ( !self.pickUpAnnotation )
    {
        self.pickUpAnnotation = [[MKPointAnnotation alloc]init];
        self.pickUpAnnotation.title = @"Pick-Up point";
    }
    
    self.pickUpAnnotation.coordinate = CLLocationCoordinate2DMake([[self.suggestedLocations objectForKey:kSuggestedPickUpLat] doubleValue],
                                                                  [[self.suggestedLocations objectForKey:kSuggestedPickUpLong] doubleValue]);
    
    self.pickUpAnnotation.subtitle = [self.suggestedLocations objectForKey:kSuggestedPickUpAddr];
    
    [self.mapView addAnnotation:self.pickUpAnnotation];
    [self.mapView selectAnnotation:self.pickUpAnnotation animated:YES];
}


-(void)zoomToFitMapAnnotations
{
    if([self.mapView.annotations count] == 0)
        return;
    
    CLLocationCoordinate2D topLeftCoord;
    topLeftCoord.latitude = -90;
    topLeftCoord.longitude = 180;
    
    CLLocationCoordinate2D bottomRightCoord;
    bottomRightCoord.latitude = 90;
    bottomRightCoord.longitude = -180;
    
    for(MKPointAnnotation* annotation in self.mapView.annotations)
    {
        topLeftCoord.longitude = fmin(topLeftCoord.longitude, annotation.coordinate.longitude);
        topLeftCoord.latitude = fmax(topLeftCoord.latitude, annotation.coordinate.latitude);
        
        bottomRightCoord.longitude = fmax(bottomRightCoord.longitude, annotation.coordinate.longitude);
        bottomRightCoord.latitude = fmin(bottomRightCoord.latitude, annotation.coordinate.latitude);
    }
    
    MKCoordinateRegion region;
    region.center.latitude = topLeftCoord.latitude - (topLeftCoord.latitude - bottomRightCoord.latitude) * 0.5;
    region.center.longitude = topLeftCoord.longitude + (bottomRightCoord.longitude - topLeftCoord.longitude) * 0.5;
    region.span.latitudeDelta = fabs(topLeftCoord.latitude - bottomRightCoord.latitude) * 1.2; // Add a little extra space on the sides
    region.span.longitudeDelta = fabs(bottomRightCoord.longitude - topLeftCoord.longitude) * 1.2; // Add a little extra space on the sides
    
    region = [self.mapView regionThatFits:region];
    [self.mapView setRegion:region animated:YES];
}


#pragma mark - MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    //TODO: reuse kAnnotationIdentifier
    
    MKPointAnnotation *resultPin = [[MKPointAnnotation alloc] init];
    MKPinAnnotationView *result = [[MKPinAnnotationView alloc] initWithAnnotation:resultPin reuseIdentifier:@"AnnotationIdentifier"];
    
    result.animatesDrop = YES;
    result.canShowCallout = YES;
    
    if ([annotation.title isEqualToString: @"Drop-Off point"])
    {
        result.pinColor = MKPinAnnotationColorRed;
        
        return result;
    }
    
    if ([annotation.title isEqualToString:@"Pick-Up point"])
    {
        result.pinColor = MKPinAnnotationColorGreen;
        
        return result;
    }
    
    if (annotation.title)
    {
        result.pinColor = MKPinAnnotationColorPurple;
        
        return result;
    }
    
    return nil;
}



@end
