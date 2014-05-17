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
#import "StowawayServerCommunicator.h"
#import "Environment.h"

@interface MeetCrewMapViewManager ()<CLLocationManagerDelegate, MKMapViewDelegate, PTPusherDelegate>

@property (strong, nonatomic) NSMutableDictionary *suggestedLocations;

@property (strong, nonatomic) NSString * locationChannel;
@property (strong, nonatomic) PTPusher * pusher;

@property (weak, nonatomic) MKMapView * mapView;

@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew; //index 0 being self and upto 3, this class will also add the MKPointAnnotation; this is copy of the original so we can compare when crew changes

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

@property (strong, nonatomic) CLGeocoder * geocoder;

@end


@implementation MeetCrewMapViewManager

//called anytime a stowaways gets updated
-(void)initializeCrew:(NSMutableArray *)newCrew forRideID:(NSNumber *)rideID
{
    NSLog(@"MeetCrewMapViewManager:: new crew......... %@, rideID %@", newCrew, rideID);
    
    self.rideID = rideID;
    
    //for the first time, just copy the crew
    if ( !self.crew )
    {
        NSLog(@"initializeCrew......");

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
            NSLog(@"<i=%d> delete %@", i, crewMember);
            //delete this crew member and remove its annotation from map
            MKPointAnnotation * mapPoint = [crewMember objectForKey:kMKPointAnnotation];
            [self.mapView removeAnnotation:mapPoint];
            [self.crew removeObjectAtIndex:i];
            i--;
        }
    }
}

#pragma mark Auto-checkin

//called when 5mins timer expires
-(void)startAutoCheckinMode
{
    NSDictionary * crewMember_self = [self.crew objectAtIndex:0];

    NSLog(@"startAutoCheckinMode - self %@", crewMember_self);
   
    if ([[crewMember_self objectForKey:kIsCaptain] boolValue])
    {
        NSLog(@"i am the captain, asking server to start auto-checkin");
        //checkin request - only captain sends
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@/checkin", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.rideID];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = nil; //no response expected
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"PUT"];
    }
    else
        NSLog(@"i am a stowaway, so dont tell server to auto-checkin");

    //change the location activity mode to give us auto navigation location updates
    self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
}

//called when server made a decision about auto-checkin
-(void)stopAutoCheckinMode
{
    NSLog(@"stopAutoCheckinMode");
    [self stopLocationUpdates];
    [self stopPusherUpdates];
}

//called once when meet your crew view is loaded
-(void)startUpdatingMapView:(MKMapView *)mapView
     withSuggestedLocations:(NSDictionary *)suggestedLocations
           andPusherChannel:(NSString *)locationChannel
                isLoneRider:(BOOL)isLoneRider
{
    NSLog(@"%s, isLoneRider %d",__func__, isLoneRider);
   
    //check loc is on
    self.isLocationDisabled = ![self isLocationEnabled];

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
    
    if (!isLoneRider)
    {
        //start location updates
        [self startLocationUpdates];

        //subscribe to pusher channel
        [self startPusherUpdates];
    }
}

-(void)reverseGeocodeDropOffSuggestedAddresses
{
    CLLocation *dropOffLoc = nil;
    
    NSLog(@"%s.........", __func__);
    
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
        NSLog(@"reverse geo coding drop off loc ...");
        
        if (!self.geocoder)
            self.geocoder = [[CLGeocoder alloc]init];
        
        [self.geocoder reverseGeocodeLocation: dropOffLoc completionHandler:
         ^(NSArray *placemarks, NSError *error)
        {
            NSLog(@"drop off -- %@, error %@", placemarks, error);
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

            NSLog(@"drop off Addr %@, --  name %@, locality %@ ==== sub %@ thoroughfare %@", streetAdd, placemark.name, placemark.locality, placemark.subThoroughfare, placemark.thoroughfare);

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
    
    NSLog(@"%s.........", __func__);
    
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
        NSLog(@"reverse geo coding pick up loc ...");
        
        if (!self.geocoder)
            self.geocoder = [[CLGeocoder alloc]init];
        
        [self.geocoder reverseGeocodeLocation: pickUpLoc completionHandler:
         ^(NSArray *placemarks, NSError *error)
         {
             NSLog(@"pick up -- %@, error %@", placemarks, error);
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
             
             NSLog(@"pickup Addr %@, --  name %@, locality %@ ==== sub %@ thoroughfare %@", streetAdd, placemark.name, placemark.locality, placemark.subThoroughfare, placemark.thoroughfare);
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
    NSLog(@"%s",__func__);
    // start by locating user's current position
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
    self.locationManager.activityType = CLActivityTypeFitness;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	[self.locationManager startUpdatingLocation];
}

-(void) stopLocationUpdates
{
    NSLog(@"%s",__func__);
	[self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"didUpdateLocations !");
    //NSLog(@"Meet crew: loc update - %@", locations);
    CLLocation * newLocation = [locations lastObject];
    
    CLLocationDistance change = [self.location   distanceFromLocation:newLocation];
   // NSLog(@"prev loc %@, change %f", self.location, change);
    
    if ( self.location && (change < kPusherCrewWalkingLocationUpdateThreshholdMeters) ) {
        NSLog(@"change is less than %f, ignoring...", kPusherCrewWalkingLocationUpdateThreshholdMeters);
        return;
    }
    
    NSLog(@"Meet crew: loc update - %@", newLocation);

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
    //TODO: re-start loc services if needed
    NSLog(@"%s, status %d",__func__, status);
    
    if ( (status == kCLAuthorizationStatusAuthorized) && self.isLocationDisabled )
        [self startLocationUpdates];
    else
        self.isLocationDisabled = ![self isLocationEnabled];    //this would prompt user
}


-(BOOL) isLocationEnabled
{
    NSLog(@"%s",__func__);
    
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

-(void)startPusherUpdates
{
    NSLog(@"%s", __func__);
    //create pusher
    self.pusher = [PTPusher pusherWithKey:[[Environment ENV] lookup:@"kPusherApiKey"] delegate:self encrypted:YES];
    self.pusher.reconnectAutomatically = YES;
    
    //authentication endpoint
    self.pusher.authorizationURL = [NSURL URLWithString: [NSString stringWithFormat:@"%@%@/auth", [[Environment ENV] lookup:@"kStowawayServerApiUrl_pusher"], self.userID]];
    
    self.isPusherConnected = NO;
    
    [self.pusher connect];
    
    //subscribe to location channel created by server
    PTPusherChannel *channel = [self.pusher subscribeToPrivateChannelNamed:self.locationChannel];
    
    [channel bindToEventNamed:[[Environment ENV] lookup:@"kPusherCrewLocationEvent"] target:self action:@selector(handleCrewLocationUpdate:)];
}

-(void)stopPusherUpdates
{
    NSLog(@"%s", __func__);
    PTPusherChannel *channel = [self.pusher channelNamed:self.locationChannel];
    [channel unsubscribe];
}

-(void)sendDataToPusher:(CLLocationCoordinate2D )locationCoordinates
{
    PTPusherConnection * connection = self.pusher.connection;
    NSLog(@"sendDataToPusher::connected=%d  (%f,%f) ", self.isPusherConnected, locationCoordinates.latitude, locationCoordinates.longitude);

    if ( !self.isPusherConnected )
        return;

    NSDictionary * dataDict = @{@"lat": [NSNumber numberWithDouble:locationCoordinates.latitude],
                                @"long": [NSNumber numberWithDouble:locationCoordinates.longitude],
                                kUserPublicId: self.userID,
                                kRequestPublicId: self.requestID};
    NSDictionary * locationUpdate = @{@"event":[[Environment ENV] lookup:@"kPusherCrewLocationEvent"],
                                      @"channel":[NSString stringWithFormat:@"private-%@", self.locationChannel],
                                      @"data": dataDict};
    NSLog(@"*** sendDataToPusher:: %@", locationUpdate);
    [connection send:locationUpdate];
}


- (void)handleCrewLocationUpdate:(PTPusherEvent *)event
{
    NSLog(@"\n %s, event %@ !!!!! \n", __func__, event);
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



#pragma mark - PTPusher delegate

- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel withRequest:(NSMutableURLRequest *)request
{
    //TODO: fill in right credentials
    NSLog(@"willAuthorizeChannel:: %@, %@", channel, request);
    
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

#pragma mark - map annotations

-(void)showDropOffLocation
{
    NSLog(@"%s", __func__);

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
    NSLog(@"%s", __func__);

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
    NSLog(@"%s", __func__);

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
    NSLog(@"viewForAnnotation::-- title %@, subtitle %@", annotation.title, annotation.subtitle);

    //TODO: reuse kAnnotationIdentifier
    
    MKPointAnnotation *resultPin = [[MKPointAnnotation alloc] init];
    MKPinAnnotationView *result = [[MKPinAnnotationView alloc] initWithAnnotation:resultPin reuseIdentifier:@"AnnotationIdentifier"];
    
    result.animatesDrop = YES;
    result.canShowCallout = YES;
    
    if ([annotation.title isEqualToString: @"Drop-Off point"])
    {
        NSLog(@"color mp RED");
        result.pinColor = MKPinAnnotationColorRed;
        
        return result;
    }
    
    if ([annotation.title isEqualToString:@"Pick-Up point"])
    {
        NSLog(@"color mp GREEN");

        result.pinColor = MKPinAnnotationColorGreen;
        
        return result;
    }
    
    if (annotation.title && annotation.subtitle)
    {
        NSLog(@"color mp PURPLE");

        result.pinColor = MKPinAnnotationColorPurple;
        
        return result;
    }
    
    return nil;
}



@end
