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


@interface MeetCrewMapViewManager ()<CLLocationManagerDelegate, MKMapViewDelegate>

@property (strong, nonatomic) NSDictionary *suggestedLocations;

@property (strong, nonatomic) NSString * locationChannel;

@property (weak, nonatomic) MKMapView * mapView;

@property (strong, nonatomic) NSMutableArray * /*of NSDictionary*/ crew; //index 0 being self and upto 3, this class will also add the MKMapItem; this is copy of the original so we can compare

@property BOOL inAutoCheckinModeNow;

@property (nonatomic, strong) MKPointAnnotation * pickUpAnnotation;
@property (nonatomic, strong) MKPointAnnotation * dropOffAnnotation;

@property (strong, nonatomic) CLLocationManager * locationManager;

@end


@implementation MeetCrewMapViewManager

//called anytime a stowaways gets updated
-(void)setCrew:(NSMutableArray *)crew
{
    //compare with the existing crew and remove any old map annotations as required
    
}

//called when 5mins timer expires
-(void)setAutoCheckinMode:(BOOL)inAutoCheckinModeNow
{
    //change the location activity mode to give us auto navigation location updates
    
}

//called once
-(void)startUpdatingMapView:(MKMapView *)mapView
     withSuggestedLocations:(NSDictionary *)suggestedLocations
           andPusherChannel:(NSString *)locationChannel
{
    //set properties
    self.mapView = mapView;
    self.mapView.delegate = self;
    self.suggestedLocations = suggestedLocations;
    self.locationChannel = locationChannel;
    
    //show suggested locations map annotations
    [self showDropOffLocation];
    [self showPickUpLocation];
    [self zoomToFitMapAnnotations];
    
    //subscribe to pusher channel
    
    //send pusher self location
    
    //read pusher data to update the map view - each stowaway annotation, subtitle which can be
    
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

@end
