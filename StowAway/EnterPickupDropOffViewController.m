//
//  EnterPickupDropOffViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/24/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "EnterPickupDropOffViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "StowawayServerCommunicator.h"
#import "FindingCrewViewController.h"
#import "SWRevealViewController.h"
#import "LoginViewController.h"

#define METERS_PER_MILE 1609.344
#define SHOW_MILES_OF_MAP_VIEW 0.6
#define MAP_VIEW_REGION_DISTANCE (SHOW_MILES_OF_MAP_VIEW * METERS_PER_MILE)

//ride to work, service time
NSInteger startingMorningHrs = 6;  //6:00 - 6:15 am can be the first slot
NSInteger endingMorningHrs = 11; //10:45 - 11:00 am will be the last slot
//ride to home, service time
NSInteger startingEveningHrs = 15; //3:00 - 3:15 pm would be the first slot
NSInteger endingEveningHrs = 22; //9:45 - 10pm would be the last slot


typedef enum : NSUInteger
{
    kRideType_ToWorkToday,
    kRideType_ToHomeToday,
    kRideType_ToWorkTomorrow,
    kRideType_ToHomeTomorrow
} kRideTypeIndex;

static NSString *kCellIdentifier = @"cellIdentifier";
static NSString *kAnnotationIdentifier = @"annotationIdentifier";

@interface EnterPickupDropOffViewController () <CLLocationManagerDelegate,
                                                MKMapViewDelegate,
                                                StowawayServerCommunicatorDelegate,
                                                UISearchBarDelegate, UISearchDisplayDelegate>/*,
                                                UIPickerViewDelegate, UIPickerViewDataSource>*/

@property (weak, nonatomic) IBOutlet UIPickerView *timePickerView;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *pickUpSearchBar;
@property (weak, nonatomic) IBOutlet UISearchBar *dropOffSearchBar;
@property (weak, nonatomic) IBOutlet UIButton *findCrewButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *rideRequestActivityIndicator;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *revealButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rideCreditsBarButton;
@property double rideCredits;

@property (strong, nonatomic) CLLocationManager * locationManager;

@property BOOL isUsingCurrentLoc;
@property (nonatomic) CLLocationCoordinate2D userLocation;

@property (nonatomic, strong) MKLocalSearch *localSearch;

@property (nonatomic, strong) NSMutableArray /* of MKMapItem */ *pickUpPlaces;
@property (nonatomic, strong) NSMutableArray /* of MKMapItem */ *dropOffPlaces;

@property (nonatomic, strong) id pickUpLocItem;
@property (nonatomic, strong) id dropOffLocItem;

@property (nonatomic, strong) MKPointAnnotation * pickUpAnnotation;
@property (nonatomic, strong) MKPointAnnotation * dropOffAnnotation;

@property (strong, nonatomic) IBOutlet UISearchDisplayController *dropOffSearchDisplayController;
@property (strong, nonatomic) IBOutlet UISearchDisplayController *pickUpSearchDisplayController;

@property (strong, nonatomic) NSDictionary * rideRequestResponse;

@property (nonatomic, strong) NSMutableArray * availableRideTimesLabel;
@property (nonatomic, strong) NSMutableArray * availableRideTimesAbsoluteTime;
@property (nonatomic, strong) NSArray * rideTypes;
@property (weak, nonatomic) IBOutlet UIButton *leftRideTypeButton;
@property (weak, nonatomic) IBOutlet UIButton *rightRideTypeButton;
@property (weak, nonatomic) IBOutlet UILabel *rideTypeLabel;
@property (weak, nonatomic) IBOutlet UILabel *rideTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *decreaseRideTimeButton;
@property (weak, nonatomic) IBOutlet UIButton *increaseRideTimeButton;
@property NSUInteger startingRideTypeIndex;
@property BOOL isUsingNextRideType;
@property NSUInteger currentRideTimeIndex;
@property BOOL isRideTimeConfigured;

@property NSInteger nowHrs;
@property NSInteger nowMins;
@property NSInteger startingAvailabilityHrs;
@property NSInteger startingAvailabilityMins;
@property NSInteger endingAvailabilityHrs;
@property (strong, nonatomic) NSDateComponents *nowDateComponents;
@property BOOL isPreviousAppStateValid;
@property BOOL isWaitingForRideCreditQueryToReturn;

@property (strong, nonatomic) NSDate *rideDepartureDate;

@end


@implementation EnterPickupDropOffViewController

int locationInputCount = 0;
BOOL onBoardingStatusChecked = NO;

#pragma mark - setup view

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(void)setUpRevealMenuButton
{
    [self.revealButtonItem setTarget: self.revealViewController];
    [self.revealButtonItem setAction: @selector( revealToggle: )];
    [self.navigationController.navigationBar addGestureRecognizer: self.revealViewController.panGestureRecognizer];
}

-(void)setUpPlacesSearch
{
    NSArray * locationHistory = [[NSUserDefaults standardUserDefaults] objectForKey:kPickUpLocationHistoryToHome];

    self.pickUpPlaces   = [NSMutableArray arrayWithArray:locationHistory];
    self.dropOffPlaces  = [NSMutableArray arrayWithArray:locationHistory];
    
    [self addCurrentLocToPickUpPlaces];
}

-(void)addCurrentLocToPickUpPlaces
{
    // first thing in serach table should be current location
    MKMapItem * currentLoc = [MKMapItem mapItemForCurrentLocation];
    currentLoc.name = kPickUpDefaultCurrentLocation;
    [self.pickUpPlaces insertObject: currentLoc atIndex:0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSLog(@"%s......", __func__);

    //set text as white - looks better when background is blue
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setTextColor:[UIColor whiteColor]];
    
    [self setUpRevealMenuButton];
    
    [self.rideRequestActivityIndicator stopAnimating];
    
    [self setUpPlacesSearch];
    
   // [self configureAvailableRideTimes];
    self.isRideTimeConfigured = YES;
    self.rideTypes = @[@"Your Ride To Work Today",
                       @"Your Ride Home Today",
                       @"Your Ride To Work Tomorrow",
                       @"Your Ride Home Tomorrow"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appReturnsActive:) name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
/*
 [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillBecomeInActive:) name:UIApplicationWillResignActiveNotification
                                               object:nil];
*/
}

- (void)appWillBecomeInActive:(NSNotification *)notification
{
    NSLog(@"--******--%s............", __func__);
    [self destroyCoreLocationManager];

}
- (void)appReturnsActive:(NSNotification *)notification
{
    NSLog(@"---------%s............", __func__);
    
    //dont recalculate immediately after VDL
    if (!self.isRideTimeConfigured)
        [self configureScheduledRidesOptions];
}

-(BOOL)isRestoringPreviousAppState
{
    NSNumber * requestID = [[NSUserDefaults standardUserDefaults] objectForKey:kRequestPublicId];
    NSNumber * userID = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
    
    NSLog(@"%s: requestID %@, userID %@", __func__, requestID, userID);
    
    if (requestID && userID)
    {
        NSNumber * requestedForNum = [[NSUserDefaults standardUserDefaults] objectForKey:kRequestedForDate];
        NSTimeInterval requestedFor = [requestedForNum doubleValue];
        NSTimeInterval currentTimeInterval = [[NSDate date]timeIntervalSince1970];
        NSLog(@"%s: requestedFor %f, currentTimeInterval %f", __func__, requestedFor, currentTimeInterval);

        if ( currentTimeInterval < requestedFor)
        {
            //all conditions satify to restore previous ride request
            self.isPreviousAppStateValid = YES;
            self.rideRequestResponse = @{kPublicId: requestID, kUserPublicId: userID};
            
            //segue to finding crew
            [self performSegueWithIdentifier: @"toFindingCrew" sender: self];
            return YES;
        }
    }
    return NO;
}

-(void)viewDidAppear:(BOOL)animated
{
    NSLog(@"%s......, onBoardingStatusChecked %d", __func__, onBoardingStatusChecked);
    
    [super viewDidAppear:YES];
    
    [self checkOnboardingStatus];

    [self queryRideCredits];

    if ([self isRestoringPreviousAppState])
        return;

    [self updateFindCrewButtonEnabledState];

    //forget that ride was finalized
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:kIsRideFinalized];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if ( onBoardingStatusChecked )
        [self setUpLocationServices];
    
    [self configureScheduledRidesOptions];
    
    self.isRideTimeConfigured = NO;
}

#pragma mark - onboarding check

-(BOOL)isUserLoggedIn
{
    NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];

    if ( publicUserId && [LoginViewController isFBLoggedIn] )
    {
        NSLog(@"%s: fb already logged in, publicUserId %@", __func__, publicUserId);
        return YES;
    } else {
        NSLog(@"%s: fb NOT logged in, publicUserId %@", __func__, publicUserId);
        return NO;
    }
}

-(void)checkOnboardingStatus
{
    NSLog(@"%s...... onBoardingStatusChecked %d ", __func__, onBoardingStatusChecked);

    if (onBoardingStatusChecked)
    {
        NSLog(@"has already checked onboarding status");
        return;
    }
    
    //check ONBOARDING DONE ?
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
  
    onBoardingStatusChecked = YES;

    if ( ![self isUserLoggedIn] )
    {
        onBoardingStatusChecked = NO;
        [self performSegueWithIdentifier: @"onboarding_tutorial" sender: self];
    }
    else
    {
        if (![[userDefaults objectForKey:kOnboardingStatusReceiptsDone]boolValue] )
        {
            onBoardingStatusChecked = NO;
            [self performSegueWithIdentifier: @"onboarding_receipts" sender: self];
        }
        else
        {
            if (![[userDefaults objectForKey:kOnboardingStatusPaymentDone]boolValue] )
            {
                onBoardingStatusChecked = NO;
                [self performSegueWithIdentifier: @"onboarding_payment" sender: self];
            }
            else if (![[userDefaults objectForKey:kOnboardingStatusTermsDone]boolValue] )
            {
                onBoardingStatusChecked = NO;
                [self performSegueWithIdentifier: @"onboarding_terms" sender: self];
            }
        }
    }    
    
    NSLog(@"%s......######## onBoardingStatusChecked %d ", __func__, onBoardingStatusChecked);
}

+(void)setOnBoardingStatusChecked:(BOOL)yesOrNo
{
    NSLog(@"setOnBoardingStatusChecked %d", yesOrNo);
    onBoardingStatusChecked = yesOrNo;
}

#pragma mark - Ride Time Buttons
- (IBAction)leftRideTypeButtonTapped:(UIButton *)sender
{
    NSLog(@"%s: startingRideTypeIndex %ld", __func__, (long)self.startingRideTypeIndex);
    
    self.rideTypeLabel.text = self.rideTypes[self.startingRideTypeIndex];
    self.isUsingNextRideType = NO;
    
    self.rightRideTypeButton.enabled = YES;
    self.leftRideTypeButton.enabled = NO;

    //update the ride availability times for the new ride type
    [self configureScheduledRidesOptions];
}

- (IBAction)rightRideTypeButtonTapped:(UIButton *)sender
{
    NSLog(@"%s: startingRideTypeIndex %ld", __func__, (long)self.startingRideTypeIndex);

    self.rideTypeLabel.text = self.rideTypes[self.startingRideTypeIndex + 1];
    self.isUsingNextRideType = YES;
    
    self.leftRideTypeButton.enabled = YES;
    self.rightRideTypeButton.enabled = NO;
    
    //update the ride availability times for the new ride type
    [self configureScheduledRidesOptions];
}

- (IBAction)decreaseRideTimeButtonTapped:(UIButton *)sender
{
    if (self.currentRideTimeIndex)
    {
        self.currentRideTimeIndex--;
        self.rideTimeLabel.text = self.availableRideTimesLabel[self.currentRideTimeIndex];
    }
    
    if (self.currentRideTimeIndex == 0)
        sender.enabled = NO;
    
    self.increaseRideTimeButton.enabled = YES;

    NSLog(@"%s: currentRideTimeIndex %ld, %@", __func__, (long)self.currentRideTimeIndex, self.rideTimeLabel.text);

}

- (IBAction)increaseRideTimeButtonTapped:(UIButton *)sender
{
    self.currentRideTimeIndex++;
    self.rideTimeLabel.text = self.availableRideTimesLabel[self.currentRideTimeIndex];

    if (self.currentRideTimeIndex == (self.availableRideTimesLabel.count -1) )
        sender.enabled = NO;
    
    self.decreaseRideTimeButton.enabled = YES;
    
    NSLog(@"%s: currentRideTimeIndex %ld, %@", __func__, (long)self.currentRideTimeIndex, self.rideTimeLabel.text);
    
}


#pragma mark - Ride Scheduling

-(void)calculateCurrentHrsMins
{
    //(1) Get current hrs and mins
    NSDate * now = [NSDate date];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    self.nowDateComponents = [calendar components:(NSDayCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSMonthCalendarUnit) fromDate:now];
    
    self.nowHrs = self.nowDateComponents.hour;
    self.nowMins = self.nowDateComponents.minute;
    
    NSLog(@"%s: now [%@], hrs %ld, mins %ld", __func__, [dateFormatter stringFromDate:now], (long)self.nowHrs, (long)self.nowMins);
}

-(void)calculateRideType
{
    //(2) history -- look at the last ride home & work and check the time
    BOOL hasTakenRideToWorkToday = NO;
    BOOL hasTakenRideToHomeToday = NO;
    
    //(3) get ride type
    if ( (self.nowHrs < endingMorningHrs-1) || (self.nowHrs < endingMorningHrs && self.nowMins < 31) )
    {
        //morning time - 0~10:59am
        self.startingRideTypeIndex = hasTakenRideToWorkToday ? kRideType_ToHomeToday: kRideType_ToWorkToday;
    }
    else if( (self.nowHrs < endingEveningHrs-1) || ( self.nowHrs < endingEveningHrs && self.nowMins < 31) )
    {
        //day time -  after 11am and before 9:45pm
        self.startingRideTypeIndex = hasTakenRideToHomeToday ? kRideType_ToWorkTomorrow: kRideType_ToHomeToday;
    } else
    {
        // 10pm to midnight
        self.startingRideTypeIndex = kRideType_ToWorkTomorrow;
    }
    
    self.rideTypeLabel.text = self.rideTypes[self.startingRideTypeIndex];
    NSLog(@"%s: startingRideTypeIndex %ld [%@].......", __func__, (long)self.startingRideTypeIndex, self.rideTypeLabel.text);
}

-(void)calculateAvailableRideTimesRangeFor:(NSUInteger)rideTypeIndex
{
    //(4) available ride time range
    switch (rideTypeIndex)
    {
        case kRideType_ToWorkToday:
            
            self.startingAvailabilityHrs    = MAX(self.nowHrs, startingMorningHrs);
            self.startingAvailabilityMins   = (self.nowHrs < startingMorningHrs)? -1: self.nowMins;
            self.endingAvailabilityHrs      = endingMorningHrs;
            
            break;
            
        case kRideType_ToHomeToday:
            
            self.startingAvailabilityHrs    = MAX(self.nowHrs, startingEveningHrs);
            self.startingAvailabilityMins   = (self.nowHrs < startingEveningHrs)? -1: self.nowMins;
            self.endingAvailabilityHrs      = endingEveningHrs;
            
            break;
            
        case kRideType_ToWorkTomorrow:
            
            self.startingAvailabilityHrs    = startingMorningHrs;
            self.startingAvailabilityMins   = -1;
            self.endingAvailabilityHrs      = endingMorningHrs;
            
            break;
            
        case kRideType_ToHomeTomorrow:
            
            self.startingAvailabilityHrs    = startingEveningHrs;
            self.startingAvailabilityMins   = -1;
            self.endingAvailabilityHrs      = endingEveningHrs;
            
            break;
            
        default:
            break;
    }
    
    NSLog(@"BEFORE modularizing:: starting hrs %ld, starting mins %ld, endingAvailabilityHrs %ld ******* ",
          (long)self.startingAvailabilityHrs, (long)self.startingAvailabilityMins, (long)self.endingAvailabilityHrs);
    
    if (self.startingAvailabilityMins == -1)
    {
        //future hrs, so start mins is 0
        self.startingAvailabilityMins = 0;
    }
    else
    {
        if (self.startingAvailabilityMins == 0)
        {
            //0 mins
            self.startingAvailabilityMins = 15;
        }
        else
        {
            NSInteger fraction = (self.startingAvailabilityMins / 15);
            if ((self.startingAvailabilityMins % 15) == 0)
                fraction--; //to take care of transitions 15,30,45 mins
            switch (fraction)
            {
                case 0:
                    //1-15 mins
                    self.startingAvailabilityMins = 30;
                    break;
                    
                case 1:
                    //16-30 mins
                    self.startingAvailabilityMins = 45;
                    break;
                    
                case 2:
                    //31-45 mins
                    self.startingAvailabilityMins = 0;
                    self.startingAvailabilityHrs++;
                    break;
                    
                case 3:
                    //46-59 mins
                    self.startingAvailabilityMins = 15;
                    self.startingAvailabilityHrs++;
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    NSLog(@"AFTER modularizing:: starting hrs %ld, starting mins %ld ******* ", (long)self.startingAvailabilityHrs, (long)self.startingAvailabilityMins);
}

-(void)calculateAvailableRideTimesStrings
{
    //(5) creating ride availability time strings array
    NSUInteger nxtHrs = self.startingAvailabilityHrs;
    NSUInteger nxtMins = self.startingAvailabilityMins ;
    NSUInteger historicalHrs = 0;
    NSUInteger historicalMins = 0;
    
    //read the history
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    if ( nxtHrs > 12 )
    {
        historicalHrs = [[standardDefaults objectForKey: kLastRideToHomeHrs] intValue] + 12;
        historicalMins = [[standardDefaults objectForKey: kLastRideToHomeMins] intValue];
    }
    else {
        historicalHrs = [[standardDefaults objectForKey: kLastRideToWorkHrs] intValue];
        historicalMins = [[standardDefaults objectForKey: kLastRideToWorkMins] intValue];
    }
    self.currentRideTimeIndex = 0;  //should be based on history
    NSLog(@"%s: history: %lu:%lu", __func__, (unsigned long)historicalHrs, (unsigned long)historicalMins);
    
    self.availableRideTimesLabel = nil;
    self.availableRideTimesLabel = [NSMutableArray arrayWithCapacity:1];
    
    while ( self.startingAvailabilityHrs < self.endingAvailabilityHrs )
    {
        if (self.startingAvailabilityMins == 45)
        {
            nxtHrs ++;
            nxtMins = 0;
        } else
            nxtMins +=15;
        
        [self.availableRideTimesLabel addObject:[NSString stringWithFormat:@"%ld:%02ld - %u:%02lu %@",
                                                 (long)(self.startingAvailabilityHrs > 12)? (self.startingAvailabilityHrs-12): (long)self.startingAvailabilityHrs,
                                                 (long)self.startingAvailabilityMins,
                                                 (nxtHrs > 12)? (nxtHrs-12):nxtHrs ,
                                                 (unsigned long)nxtMins,
                                                 (nxtHrs>12)?@"pm":@"am"]];
        
        if (self.startingAvailabilityHrs == historicalHrs && self.startingAvailabilityMins == historicalMins)
            self.currentRideTimeIndex = self.availableRideTimesLabel.count -1;

        self.startingAvailabilityHrs = nxtHrs;
        self.startingAvailabilityMins = nxtMins;
    }
    
    NSLog(@"%s: availableRideTimesLabel %@, self.currentRideTimeIndex %lu", __func__, self.availableRideTimesLabel, (unsigned long)self.currentRideTimeIndex);
    
    self.rideTimeLabel.text = self.availableRideTimesLabel[self.currentRideTimeIndex];
    
    //enable/disable the +/- buttons
    self.increaseRideTimeButton.enabled = (self.availableRideTimesLabel.count > 1)? YES: NO;
    self.decreaseRideTimeButton.enabled = self.currentRideTimeIndex? YES: NO;
}

-(void)configureScheduledRidesOptions
{
    NSLog(@"%s: +++++++++ isUsingNextRideType %d ++++++++++++", __func__, self.isUsingNextRideType);

    //(1)
    [self calculateCurrentHrsMins];

    if (!self.isUsingNextRideType)
    {
        //(2, 3)
        [self calculateRideType];
    }
    
    //auto-fill the locations based on the history and ride type
    [self autoFillLocationPoints];
    
    //(4)
    [self calculateAvailableRideTimesRangeFor:self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex];
    
    //(5)
    [self calculateAvailableRideTimesStrings];
}

-(NSDate *)calculateRequestedRideDate
{
    NSDate * choosenRideDate = nil;
    NSString * choosenTime = self.availableRideTimesLabel[self.currentRideTimeIndex];
    NSUInteger choosenRideType = self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex;
    
    NSLog(@"%s: %@ [%lu], %@", __func__, self.rideTypes[choosenRideType], (unsigned long)choosenRideType, choosenTime);
    
    NSArray * tokens = [choosenTime componentsSeparatedByString:@" "];
    NSString * startTime = [tokens firstObject];
    NSString * am_pm = [tokens objectAtIndex:3];
    BOOL isPM = [am_pm isEqualToString:@"pm"];
    tokens = [startTime componentsSeparatedByString:@":"];
    NSString * choosenHrs = [tokens firstObject];
    NSString * choosenMins = [tokens lastObject];
    
    NSLog(@"%s: %@ %@ %@ %d", __func__, choosenHrs, choosenMins, am_pm, isPM);

    //remember the ride time history
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:choosenHrs forKey: isPM? kLastRideToHomeHrs: kLastRideToWorkHrs];
    [standardDefaults setObject:choosenMins forKey: isPM? kLastRideToHomeMins: kLastRideToWorkMins];
    [standardDefaults synchronize];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    self.nowDateComponents.hour = isPM? [choosenHrs intValue]+12: [choosenHrs intValue];
    self.nowDateComponents.minute = [choosenMins intValue];
   
    if (choosenRideType > kRideType_ToHomeToday)        //tomorrow
        self.nowDateComponents.day++;
    
    NSLog(@"choosen componenets : hours %ld, minutes %ld, month %ld, year %ld, day %ld", (long)self.nowDateComponents.hour, (long)self.nowDateComponents.minute, (long)self.nowDateComponents.month, (long)self.nowDateComponents.year, (long)self.nowDateComponents.day);
    
    choosenRideDate = [calendar dateFromComponents:self.nowDateComponents];
    NSLog(@"choosen ride date: %@", [dateFormatter stringFromDate:choosenRideDate]);

    return choosenRideDate;
}

-(void)autoFillLocationPoints
{
    BOOL isRideToWork = YES;
    
    NSUInteger choosenRideType = self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex;

    if (choosenRideType == kRideType_ToHomeToday || choosenRideType == kRideType_ToHomeTomorrow)
        isRideToWork = NO;
    
    id lastPickUpLocation = [[[NSUserDefaults standardUserDefaults] objectForKey:isRideToWork? kPickUpLocationHistoryToWork: kPickUpLocationHistoryToHome] firstObject]; //first of array of mapitem
    id lastDropOffLocation = [[[NSUserDefaults standardUserDefaults] objectForKey:isRideToWork? kDropOffLocationHistoryToWork: kDropOffLocationHistoryToHome] firstObject]; //first of array of mapitem

    NSLog(@"%s:isRideToWork %d lastPickUpLocation %@, lastDropOffLocation %@", __func__, isRideToWork, lastPickUpLocation, lastDropOffLocation);
    
    if (lastPickUpLocation)
    {
        self.pickUpLocItem = lastPickUpLocation;
        [self setLocationPoint:YES];
    }
    
    if (lastDropOffLocation)
    {
        self.dropOffLocItem = lastDropOffLocation;
        [self setLocationPoint:NO];
    }
    [self updateFindCrewButtonEnabledState];
}


#pragma mark - location history

-(BOOL)updateLocationHistoryWithLocItem:(id)locItem isForPickUp:(BOOL)isPickUp
{
    NSString *  placeName   = nil;
    MKMapItem * mkMapItem   = nil;
    NSString *  historyKey  = nil;
    
    if ( ![locItem isKindOfClass:[MKMapItem class]] ) //an loc from history
    {
        placeName = [locItem objectForKey:kLocationHistoryName];

    } else
    { //map searched item
        mkMapItem = (MKMapItem *)locItem;
        placeName = mkMapItem.name;
    }
    
    if (!placeName)
    {
        NSLog(@"%s: NIL place name", __func__);

        return NO;
    }
    
    
    //determine key based on ispickup and ride type to work/home
    NSUInteger choosenRideType = self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex;
    if ( choosenRideType == kRideType_ToHomeToday || choosenRideType == kRideType_ToHomeTomorrow )
    {
        historyKey = isPickUp ? kPickUpLocationHistoryToHome: kDropOffLocationHistoryToHome;
    }
    else
    {
        historyKey = isPickUp ? kPickUpLocationHistoryToWork: kDropOffLocationHistoryToWork;
    }
    NSLog(@"%s: historyKey[%@]", __func__, historyKey);

    //if the place already exists in the history
    NSArray * existingHistoryMatch = [self getFilteredLocationHistoryFor:placeName isForPickUp:isPickUp isExactMatchRequired:YES];
    if( existingHistoryMatch && existingHistoryMatch.count )
    {
        NSMutableArray * locationHistory = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:historyKey]]; //array of mapitem
       
        NSUInteger indexFound = [locationHistory indexOfObject:existingHistoryMatch.firstObject];
        //move this entry to the begining
        NSLog(@"%s: existingHistoryMatch %@.............indexFound %lu", __func__, existingHistoryMatch, (unsigned long)indexFound);
        
        if ( (indexFound != NSNotFound) && indexFound > 0)
        {
            NSLog(@"%s: move it to the begining of the history array", __func__);
            [locationHistory removeObjectAtIndex:indexFound];
            [locationHistory insertObject:existingHistoryMatch.firstObject atIndex:0];
            
            [[NSUserDefaults standardUserDefaults] setObject:locationHistory forKey:historyKey];
            return YES;
        }
        return NO;
    }
    
    //a new loc, so add it to
    NSDictionary *locDict = nil;
    if (mkMapItem && mkMapItem.placemark.coordinate.latitude && mkMapItem.placemark.coordinate.longitude)
        locDict = @{kLocationHistoryName: mkMapItem.name,
                  kLocationHistoryLatitude: [NSNumber numberWithDouble: mkMapItem.placemark.coordinate.latitude],
                  kLocationHistoryLongitude: [NSNumber numberWithDouble: mkMapItem.placemark.coordinate.longitude]};
    else
    {
        NSLog(@"ERROR--- new loc to be added to history[%@] is nil !!!", historyKey);

        return NO;
    }
    
   
    NSMutableArray * locHistory     = [NSMutableArray arrayWithCapacity:1];
    NSArray * prevLocationHistory   = [[NSUserDefaults standardUserDefaults] objectForKey:historyKey];
    [locHistory addObjectsFromArray:prevLocationHistory];

    [locHistory insertObject:locDict atIndex:0];
    if (locHistory.count > kLocationHistorySize)
        [locHistory removeLastObject];
    
    [[NSUserDefaults standardUserDefaults] setObject:locHistory forKey:historyKey];
    
    NSLog(@"%s: '%@' --> %@", __func__, historyKey, locHistory);

    return YES;
}

-(void)updateLocationHistory
{
    BOOL isDropOffHistoryUpdated = NO;
    BOOL isPickUpHistoryUpdated = NO;
    
    //drop off loc
    isDropOffHistoryUpdated = [self updateLocationHistoryWithLocItem:self.dropOffLocItem isForPickUp:NO];
    
    //pick up loc
    isPickUpHistoryUpdated = [self updateLocationHistoryWithLocItem:self.pickUpLocItem isForPickUp:YES];

    //write it
    if (isPickUpHistoryUpdated || isDropOffHistoryUpdated)
    {
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"%s: written to memory", __func__);
    }
}

-(NSString *)getLocationItemName:(id)locItem
{
    if ( [locItem isKindOfClass:[NSDictionary class]])
        return [locItem objectForKey:kLocationHistoryName];
    
    MKMapItem * mp = (MKMapItem *)locItem;
    return mp.name;
}

-(CLLocationCoordinate2D)getLocationItemCoordinate:(id)locItem
{
    if ( [locItem isKindOfClass:[NSDictionary class]]) //from history
    {
        if ([[locItem objectForKey:kLocationHistoryName] isEqualToString:kPickUpDefaultCurrentLocation])
        {
            NSLog(@"map item in history is current loc, use latest self lat long");
            self.isUsingCurrentLoc = YES;
            return self.userLocation;
        }
        
        return CLLocationCoordinate2DMake([[locItem objectForKey:kLocationHistoryLatitude] doubleValue],
                                          [[locItem objectForKey:kLocationHistoryLongitude] doubleValue]);
    }

    
    MKMapItem * mp = (MKMapItem *)locItem;
    if ( mp.isCurrentLocation ) //from search result
    {
        NSLog(@"map item is current loc, update lat long manually");
        self.isUsingCurrentLoc = YES;
        return self.userLocation;
    }
    return mp.placemark.coordinate;
}


-(NSArray *)getFilteredLocationHistoryFor:(NSString *)searchString isForPickUp:(BOOL)isPickUp isExactMatchRequired:(BOOL)exactMatch
{
    NSArray * filteredLoc = nil;
    NSPredicate *predicate = nil;
    
    //determine key based on ispickup and ride type to work/home
    NSString * historyKey = nil;
    NSUInteger choosenRideType = self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex;
    if (choosenRideType == kRideType_ToHomeToday || choosenRideType == kRideType_ToHomeTomorrow)
        historyKey = isPickUp ? kPickUpLocationHistoryToHome: kDropOffLocationHistoryToHome;
    else
        historyKey = isPickUp ? kPickUpLocationHistoryToWork: kDropOffLocationHistoryToWork;
    
    NSArray * locationHistory = [[NSUserDefaults standardUserDefaults] objectForKey:historyKey]; //array of mapitem
    NSLog(@"%s:looking for \"%@\" in [%@] of size %lu" , __func__, searchString, historyKey, (unsigned long)locationHistory.count);
    
    if (locationHistory)
    {
        if (exactMatch)
            predicate = [NSPredicate predicateWithFormat:@"%K MATCHES[cd] %@", kLocationHistoryName, searchString];
        else
            predicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", kLocationHistoryName, searchString];
        
        filteredLoc = [locationHistory filteredArrayUsingPredicate:predicate];
    }
    
    
    NSLog(@"%s: found %lu %@", __func__, (unsigned long)filteredLoc.count, exactMatch?@"MATCHES":@"CONTAINS");
    
    return filteredLoc;
}

#pragma mark - Search Result

-(BOOL) isPickUpTableView:(UITableView *)tableView
{
    return (self.pickUpSearchDisplayController.searchResultsTableView == tableView);
}

-(NSArray *) getPlacesForTableView:(UITableView *)tableView
{
    NSArray * places = nil;
    
    if ( [self isPickUpTableView: tableView] )
    {
        places = self.pickUpPlaces;
    }
    else
    {
        places = self.dropOffPlaces;
    }

    return places;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self getPlacesForTableView:tableView].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    
    id locItem = [[self getPlacesForTableView:tableView] objectAtIndex:indexPath.row];
    
    if (!cell) {
        cell = [[UITableViewCell alloc]init];
    }
    
    cell.textLabel.text = [self getLocationItemName:locItem];

	return cell;
}

-(void)setLocationPoint:(BOOL)isPickUpPoint
{
    MKPointAnnotation * mkPA;
    if (isPickUpPoint)
    {
        if ( !self.pickUpAnnotation )
        {
            self.pickUpAnnotation = [[MKPointAnnotation alloc]init];
            self.pickUpAnnotation.subtitle = @"pick up location";
        }
        mkPA = self.pickUpAnnotation;
        mkPA.coordinate = [self getLocationItemCoordinate:self.pickUpLocItem];
        mkPA.title = self.pickUpSearchBar.text = [self getLocationItemName:self.pickUpLocItem];
    }
    else
    {
        if ( !self.dropOffAnnotation )
        {
            self.dropOffAnnotation = [[MKPointAnnotation alloc]init];
            self.dropOffAnnotation.subtitle = @"drop off location";
        }
        mkPA = self.dropOffAnnotation;
        mkPA.coordinate = [self getLocationItemCoordinate:self.dropOffLocItem];
        mkPA.title = self.dropOffSearchBar.text = [self getLocationItemName:self.dropOffLocItem];
    }
    
    [self.mapView addAnnotation:mkPA];
    [self.mapView selectAnnotation:mkPA animated:YES];
    
    NSLog(@"isPickUpPoint %d, lat %f, long %f",isPickUpPoint, mkPA.coordinate.latitude, mkPA.coordinate.longitude);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( [self isPickUpTableView:tableView] )
    {
        //dismiss search results now
        [self.pickUpSearchDisplayController setActive:NO animated:YES];

        //which one was selected
        self.pickUpLocItem = [self.pickUpPlaces objectAtIndex:indexPath.row];
        
        if ( !self.pickUpAnnotation )
        {
            self.pickUpAnnotation = [[MKPointAnnotation alloc]init];
            self.pickUpAnnotation.subtitle = @"pick up location";
        }
        
        self.isUsingCurrentLoc = NO; //get loc will set it to yes if needed
        self.pickUpAnnotation.coordinate = [self getLocationItemCoordinate:self.pickUpLocItem];
        self.pickUpAnnotation.title = self.pickUpSearchBar.text = [self getLocationItemName:self.pickUpLocItem];

        [self.mapView addAnnotation:self.pickUpAnnotation];
        [self.mapView selectAnnotation:self.pickUpAnnotation animated:YES];
        
        NSLog(@"pick up location lat %f long %f", self.pickUpAnnotation.coordinate.latitude, self.pickUpAnnotation.coordinate.longitude);
    } else
    {
        [self.dropOffSearchDisplayController setActive:NO animated:YES];
        
        self.dropOffLocItem = [self.dropOffPlaces objectAtIndex:indexPath.row];
        
        if ( !self.dropOffAnnotation )
        {
            self.dropOffAnnotation = [[MKPointAnnotation alloc]init];
            self.dropOffAnnotation.subtitle = @"drop off location";
        }

        self.dropOffAnnotation.coordinate = [self getLocationItemCoordinate:self.dropOffLocItem];
        self.dropOffAnnotation.title = self.dropOffSearchBar.text = [self getLocationItemName:self.dropOffLocItem];

        [self.mapView addAnnotation:self.dropOffAnnotation];
        [self.mapView selectAnnotation:self.dropOffAnnotation animated:YES];
        
        NSLog(@"drop off location lat %f long %f", self.dropOffAnnotation.coordinate.latitude, self.dropOffAnnotation.coordinate.longitude);
    }

    [self updateFindCrewButtonEnabledState];
}



#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
   // NSLog(@"searchText %@, length %d", searchText, searchText.length);
    
    /*
    // don't do actual network search untill 2 chars entered
    if (searchText.length < 2)
        return;
    */
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startSearch:) object:searchBar];
    
    //wait for 0.5sec before actual search starts over the network
    [self performSelector:@selector(startSearch:) withObject:searchBar afterDelay:0.5];
    
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
    [searchBar resignFirstResponder];
    NSLog(@"CANCEL:: pickup %@, dropoff %@", self.pickUpSearchBar.text, self.dropOffSearchBar.text);
    
    [self updateFindCrewButtonEnabledState];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    //show current location as soon as user taps it
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( searchBar == self.pickUpSearchBar)
            [self.pickUpSearchDisplayController.searchResultsTableView reloadData];
        else
            [self.dropOffSearchDisplayController.searchResultsTableView reloadData];
    });
    
    [searchBar setShowsCancelButton:YES animated:YES];
    
    [self updateFindCrewButtonEnabledState];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
    [self updateFindCrewButtonEnabledState];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    
    [searchBar resignFirstResponder];
    
    [self startSearch:searchBar];
}

- (void)startSearch:(UISearchBar *)searchBar
{
    NSString * searchString = searchBar.text;
    
    MKLocalSearchCompletionHandler completionHandler = ^(MKLocalSearchResponse *response, NSError *error)
    {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

        NSLog(@"SEARCH returned %lu results: error %@", (unsigned long)response.mapItems.count, error);
        
        if (error != nil)
        {
            NSString *errorStr = [[error userInfo] valueForKey:NSLocalizedDescriptionKey];
            NSLog(@"%s: error %@", __func__, errorStr);
           /* 
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Could not find places"
                                                            message:errorStr
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            */
        }
        else
        {
            if ( searchBar == self.pickUpSearchBar)
            {
                //add natural language map search result
                [self.pickUpPlaces addObjectsFromArray: response.mapItems];
                
                [self.pickUpSearchDisplayController.searchResultsTableView reloadData];

            } else
            {
                //add natural language map search result
                [self.dropOffPlaces addObjectsFromArray: response.mapItems];
                
                [self.dropOffSearchDisplayController.searchResultsTableView reloadData];
            }
        }
    };
    
    NSLog(@"search: <%@>, is searching %d", searchString, self.localSearch.searching);
    
    if ( searchBar == self.pickUpSearchBar)
    {
        //clear the array before adding new result
        [self.pickUpPlaces removeAllObjects];
        
        //add current loc
        [self addCurrentLocToPickUpPlaces];
        
        //add places matching from the history to this array
        NSArray * existingHistoryMatch = [self getFilteredLocationHistoryFor:searchString isForPickUp:YES isExactMatchRequired:NO];
        [self.pickUpPlaces addObjectsFromArray: existingHistoryMatch];
        
        [self.pickUpSearchDisplayController.searchResultsTableView reloadData];
        
    } else
    {
        //clear the array before adding new result
        [self.dropOffPlaces removeAllObjects];
        
        //add places matching from the history to this array
        NSArray * existingHistoryMatch = [self getFilteredLocationHistoryFor:searchString isForPickUp:NO isExactMatchRequired:NO];
        [self.dropOffPlaces addObjectsFromArray: existingHistoryMatch];
        
        [self.dropOffSearchDisplayController.searchResultsTableView reloadData];
    }
    
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

#pragma mark - Map View

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
/*
    // If it's the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]])
    {
        NSLog(@"its a user location");
        return nil;
    }
    // Handle any custom annotations.
    if ([annotation isKindOfClass:[MKPointAnnotation class]])
    {
        // Try to dequeue an existing pin view first.
        MKAnnotationView *pinView = (MKAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:kAnnotationIdentifier];
        if (!pinView)
        {
            // If an existing pin view was not available, create one.
            pinView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kAnnotationIdentifier];
            pinView.canShowCallout = YES;

            NSString * imageName = [annotation.subtitle isEqualToString:@"drop off location"]? @"dropOffCustomMapPinImage.png": @"pickUpCustomMapPinImage.png";
            pinView.image = [UIImage imageNamed:imageName];
        } else {
            pinView.annotation = annotation;
        }
        return pinView;
    }
    
    return nil;
    
*/
    //TODO: reuse kAnnotationIdentifier
    
    MKPointAnnotation *resultPin = [[MKPointAnnotation alloc] init];
    MKPinAnnotationView *result = [[MKPinAnnotationView alloc] initWithAnnotation:resultPin reuseIdentifier:kAnnotationIdentifier];

    result.animatesDrop = YES;
    result.canShowCallout = YES;

    if ([annotation.subtitle isEqualToString:@"drop off location"])
    {
        result.pinColor = MKPinAnnotationColorRed;
        
        //resultPin.coordinate = self.dropOffAnnotation.coordinate;
       // resultPin.title = self.dropOffAnnotation.title;
       // resultPin.subtitle = self.dropOffAnnotation.subtitle;

        return result;
    }
    
    if ([annotation.subtitle isEqualToString:@"pick up location"])
    {
        result.pinColor = MKPinAnnotationColorGreen;
        self.isUsingCurrentLoc = NO;

        if ( [annotation.title isEqualToString:kPickUpDefaultCurrentLocation])
        {
            NSLog(@"%s: use the latest user location", __func__);
            resultPin.coordinate = self.userLocation;
            self.isUsingCurrentLoc = YES;
        }
        //else
          //  resultPin.coordinate = self.pickUpAnnotation.coordinate;
        
        //resultPin.title = self.pickUpAnnotation.title;
        //resultPin.subtitle = self.pickUpAnnotation.subtitle;
        
        return result;
    }
    return nil;
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

- (void) updateMapsViewArea
{
   // NSLog(@"%s", __func__);
    MKCoordinateRegion viewRegion = [self getVisibleMapRegionForUserLocation];
    
    [self.mapView setRegion:viewRegion animated:YES];
}


#pragma mark - Location 

-(void)setUpLocationServices
{
    NSLog(@"%s", __func__);

    [self isLocationEnabled];
    
    self.mapView.showsUserLocation = YES;
    
    [self setupCoreLocationManager];
    
    [self updateMapsViewArea];
}

-(void) destroyCoreLocationManager
{
    NSLog(@"%s", __func__);
    
    [self.locationManager stopUpdatingLocation];
    
    self.locationManager = nil;
}

-(void) setupCoreLocationManager
{
    // start by locating user's current position
    if (self.locationManager) {
        NSLog(@"%s: location manager is not null", __func__);
        return;
    }

    NSLog(@"%s", __func__);

	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
    self.locationManager.activityType = CLActivityTypeOther;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
	[self.locationManager startUpdatingLocation];
    self.userLocation = self.locationManager.location.coordinate; //get cached location first
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation * newLocation = [locations lastObject];
    
    // remember for later -  user's current location
    if( newLocation )
        self.userLocation = newLocation.coordinate;
    
    [self updateMapsViewArea];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    // report any errors returned back from Location Services
    NSLog(@"loc manager failed - %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    
//TODO: re-start loc services if needed
    
}

-(BOOL) isLocationEnabled
{
    NSString *causeStr = nil;
    
    // check whether location services are enabled on the device
    if ([CLLocationManager locationServicesEnabled] == NO)
    {
        causeStr = @"this device";
    }
    // check the application’s explicit authorization status:
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
    {
        causeStr = @"Stowaway";
    }
    
    if (causeStr != nil)
    {
        NSString *alertMessage = [NSString stringWithFormat:@"You have location services disabled for %@.\nPlease turn it on at \"Settings > Privacy > Location Services\"", causeStr];
        
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

#pragma mark - Find Crew

-(void)updateFindCrewButtonEnabledState
{
    locationInputCount = 2;
    
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
    
    if (locationInputCount > 1)
        self.findCrewButton.enabled = YES;
}

- (IBAction)findCrewButtonTapped:(UIButton *)sender
{
    [self updateLocationHistory];
    self.rideDepartureDate = [self calculateRequestedRideDate];
    NSTimeInterval requested_for = [self.rideDepartureDate timeIntervalSince1970];
    NSNumber * requestForNum = [NSNumber numberWithFloat:requested_for];
    NSLog(@"requestedRideDate %@, requested_for %f", self.rideDepartureDate, requested_for);
  
    //save requested for time, will be used in app restoration
    [[NSUserDefaults standardUserDefaults] setObject:requestForNum forKey:kRequestedForDate];
    [[NSUserDefaults standardUserDefaults] synchronize];

    //prepare the ride request query
    NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
        
    NSString *url = [NSString stringWithFormat:@"%@%@/requests", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], publicUserId];
    
    NSLog(@"%s: isUsingCurrentLoc %d", __func__, self.isUsingCurrentLoc);
    
    NSString *rideRequest = [NSString stringWithFormat:@"{\"request\": {\"%@\":\"%@\", \"%@\":\"%@\", \"%@\":%f, \"%@\":%f, \"%@\":%f, \"%@\":%f, \"%@\":%f, \"%@\":%d }}",
                             kPickUpAddress, self.pickUpAnnotation.title,
                             kDropOffUpAddress, self.dropOffAnnotation.title,
                             kPickUpLat, self.isUsingCurrentLoc? self.userLocation.latitude: self.pickUpAnnotation.coordinate.latitude,
                             kPickUpLong, self.isUsingCurrentLoc? self.userLocation.longitude: self.pickUpAnnotation.coordinate.longitude,
                             kDropOffLat, self.dropOffAnnotation.coordinate.latitude,
                             kDropOffLong, self.dropOffAnnotation.coordinate.longitude,
                             kRequestedForDate, requested_for,
                             kRequestDuration, (15*60)];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:rideRequest ForURL:url usingHTTPMethod:@"POST"];
    
    [self.rideRequestActivityIndicator startAnimating];
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
   
    if (self.isWaitingForRideCreditQueryToReturn && !sError && [self processUserObject:data])
    {
        self.isWaitingForRideCreditQueryToReturn = NO;
      
        return;
    }

    [self.rideRequestActivityIndicator stopAnimating];
    
    // set data to processed in the next view
    if ( sError == NULL )
    {
        self.rideRequestResponse = data;
     
        //segue to finding crew
        [self performSegueWithIdentifier: @"toFindingCrew" sender: self];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"%s........", __func__);
    
    [self destroyCoreLocationManager]; //we don't need to update user's current location at this point

    if ( [segue.identifier isEqualToString:@"toFindingCrew"] )
    {
        if ([segue.destinationViewController class] == [FindingCrewViewController class])
        {
            FindingCrewViewController * findingCrewVC = segue.destinationViewController;
           
            findingCrewVC.rideRequestResponse = self.rideRequestResponse;
            NSNumber * requestID = [self.rideRequestResponse objectForKey:kPublicId];

            findingCrewVC.rideCredits = self.rideCredits; //for going to FC vc thru usual flow
            
            if (!self.isPreviousAppStateValid)
            {
                //new request
                NSString * choosenTime = self.availableRideTimesLabel[self.currentRideTimeIndex];
                NSUInteger choosenRideType = self.isUsingNextRideType? (self.startingRideTypeIndex+1): self.startingRideTypeIndex;
                
                findingCrewVC.rideTypeLabel = self.rideTypes[choosenRideType];
                findingCrewVC.rideTimeLabel = choosenTime;

                findingCrewVC.rideDepartureDate = self.rideDepartureDate;
                
                //remember the ride id, ride time label and ride type label -- so it can be used to restore the app
                [[NSUserDefaults standardUserDefaults] setObject:requestID forKey:kRequestPublicId];
                [[NSUserDefaults standardUserDefaults] setObject:findingCrewVC.rideTypeLabel forKey:@"rideTypeLabel"];
                [[NSUserDefaults standardUserDefaults] setObject:findingCrewVC.rideTimeLabel forKey:@"rideTimeLabel"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else
            {
                //old request
                findingCrewVC.rideTypeLabel = [[NSUserDefaults standardUserDefaults] objectForKey:@"rideTypeLabel"];
                findingCrewVC.rideTimeLabel = [[NSUserDefaults standardUserDefaults] objectForKey:@"rideTimeLabel"];
            }
        }
    }
}

#pragma mark - ride credits
- (IBAction)rideCreditsBarButtonTapped:(UIBarButtonItem *)sender
{
    NSString * msg = nil;
   
    if(self.rideCredits)
        msg = [NSString stringWithFormat:@"You have $%0.2f to spend on stowaway rides.\n%@",
               self.rideCredits,
               @"Your credit card would only be charged after this credit has been applied."];
    else
        msg = @"Your current credit balance is $0. Credits can be applied to pay for rides.";
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ride Credits"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    [alert show];
}

-(void)queryRideCredits
{
    NSLog(@"%s........", __func__);
    NSNumber * userID = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
    
    NSString *url = [NSString stringWithFormat:@"%@%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], userID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    self.isWaitingForRideCreditQueryToReturn = YES;
   [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
}

-(BOOL)processUserObject: (NSDictionary *)data
{
    NSNumber * rideCreditNum = [data objectForKey:@"credits"];
    NSLog(@"%s: rideCreditNum %@", __func__, rideCreditNum);

    if (!rideCreditNum)
        return NO; //still waiting
    
    self.rideCredits = [rideCreditNum doubleValue];

    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateRideCredits"
                                                        object:self
                                                      userInfo:@{@"credits": rideCreditNum}]; //for going to FC immediately during app state restoration
    
    return YES;

}

@end
