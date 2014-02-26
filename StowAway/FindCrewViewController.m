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
@interface FindCrewViewController () <CLLocationManagerDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) CLLocationManager * locationManager;

@property (nonatomic) CLLocationCoordinate2D userLocation;

@property (nonatomic, strong) MKLocalSearch *localSearch;

@property (nonatomic, strong) NSMutableArray /* of MKMapItem */ *places;

@property (nonatomic, assign) MKCoordinateRegion boundingRegion;

@end

static NSString *kCellIdentifier = @"cellIdentifier";

@implementation FindCrewViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.places = [NSMutableArray arrayWithCapacity: 1];
    
    self.navigationController.navigationBarHidden = YES;

    [self setupLocationServices];
    
    // first thing in serach table should be current location
    MKMapItem * currentLoc = [MKMapItem mapItemForCurrentLocation];
    currentLoc.name = @"Current Location";
    [self.places insertObject: currentLoc atIndex:0];
    NSLog(@"count places: %d, %@, %@", [self.places count], self.places,  [MKMapItem mapItemForCurrentLocation]);
}

- (void)viewWillAppear:(BOOL)animated
{
    [self isLocationEnabled];
    
    [self updateMapsViewArea];
}

#pragma mark - UITableView delegate methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"#of rows: %d", [self.places count]);
	return [self.places count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    
    MKMapItem *mapItem = [self.places objectAtIndex:indexPath.row];
    
    NSLog(@"cellForRow [%d] %@", indexPath.row, mapItem);
    
    if (!cell)
        cell = [[UITableViewCell alloc]init];
    
    cell.textLabel.text = mapItem.name;

	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"%s", __func__);
    [self.tableView setHidden:YES];
    // pass the new bounding region to the map destination view controller
    //    self.mapView .boundingRegion = self.boundingRegion;
    
    // pass the individual place to our map destination view controller
    NSIndexPath *selectedItem = [self.tableView indexPathForSelectedRow];
    NSLog(@"index path row %d, selectedItem %@", indexPath.row, selectedItem);
    //  self.mapView.mapItemList = [NSArray arrayWithObject:[self.places objectAtIndex:selectedItem.row]];
    
    //[self.detailSegue perform];
}



#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
    NSLog(@"%s", __func__);
    [self.tableView setHidden:YES];
    
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    NSLog(@"%s", __func__);
    [self.tableView setHidden:NO];
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    NSLog(@"%s", __func__);
    [self.tableView setHidden:YES];

    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)startSearch:(NSString *)searchString
{
    MKLocalSearchCompletionHandler completionHandler = ^(MKLocalSearchResponse *response, NSError *error)
    {
        NSLog(@"****** SEARCH RETURNED ***** error %@, response %@", error, response);
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
            [self.places addObjectsFromArray: [response mapItems]];
            
            [self.tableView reloadData];
        }
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    };

    
    NSLog(@"start serach:: %@, searching %d", searchString, self.localSearch.searching);
    
    if (self.localSearch.searching)
        [self.localSearch cancel];
 
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = searchString;
    request.region = [self getVisibleMapRegionForUserLocation];
    
    if (self.localSearch != nil)
        self.localSearch = nil;
    
    self.localSearch = [[MKLocalSearch alloc] initWithRequest:request];
    
    [self.localSearch startWithCompletionHandler:completionHandler];
    NSLog(@" searching for <%@>", searchString);
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"%s", __func__);
    
    [searchBar resignFirstResponder];
    
    [self startSearch:searchBar.text];
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
    NSLog(@"%s", __func__);
    MKCoordinateRegion viewRegion = [self getVisibleMapRegionForUserLocation];
    
    [self.mapView setRegion:viewRegion animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"loc update - %@", locations);
    CLLocation * newLocation = [locations lastObject];
    
    // remember for later the user's current location
    self.userLocation = newLocation.coordinate;
    
	[manager stopUpdatingLocation]; // we only want one update, to get current location
    
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

#pragma mark - action button

- (IBAction)actionButtonTapped:(UIButton *)sender
{
    
}
@end
