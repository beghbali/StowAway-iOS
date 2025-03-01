//
//  MeetCrewMapViewManager.m
//  StowAway
//
//  Created by Vin Pallen on 3/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "MeetCrewMapViewManager.h"
#import <CoreLocation/CoreLocation.h>
#import "PTPusherChannel.h"
#import "PTPusher.h"
#import "PTPusherEvent.h"
#import "Reachability.h"
#import "PTPusherErrors.h"
#import "PTPusherConnection.h"
#import "StowawayServerCommunicator.h"

@interface MeetCrewMapViewManager ()<CLLocationManagerDelegate, MKMapViewDelegate, PTPusherDelegate>

@property (strong, nonatomic) NSMutableDictionary *suggestedLocations;

@property (strong, nonatomic) NSString * locationChannel;
@property (strong, nonatomic) PTPusher * pusher;

@property (weak, nonatomic) MKMapView * mapView;

/* index 0 being self and upto 3, this class will also add the MKPointAnnotation; this is copy of the original so we can compare when crew changes */
@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew;

@property BOOL inAutoCheckinModeNow;

@property (nonatomic, strong) MKPointAnnotation * pickUpAnnotation;
@property (nonatomic, strong) MKPointAnnotation * dropOffAnnotation;

@property (strong, nonatomic) CLLocationManager * locationManager;
@property (strong, nonatomic) CLLocation * location;

@property (strong, nonatomic) NSNumber *userID;
@property (strong, nonatomic) NSNumber *requestID;
@property (strong, nonatomic) NSNumber *rideID;

@property BOOL isPusherConnected;
@property BOOL isLocationDisabled;
@property BOOL isAllCrewMapped;
@property BOOL isPickupDropOffPointMapped;

@property (strong, nonatomic) CLGeocoder * geocoder;

@end


@implementation MeetCrewMapViewManager

#pragma mark - initialization
//called anytime crew gets updated
-(void)initializeCrew:(NSMutableArray *)newCrew forRideID:(NSNumber *)rideID
{
#ifdef DEBUG
    NSLog(@"%s:: new crew......... %@, rideID %@", __func__, newCrew, rideID);
#endif
    self.rideID = rideID;
    
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
        NSNumber * existingUserId = [crewMember objectForKey:kUserPublicId];
        BOOL found = NO;
        
        for ( int j = 1; j < newCrew.count; j++)
        {
            NSDictionary * newCrewMember = [newCrew objectAtIndex:j];
            NSNumber * newUserId = [newCrewMember objectForKey:kUserPublicId];
            
            if ( [newUserId compare:existingUserId] == NSOrderedSame ) {
                found = YES;
                break;
            }
        }
        
        if ( !found )
        {
#ifdef DEBUG
            NSLog(@"%s: <i=%d> delete %@", __func__, i, crewMember);
#endif
            //delete this crew member and remove its annotation from map
            MKPointAnnotation * mapPoint = [crewMember objectForKey:kMKPointAnnotation];
            [self.mapView removeAnnotation:mapPoint];
            [self.crew removeObjectAtIndex:i];
            i--;
        }
    }
}

//called once when meet your crew view is loaded
-(void)startUpdatingMapView:(MKMapView *)mapView
     withSuggestedLocations:(NSDictionary *)suggestedLocations
           andPusherChannel:(NSString *)locationChannel
{
    //check loc is on
    self.isLocationDisabled = [self alertIsLocationDisabled];
    
    //set class properties
    self.mapView = mapView;
    self.mapView.delegate = self;
    self.suggestedLocations = [NSMutableDictionary dictionaryWithDictionary: suggestedLocations];
    self.locationChannel = locationChannel;
    
    [self reverseGeocodeSuggestedPickUpAddresses];  //pick up first and only if it finishes go for drop off geocoding
    
    //show suggested locations map annotations, drop off first
    [self showDropOffLocation];
    [self showPickUpLocation];
    [self zoomToFitMapAnnotations];
}

#pragma mark - Auto-checkin

//called when 5mins timer expires
-(void)startAutoCheckinMode
{
    NSDictionary * crewMember_self = [self.crew objectAtIndex:0];

#ifdef DEBUG
    NSLog(@"startAutoCheckinMode - self %@", crewMember_self);
#endif
    if ([[crewMember_self objectForKey:kIsCaptain] boolValue])
    {
#ifdef DEBUG
        NSLog(@"i am the captain, asking server to start auto-checkin");
#endif
        //checkin request - only captain sends
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@/checkin", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.rideID];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = nil; //no response expected
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"PUT"];
    }
    else
#ifdef DEBUG
        NSLog(@"i am a stowaway, so dont tell server to auto-checkin");
#endif
    
    //change the location activity mode to give us auto navigation location updates
    self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
}

//called when server made a decision about auto-checkin
-(void)stopAutoCheckinMode
{
#ifdef DEBUG
    NSLog(@"%s", __func__);
#endif
    [self stopLocationUpdates];
    [self stopPusherUpdates];
}

#pragma mark - reverse geocoding
-(void)reverseGeocodeDropOffSuggestedAddresses
{
    CLLocation *dropOffLoc = nil;
    
    NSString * suggDropOffAddr = [self.suggestedLocations objectForKey:kSuggestedDropOffAddr];
    
    if ( [suggDropOffAddr isEqualToString:kSuggestedDefaultDropOffAddr])
    {
        dropOffLoc = [[CLLocation alloc]
                      initWithLatitude:[[self.suggestedLocations objectForKey:kSuggestedDropOffLat] doubleValue]
                      longitude:[[self.suggestedLocations objectForKey:kSuggestedDropOffLong] doubleValue]];
        
        [self.suggestedLocations setObject:@"" forKey:kSuggestedDropOffAddr];
    }
    
    if ( dropOffLoc )
    {
        if (!self.geocoder)
            self.geocoder = [[CLGeocoder alloc]init];
        
        [self.geocoder reverseGeocodeLocation: dropOffLoc completionHandler:
         ^(NSArray *placemarks, NSError *error)
        {
            //NSLog(@"drop off -- %@, error %@", placemarks, error);
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
        
            NSString * streetAdd = nil;
            
            if (placemark.thoroughfare && placemark.subThoroughfare)
            {
                if (placemark.locality)
                    streetAdd = [NSString stringWithFormat:@"%@ %@, %@", placemark.subThoroughfare, placemark.thoroughfare, placemark.locality ];
                else
                    streetAdd = [NSString stringWithFormat:@"%@ %@", placemark.subThoroughfare, placemark.thoroughfare ];
            }
            else if( placemark.name || placemark.locality)
            {
                NSString * streetName = placemark.name ? placemark.name: @"";
                NSString * locality = placemark.locality ? placemark.locality: @"";
                
                streetAdd = [NSString stringWithFormat:@"%@, %@", streetName, locality];
            }

#ifdef DEBUG
            NSLog(@"drop off Addr %@, --  name %@, locality %@ ==== sub %@ thoroughfare %@", streetAdd, placemark.name, placemark.locality, placemark.subThoroughfare, placemark.thoroughfare);
#endif
            if (!streetAdd)
                return;
            
            [self.suggestedLocations setObject:streetAdd forKey:kSuggestedDropOffAddr];
            [self showDropOffLocation];
            [self showPickUpLocation];
        }];
    }
}

-(void)reverseGeocodeSuggestedPickUpAddresses
{
    CLLocation *pickUpLoc = nil;
    
    NSString * suggPickUpAddr = [self.suggestedLocations objectForKey:kSuggestedPickUpAddr];
    
    if ( [suggPickUpAddr isEqualToString:kSuggestedDefaultPickUpAddr] ||
        [suggPickUpAddr isEqualToString:kPickUpDefaultCurrentLocation] )
    {
        pickUpLoc = [[CLLocation alloc]
                     initWithLatitude:[[self.suggestedLocations objectForKey:kSuggestedPickUpLat] doubleValue]
                     longitude:[[self.suggestedLocations objectForKey:kSuggestedPickUpLong] doubleValue]];
        
        //replace default with empty string
        [self.suggestedLocations setObject:@"" forKey:kSuggestedPickUpAddr];
    }
    
    if ( pickUpLoc )
    {
        if (!self.geocoder)
            self.geocoder = [[CLGeocoder alloc]init];
        
        [self.geocoder reverseGeocodeLocation: pickUpLoc completionHandler:
         ^(NSArray *placemarks, NSError *error)
         {
             //NSLog(@"pick up -- %@, error %@", placemarks, error);
             CLPlacemark *placemark = [placemarks objectAtIndex:0];
             
             NSString * streetAdd = nil;
             
             if (placemark.thoroughfare && placemark.subThoroughfare)
             {
                 if (placemark.locality)
                     streetAdd = [NSString stringWithFormat:@"%@ %@, %@", placemark.subThoroughfare, placemark.thoroughfare, placemark.locality ];
                 else
                     streetAdd = [NSString stringWithFormat:@"%@ %@", placemark.subThoroughfare, placemark.thoroughfare ];
             }
             else if( placemark.name || placemark.locality)
             {
                 NSString * streetName = placemark.name ? placemark.name: @"";
                 NSString * locality = placemark.locality ? placemark.locality: @"";
                 
                 streetAdd = [NSString stringWithFormat:@"%@, %@", streetName, locality];
             }
             
#ifdef DEBUG
             NSLog(@"pickup Addr %@, --  name %@, locality %@ ==== sub %@ thoroughfare %@", streetAdd, placemark.name, placemark.locality, placemark.subThoroughfare, placemark.thoroughfare);
#endif
             if (!streetAdd)
                 return;
             
             [self.suggestedLocations setObject:streetAdd forKey:kSuggestedPickUpAddr];
             [self showPickUpLocation];
             [self reverseGeocodeDropOffSuggestedAddresses];
         }];
             
          return;
    }
    
    [self reverseGeocodeDropOffSuggestedAddresses];
}


#pragma mark - Core Location

-(void) startLocationUpdates
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
#endif
    // start by locating user's current position
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
    self.locationManager.activityType = CLActivityTypeFitness;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = kPusherCrewWalkingLocationUpdateThreshholdMeters;
	[self.locationManager startUpdatingLocation];
}

-(void) stopLocationUpdates
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
#endif
	[self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
#ifdef DEBUG
    NSLog(@"%s", __func__);
#endif
    CLLocation * newLocation = [locations lastObject];
    
    CLLocationDistance change = [self.location   distanceFromLocation:newLocation];
    
    if ( self.location && (change < kPusherCrewWalkingLocationUpdateThreshholdMeters) ) {
#ifdef DEBUG
        NSLog(@"change is less than %f, ignoring...", kPusherCrewWalkingLocationUpdateThreshholdMeters);
#endif
        return;
    }
    
#ifdef DEBUG
    NSLog(@"Meet crew: loc update - %@", newLocation);
#endif
    self.location = newLocation;
    [self sendDataToPusher:newLocation.coordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    // report any errors returned back from Location Services
    NSLog(@"loc manager failed - %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"%s, status %d",__func__, status);
    
    if ( (status == kCLAuthorizationStatusAuthorized) && self.isLocationDisabled )
        [self startLocationUpdates];
    else
        self.isLocationDisabled = [self alertIsLocationDisabled];    //this would prompt user
}


-(BOOL) alertIsLocationDisabled
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
#ifdef DEBUG
    NSLog(@"%s: authorizationStatus %d", __func__, status);
#endif
    if ( status && status < kCLAuthorizationStatusAuthorized ) //user has explicitly disabled
    {
        NSString *alertMessage = nil;
        
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1)
            // iOS 7.1 or earlier
            alertMessage = [NSString stringWithFormat:@"We need location services to function. \nPlease turn ON \"Settings > Privacy > Location Services > Stowaway\""];
        else
            //ios 8
            alertMessage = [NSString stringWithFormat:@"We need location services to function. \nPlease select 'Always' at \"Settings > Privacy > Location Services > Stowaway\""];
        
        UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                                                        message:alertMessage
                                                                       delegate:nil
                                                              cancelButtonTitle:@"OK"
                                                              otherButtonTitles:nil];
        [servicesDisabledAlert show];
        return YES;
    }
    return NO;
}

#pragma mark - Pusher

-(void)startPusherUpdates
{
#ifdef DEBUG
    NSLog(@"%s", __func__);
#endif
    //create pusher
    self.pusher = [PTPusher pusherWithKey:[[Environment ENV] lookup:@"kPusherApiKey"] delegate:self encrypted:YES];
    self.pusher.reconnectAutomatically = YES;
    
    //authentication endpoint
    self.pusher.authorizationURL = [NSURL URLWithString: [NSString stringWithFormat:@"%@%@/auth", [[Environment ENV] lookup:@"kStowawayServerApiUrl_pusher"], self.userID]];
    
    self.isPusherConnected = NO;
    
    [self.pusher connect];
    
    //subscribe to location channel created by server
    PTPusherChannel *channel = [self.pusher subscribeToPrivateChannelNamed:self.locationChannel];
    
    [channel bindToEventNamed:kPusherCrewLocationEvent target:self action:@selector(handleCrewLocationUpdate:)];
}

-(void)stopPusherUpdates
{
#ifdef DEBUG
    NSLog(@"%s", __func__);
#endif
    if (!(self.pusher && self.locationChannel))
        return;
    
    PTPusherChannel *channel = [self.pusher channelNamed:self.locationChannel];
    [channel unsubscribe];
}

-(void)sendDataToPusher:(CLLocationCoordinate2D )locationCoordinates
{
    PTPusherConnection * connection = self.pusher.connection;
#ifdef DEBUG
    NSLog(@"sendDataToPusher::connected=%d  (%f,%f) ", self.isPusherConnected, locationCoordinates.latitude, locationCoordinates.longitude);
#endif
    if ( !self.isPusherConnected )
        return;

    NSDictionary * dataDict = @{@"lat": [NSNumber numberWithDouble:locationCoordinates.latitude],
                                @"long": [NSNumber numberWithDouble:locationCoordinates.longitude],
                                kUserPublicId: self.userID,
                                kRequestPublicId: self.requestID};
    NSDictionary * locationUpdate = @{@"event":kPusherCrewLocationEvent,
                                      @"channel":[NSString stringWithFormat:@"private-%@", self.locationChannel],
                                      @"data": dataDict};
    
#ifdef DEBUG
    NSLog(@"*** sendDataToPusher:: %@", locationUpdate);
#endif
    [connection send:locationUpdate];
}


#pragma mark - PTPusher delegate

- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel withRequest:(NSMutableURLRequest *)request
{
#ifdef DEBUG
    NSLog(@"willAuthorizeChannel:: %@, %@", channel, request);
#endif
    [request setValue:@"afbadb4ff8485c0adcba486b4ca90cc4" forHTTPHeaderField:@"X-MyCustom-AuthTokenHeader"];
}

- (void)pusher:(PTPusher *)pusher connectionDidConnect:(PTPusherConnection *)connection
{
    NSLog(@"connectionDidConnect:: isPusherConnected %d ", self.isPusherConnected);

    self.isPusherConnected = YES;
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection failedWithError:(NSError *)error
{
    NSLog(@"connection failedWithError:: %@", error);
    
    self.isPusherConnected = NO;
    
    [self handleDisconnectionWithError:error];
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error willAttemptReconnect:(BOOL)willAttemptReconnect
{
    NSLog(@"didDisconnectWithError:%@, isPusherConnected %d", error, self.isPusherConnected);
    
    self.isPusherConnected = NO;
    
    if ( !willAttemptReconnect )
        [self handleDisconnectionWithError:error];
    
}

- (void)handleDisconnectionWithError:(NSError *)error
{
    NSLog(@"%s", __func__);
    
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
    NSLog(@"%s", __func__);

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

#pragma mark - pusher on map

- (void)handleCrewLocationUpdate:(PTPusherEvent *)event
{
#ifdef DEBUG
    NSLog(@"%s:: pusher event %@ ", __func__, event);
#endif
    NSDictionary * locationUpdate = event.data;
    
    NSNumber * userID = [locationUpdate objectForKey:kUserPublicId];
    
    //if one of the crew member id, match this one, update its location on the map
    for (int i = 1; i < self.crew.count; i++)
    {
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:i];
        NSNumber * crewId = [crewMember objectForKey:kUserPublicId];
        if ( [crewId compare:userID] == NSOrderedSame )
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

#pragma mark - map annotations

-(void)showDropOffLocation
{
    if ( !self.dropOffAnnotation )
    {
        self.dropOffAnnotation = [[MKPointAnnotation alloc]init];
        self.dropOffAnnotation.title = dropOffPointAnnotationTitle;
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
        self.pickUpAnnotation.title = pickUpPointAnnotationTitle;
    }
    
    self.pickUpAnnotation.coordinate = CLLocationCoordinate2DMake([[self.suggestedLocations objectForKey:kSuggestedPickUpLat] doubleValue],
                                                                  [[self.suggestedLocations objectForKey:kSuggestedPickUpLong] doubleValue]);
    
    self.pickUpAnnotation.subtitle = [self.suggestedLocations objectForKey:kSuggestedPickUpAddr];
    
    [self.mapView addAnnotation:self.pickUpAnnotation];
    [self.mapView selectAnnotation:self.pickUpAnnotation animated:YES];
}


-(void)zoomToFitMapAnnotations
{
#ifdef DEBUG
    NSLog(@"%s, annotations# %lu, crew# %lu, isAllCrewMapped %d, isPickupDropOffPointMapped %d", __func__,
          (unsigned long)self.mapView.annotations.count, (unsigned long)self.crew.count, self.isAllCrewMapped, self.isPickupDropOffPointMapped);
#endif
    if(!self.mapView.annotations.count || self.isAllCrewMapped || self.isPickupDropOffPointMapped)
        return;

    
    if(self.mapView.annotations.count == 3) //annotations for currentloction, pick up, drop off
    {
#ifdef DEBUG
        NSLog(@"%s: pick up and drop off points mapped once, now dont zoom out anymore...", __func__);
#endif
        self.isPickupDropOffPointMapped = YES;
    }
    
    if(self.mapView.annotations.count == (self.crew.count + 2)) //annotations for each crew, pick up, drop off
    {
#ifdef DEBUG
        NSLog(@"%s: all crew mapped once, now dont zoom out anymore...", __func__);
#endif
        self.isAllCrewMapped = YES;
    }

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
    region.span.latitudeDelta = fabs(topLeftCoord.latitude - bottomRightCoord.latitude) * 2.1; // Add a little extra space on the sides
    region.span.longitudeDelta = fabs(bottomRightCoord.longitude - topLeftCoord.longitude) * 1.2; // Add a little extra space on the sides
    
    region = [self.mapView regionThatFits:region];
    [self.mapView setRegion:region animated:YES];
}


#pragma mark - MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
#ifdef DEBUG
    NSLog(@"MC:: viewForAnnotation::-- title %@, subtitle %@", annotation.title, annotation.subtitle);
#endif
    //TODO: reuse kAnnotationIdentifier
    
    MKPointAnnotation *resultPin = [[MKPointAnnotation alloc] init];
    MKPinAnnotationView *result = [[MKPinAnnotationView alloc] initWithAnnotation:resultPin reuseIdentifier:@"AnnotationIdentifier"];
    
    result.animatesDrop = YES;
    result.canShowCallout = YES;
    
    if ([annotation.title isEqualToString: dropOffPointAnnotationTitle])
    {
        result.pinColor = MKPinAnnotationColorRed;
        
        return result;
    }
    
    if ([annotation.title isEqualToString:pickUpPointAnnotationTitle])
    {
        result.pinColor = MKPinAnnotationColorGreen;
        
        return result;
    }
    
    if (annotation.title && annotation.subtitle)
    {
        result.pinColor = MKPinAnnotationColorPurple;
        
        return result;
    }
    
    return nil;
}



@end
