//
//  FindCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/24/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "FindCrewViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#define METERS_PER_MILE 1609.344
#define SHOW_MILES_OF_MAP_VIEW 0.6
#define MAP_VIEW_REGION_DISTANCE (SHOW_MILES_OF_MAP_VIEW * METERS_PER_MILE)

static NSString *kCellIdentifier = @"cellIdentifier";
static NSString *kAnnotationIdentifier = @"annotationIdentifier";


@interface FindCrewViewController () <CLLocationManagerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, MKMapViewDelegate> /*, UITableViewDelegate, UITableViewDataSource*/

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *pickUpSearchBar;
@property (weak, nonatomic) IBOutlet UISearchBar *dropOffSearchBar;
@property (weak, nonatomic) IBOutlet UIButton *findCrewButton;

@property (strong, nonatomic) CLLocationManager * locationManager;

@property (nonatomic) CLLocationCoordinate2D userLocation;

@property (nonatomic, strong) MKLocalSearch *localSearch;

// MARK: Future: remember previosuly entered places - store it on device
@property (nonatomic, strong) NSMutableArray /* of MKMapItem */ *pickUpPlaces;
@property (nonatomic, strong) NSMutableArray /* of MKMapItem */ *dropOffPlaces;

@property (nonatomic, strong) MKMapItem * pickUpMapItem;
@property (nonatomic, strong) MKMapItem * dropOffMapItem;

@property (nonatomic, strong) MKPointAnnotation * pickUpAnnotation;
@property (nonatomic, strong) MKPointAnnotation * dropOffAnnotation;

@property (strong, nonatomic) IBOutlet UISearchDisplayController *dropOffSearchDisplayController;

@property (strong, nonatomic) IBOutlet UISearchDisplayController *pickUpSearchDisplayController;
@end


@implementation FindCrewViewController

int locationInputCount = 0;

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.pickUpPlaces   = [NSMutableArray arrayWithCapacity: 1];
    self.dropOffPlaces  = [NSMutableArray arrayWithCapacity: 1];
    
    self.navigationController.navigationBarHidden = YES;

    [self setupLocationServices];
    
    // first thing in serach table should be current location
    MKMapItem * currentLoc = [MKMapItem mapItemForCurrentLocation];
    currentLoc.name = @"Current Location";
    [self.pickUpPlaces insertObject: currentLoc atIndex:0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self isLocationEnabled];
    
    [self updateMapsViewArea];
    
    self.findCrewButton.enabled = NO;

}

#pragma mark - UITableView delegate methods

-(BOOL) isPickUpTableView:(UITableView *)tableView
{
    return (self.pickUpSearchDisplayController.searchResultsTableView == tableView);
}

-(NSArray *) getPlacesForTableView:(UITableView *)tableView
{
    NSArray * places = nil;
    
    if ( [self isPickUpTableView: tableView] )
    {
        NSLog(@"PICK-UP tableview");
        places = self.pickUpPlaces;
    }
    else
    {
        NSLog(@"DROP-OFF tableview");
        places = self.dropOffPlaces;
    }

    return places;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"# of rows");
    return [self getPlacesForTableView:tableView].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    
    MKMapItem *mapItem = [[self getPlacesForTableView:tableView] objectAtIndex:indexPath.row];
    
    NSLog(@"cellForRow [%d] %@", indexPath.row, mapItem.name);
    
    if (!cell) {
        cell = [[UITableViewCell alloc]init];
        NSLog(@"create cell");
    }
    
    cell.textLabel.text = mapItem.name;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // pass the individual place to our map destination view controller
    NSIndexPath *selectedItem = [tableView indexPathForSelectedRow];
    NSLog(@"selected index path row %d, selectedItem %@", indexPath.row, selectedItem);
    
    if ( [self isPickUpTableView:tableView] )
    {
        //dismiss search results now
        [self.pickUpSearchDisplayController setActive:NO animated:YES];

        self.pickUpMapItem = (MKMapItem *)[self.pickUpPlaces objectAtIndex:indexPath.row];
        self.pickUpSearchBar.text = self.pickUpMapItem.name;
        
        if ( !self.pickUpAnnotation )
        {
            self.pickUpAnnotation = [[MKPointAnnotation alloc]init];
            self.pickUpAnnotation.subtitle = @"pick up location";
        }
        
        if ( self.pickUpMapItem.isCurrentLocation ) {
            NSLog(@"map item is current loc, update lat long manually");
            self.pickUpAnnotation.coordinate = self.userLocation;
        } else
        {
            [self.locationManager stopUpdatingLocation];
            self.pickUpAnnotation.coordinate = self.pickUpMapItem.placemark.coordinate;
        }
        
        self.pickUpAnnotation.title = self.pickUpSearchBar.text;

        [self.mapView addAnnotation:self.pickUpAnnotation];
        
        
        NSLog(@"pick up location lat %f long %f", self.pickUpAnnotation.coordinate.latitude, self.pickUpAnnotation.coordinate.longitude);
        locationInputCount++;
    } else
    {
        [self.dropOffSearchDisplayController setActive:NO animated:YES];
        
        self.dropOffMapItem = (MKMapItem *)[self.dropOffPlaces objectAtIndex:indexPath.row];
        self.dropOffSearchBar.text = self.dropOffMapItem.name;
        
        if ( !self.dropOffAnnotation )
        {
            self.dropOffAnnotation = [[MKPointAnnotation alloc]init];
            self.dropOffAnnotation.subtitle = @"drop off location";
        }

        self.dropOffAnnotation.coordinate = self.dropOffMapItem.placemark.coordinate;
        self.dropOffAnnotation.title = self.dropOffSearchBar.text;

        [self.mapView addAnnotation:self.dropOffAnnotation];
        
        NSLog(@"drop off location lat %f long %f", self.dropOffAnnotation.coordinate.latitude, self.dropOffAnnotation.coordinate.longitude);
        locationInputCount++;
    }

    if (locationInputCount > 1)
        self.findCrewButton.enabled = YES;

}



#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
    locationInputCount = 2;
    [searchBar resignFirstResponder];
    NSLog(@"CANCEL:: pickup %@, dropoff %@", self.pickUpSearchBar.text, self.dropOffSearchBar.text);
    
    if ([self.pickUpSearchBar.text isEqualToString:@""]) {
        NSLog(@"no pickup, grey out find");
        self.findCrewButton.enabled = NO;
        locationInputCount--;
    }
    if ([self.dropOffSearchBar.text isEqualToString:@""]) {
        NSLog(@"no dropoff, grey out find");
        self.findCrewButton.enabled = NO;
        locationInputCount--;
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    //show current location as soon as user taps it
    // TODO: show current location
    NSLog(@"%s", __func__);
    if ( searchBar == self.pickUpSearchBar ) {
        NSLog(@"reload table");
        [self.pickUpSearchDisplayController.searchResultsTableView reloadData];
    }
    
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"%s", __func__);
    
    [searchBar resignFirstResponder];
    
    [self startSearch:searchBar];
}

- (void)startSearch:(UISearchBar *)searchBar
{
    NSString * searchString = searchBar.text;
    
    MKLocalSearchCompletionHandler completionHandler = ^(MKLocalSearchResponse *response, NSError *error)
    {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

        NSLog(@"SEARCH: error %@, response %@", error, response);
        if (error != nil)
        {
            NSString *errorStr = [[error userInfo] valueForKey:NSLocalizedDescriptionKey];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Could not find places"
                                                            message:errorStr
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            if ( searchBar == self.pickUpSearchBar)
            {
                NSLog(@"pick-up search result update");
                [self.pickUpPlaces addObjectsFromArray: response.mapItems];
                [self.pickUpSearchDisplayController.searchResultsTableView reloadData];
            } else
            {
                NSLog(@"drop-off search result update");
                [self.dropOffPlaces addObjectsFromArray: response.mapItems];
                NSLog(@"count %d", self.dropOffPlaces.count);
                [self.dropOffSearchDisplayController.searchResultsTableView reloadData];
            }
        }
    };
    
    NSLog(@"search: <%@>, searching %d", searchString, self.localSearch.searching);
    
    if (self.localSearch.searching)
        [self.localSearch cancel];
 
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = searchString;
    request.region = [self getVisibleMapRegionForUserLocation];
    
    if (self.localSearch != nil)
        self.localSearch = nil;
    
    self.localSearch = [[MKLocalSearch alloc] initWithRequest:request];
    
    [self.localSearch startWithCompletionHandler:completionHandler];
    NSLog(@" searching ....");
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

#pragma mark - MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    MKPointAnnotation *resultPin = [[MKPointAnnotation alloc] init];
    MKPinAnnotationView *result = [[MKPinAnnotationView alloc] initWithAnnotation:resultPin reuseIdentifier:kAnnotationIdentifier];

    result.animatesDrop = YES;
    
    NSLog(@"%s, %@", __func__, annotation.subtitle);

    if ([annotation.subtitle isEqualToString:@"drop off location"])
    {
        result.pinColor = MKPinAnnotationColorGreen;
        [resultPin setCoordinate:self.dropOffAnnotation.coordinate];
        resultPin.title = self.dropOffAnnotation.title;
        resultPin.subtitle = self.dropOffAnnotation.subtitle;

        return result;
    }
    
    if ([annotation.subtitle isEqualToString:@"pick up location"])
    {
        //TODO: use latest coordinates if current location
        result.pinColor = MKPinAnnotationColorRed;
        [resultPin setCoordinate:self.pickUpAnnotation.coordinate];
        resultPin.title = self.pickUpAnnotation.title;
        resultPin.subtitle = self.pickUpAnnotation.subtitle;
        
        return result;
    }

    
    return nil;
}


#pragma mark - Location 

-(void) setupLocationServices
{
    // start by locating user's current position
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
    self.locationManager.activityType = CLActivityTypeFitness;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
	[self.locationManager startUpdatingLocation];
}

- (void) updateMapsViewArea
{
    //NSLog(@"%s", __func__);
    MKCoordinateRegion viewRegion = [self getVisibleMapRegionForUserLocation];
    
    [self.mapView setRegion:viewRegion animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
   // NSLog(@"loc update - %@", locations);
    CLLocation * newLocation = [locations lastObject];
    
    // remember for later -  user's current location
    self.userLocation = newLocation.coordinate;
    
    [self updateMapsViewArea];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    // report any errors returned back from Location Services
    NSLog(@"loc man failed - %@", error);
}


- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    
#warning todo: re-start loc services if needed
    
}

-(MKCoordinateRegion) getVisibleMapRegionForUserLocation
{
    // confine the map search area to the user's current location
    MKCoordinateRegion newRegion;

    newRegion.center.latitude = self.userLocation.latitude;
    newRegion.center.longitude = self.userLocation.longitude;

    // setup the area spanned by the map region:
    // we use the delta values to indicate the desired zoom level of the map,
    //      (smaller delta values corresponding to a higher zoom level)
    //
    newRegion.span.latitudeDelta = 0.112872;
    newRegion.span.longitudeDelta = 0.109863;
    
    return newRegion;
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
        NSString *alertMessage = [NSString stringWithFormat:@"You currently have location services disabled for this %@. Please refer to \"Settings\" app to turn on Location Services.", causeStr];
        
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

#pragma mark - find crew

- (IBAction)findCrewButtonTapped:(UIButton *)sender
{
    
	[self.locationManager stopUpdatingLocation]; // we don't need to update user's current location at this point

}

@end
