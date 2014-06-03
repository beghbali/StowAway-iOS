//
//  FindingCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "FindingCrewViewController.h"
#import "CountdownTimer.h"
#import "StowawayServerCommunicator.h"
#import "MeetCrewViewController.h"
#import "AppDelegate.h"

#define TOTAL_FACES_COUNT 34
#define FACES_USED_FOR_ANIMATION 16

@interface FindingCrewViewController () <CountdownTimerDelegate, UIAlertViewDelegate, StowawayServerCommunicatorDelegate>

@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages1;
@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages2;
@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages3;


@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *getRideResultActivityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *countDownTimer;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel1;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel2;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel3;
@property (weak, nonatomic) IBOutlet UILabel *rideInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *advertiseFooterLabel;
@property (weak, nonatomic) IBOutlet UILabel *waitingLabel;
@property (weak, nonatomic) IBOutlet UIButton *rideInfoDisclosureButton;

@property (strong, nonatomic) CountdownTimer * cdt;
//@property (strong, nonatomic) NSDate * timerExpiryDate;
@property (strong, nonatomic) UILocalNotification *localNotification;

@property (strong, nonatomic) UILocalNotification *crewFindingTimeoutLocalNotification;

//dictionary contains user_id, fb_id, picture, name, iscaptain, requestedAt time, request_id
@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew; //index 0 being self and upto 3

//my ID's - used for finalize ride and delete request
@property (strong, nonatomic) NSNumber *rideID;
@property (strong, nonatomic) NSNumber *userID;
@property (strong, nonatomic) NSNumber *requestID;

@property (strong, nonatomic) NSDictionary *suggestedLocations;
@property (strong, nonatomic) NSString * locationChannel;
@property (strong, nonatomic) NSNumber *pickUpTime;

@property BOOL isReadyToGoToMeetCrew;

@property BOOL viewDidLoadFinished;

@property (strong, nonatomic) NSTimer * serverPollingTimer;

@end

@implementation FindingCrewViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (IBAction)rideInfoDisclosureButtonTapped:(UIButton *)sender
{
    NSString * msg = [NSString stringWithFormat:@"%@\n%@",
               @"We'll try to fill this ride until 15 minutes before your departure time.",
                      @"Usually your ride will finalize much sooner and you'll get pick up details."];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"More On Finding Crew"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    [alert show];
}

-(void)subscribeToNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteNotification:)
                                                 name:@"updateFindCrew"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedRideCreditsUpdate:)
                                                 name:@"updateRideCredits"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(crewFindingTimedOut:)
                                                 name:@"crewFindingTimedOut"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appReturnsActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(appWillBecomeInActive:)
                                                  name:UIApplicationWillResignActiveNotification
                                                object:nil];
}


- (void)appReturnsActive:(NSNotification *)notification
{
    NSLog(@"%s............%@\n", __func__, self.serverPollingTimer);
    //start the server polling
    [self pollServer];
    
    //schedule to poll the server every 30secs
    self.serverPollingTimer = [NSTimer scheduledTimerWithTimeInterval:kServerPollingIntervalSeconds
                                                               target:self
                                                             selector:@selector(pollServer)
                                                             userInfo:nil
                                                              repeats:YES];
}
- (void)appWillBecomeInActive:(NSNotification *)notification
{
    NSLog(@"%s............%@\n", __func__, self.serverPollingTimer);
    
    //dont poll the server when in the background
    [self.serverPollingTimer invalidate];
}

-(void) viewDidLoad
{
    [super viewDidLoad];
//    NSLog(@"viewdidload - FC_vc %@, rideRequestResponse %@", self, self.rideRequestResponse);
    
    //self.rideInfoDisclosureButton.highlighted = YES;
    
    NSLog(@"%s: ride creds %f, button %@", __func__, self.rideCredits,self.rideCreditsBarButton);
    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];

    [self.getRideResultActivityIndicator stopAnimating];

    //process ride request reply from server -- also sets cd timer value
    [self processRequestObject:self.rideRequestResponse];
    
    //schedule to poll the server every 30secs
    self.serverPollingTimer = [NSTimer scheduledTimerWithTimeInterval:kServerPollingIntervalSeconds
                                                               target:self
                                                             selector:@selector(pollServer)
                                                             userInfo:nil
                                                              repeats:YES];
    
    self.rideInfoLabel.text = [NSString stringWithFormat:@"%@ \n between %@",self.rideTypeLabel, self.rideTimeLabel];;
    
    self.advertiseFooterLabel.text = [NSString stringWithFormat:@"%@\n%@",
                                      @"Get there quickly and comfortably,",
                                      @"while saving 50 to 75% on your ride !"];

    self.waitingLabel.text =[NSString stringWithFormat:@"%@",
                             @"We'll send you notifications as we match you with other riders."];/*,
                             @"Your ride will finalize 15 minutes before departure."];*/
    
    [self pollServer]; //to take care of restoring app case, where server is queried for request object
    
    [self setCrewFindingTimeoutNotification];
    
    [self subscribeToNotifications];
}

//remote push notification
-(void)didReceiveRemoteNotification:(NSNotification *)notification
{
    NSLog(@"%s:  %@", __func__, notification);
    [self processRequestObject:notification.userInfo];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSLog(@"%s: ride creds %f, button %@", __func__, self.rideCredits,self.rideCreditsBarButton);
    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];

    self.viewDidLoadFinished = YES;

    NSLog(@"FindingCrewViewController::view did appear .............., isReadyToGoToMeetCrew %d", self.isReadyToGoToMeetCrew);

    //outlets are loaded, now arm the timer, this is only set once
   // [self armUpCountdownTimer];
    
    //recalculate timer
   // [self reCalculateCDTimer];

    //update the view - pics, names
    [self updateFindingCrewView]; //?? verify that this is not requied -- since on launch due to push, it will be processed
    
    //go to "meet the crew" view
    if ( self.isReadyToGoToMeetCrew && self.viewDidLoadFinished )
        [self performSegueWithIdentifier: @"toMeetCrew" sender: self];
}

- (void)pollServer
{
    //check to see if departure time has passed
    NSDate * now = [NSDate date];
    if ( [now compare:self.rideDepartureDate] == NSOrderedDescending)
    {
        NSLog(@"%s: now %@, departureDate %@", __func__, now, self.rideDepartureDate);

        [self cancelCrewFinding];

        return;
    }
    
    NSLog(@"pollServer:: userid %@, request id %@, ride id %@", self.userID, self.requestID, self.rideID);
    
    if (!self.requestID || !self.userID)
        return;
    
    //if ride id is nil get request object
    if ( self.rideID && (id)(self.rideID) != [NSNull null] )
    {
        NSDictionary * dict = @{kRidePublicId: self.rideID};

        [self processRequestObject:dict];

        return;
    }
    
    //get fresh request object to see if there is a ride
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
    
    [self.getRideResultActivityIndicator startAnimating];
}

#pragma mark - crewfinding timeout notification

-(void)setCrewFindingTimeoutNotification
{
    NSLog(@"%s:<crewFindingTimeoutLocalNotification %@> AT %@", __func__, self.crewFindingTimeoutLocalNotification, self.rideDepartureDate);

    if (!self.crewFindingTimeoutLocalNotification)
        self.crewFindingTimeoutLocalNotification  = [[UILocalNotification alloc] init];
    
    self.crewFindingTimeoutLocalNotification.fireDate              = self.rideDepartureDate;
    self.crewFindingTimeoutLocalNotification.alertBody             = [NSString stringWithFormat:@"Sorry, couldn't find a crew for\n%@", self.rideInfoLabel.text];
    self.crewFindingTimeoutLocalNotification.alertAction           = @"Ok";
    self.crewFindingTimeoutLocalNotification.soundName             = @"ride_missed.wav";
    self.crewFindingTimeoutLocalNotification.timeZone              = [NSTimeZone defaultTimeZone];
    
    [[UIApplication sharedApplication] scheduleLocalNotification:self.crewFindingTimeoutLocalNotification];
}

-(void)unSetCrewFindingTimeoutNotification
{
    NSLog(@"%s:<crewFindingTimeoutLocalNotification %@> AT %@", __func__, self.crewFindingTimeoutLocalNotification, self.rideDepartureDate);
    
    if (!self.crewFindingTimeoutLocalNotification)
        return;
    
    [[UIApplication sharedApplication] cancelLocalNotification:self.crewFindingTimeoutLocalNotification];
    self.crewFindingTimeoutLocalNotification = nil;
}


#pragma mark - stowawayServer

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    [self.getRideResultActivityIndicator stopAnimating];

    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);

    if (sError)
        return;
    
    if ([data objectForKey:kSuggestedDropOffLat])
        [self processRideObject:data];
    else
        [self processRequestObject:data];
}

#pragma mark - process REQUEST

-(void)processRequestObject:(NSDictionary *)response
{
    NSLog(@"processRequestObject........................, isReadyToGoToMeetCrew %d, viewDidLoadFinished %d, rideRequestResponse %@", self.isReadyToGoToMeetCrew, self.viewDidLoadFinished, self.rideRequestResponse);

    if (!response)
    {
        //coming from remote push notification
        self.rideRequestResponse = response = ((AppDelegate *)[UIApplication sharedApplication].delegate).fakeRideRequestResponse;
    }
    
    self.isReadyToGoToMeetCrew = NO;
    
    id nsNullObj = (id)[NSNull null];
    
    if ( !self.crew )
    {
        //this is the immediate ride request response
        NSLog(@"process immediate ride req response, create crew array");
        self.crew = [NSMutableArray arrayWithCapacity: 1];
        self.userID = [response objectForKey:kUserPublicId];
        self.requestID = [response objectForKey:kPublicId];

        if (!self.requestID)
            self.requestID = [[NSUserDefaults standardUserDefaults] objectForKey:kRequestPublicId];
        
        //parse the response to fill in SELF request_id, user_id
        NSLog(@"self.requestID %@, self.userID %@", self.requestID, self.userID );
        NSDictionary * dict = @{kRequestPublicId: self.requestID,
                                kUserPublicId: self.userID};
        NSMutableDictionary * mutableDict = [NSMutableDictionary dictionaryWithDictionary:dict];
        [self.crew insertObject:mutableDict atIndex:0];
    }
    
    NSNumber * ride_id = [response objectForKey:kRidePublicId];
    self.rideID = ride_id;
    NSLog(@"request ride result for ride_id %@", ride_id);
    
    if ( ride_id && (ride_id != nsNullObj) )
    { // there is a match - GET RIDE result
        //TODO: stowaway server communicator should handle this -- getRideObject, also used in meet crew
        NSLog(@"there is a match - get ride result");
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, ride_id];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
        
        [self.getRideResultActivityIndicator startAnimating];
        return;
    }
    
    // there is no match -  REMOVE the crew
    if (self.crew.count > 1)
    {
        // this is possible when there was just one match, and that person canceled the ride
        NSLog(@"there was just one match, and that person canceled the ride, remove crew from view");
        while ( self.crew.count > 1 )
            [self.crew removeLastObject];
        
        [self updateFindingCrewView];
        
        [self setCrewFindingTimeoutNotification];
        
        //[self cancelTimerExpiryNotificationSchedule];
    }
}

#pragma mark - process RIDE

-(void)processRideObject:(NSDictionary *)response
{
    NSLog(@"processRideObject......................................");

    //no need for crew finding failed notifcation
    [self unSetCrewFindingTimeoutNotification];
    
    NSLog(@"crew before processing: %@", self.crew);
    
    //array of user_public_id
    NSMutableArray * dontRemoveCrewIndexList = [NSMutableArray arrayWithCapacity:2];
    
    NSArray * requests = [response objectForKey:@"requests"];
    
    NSUInteger countRequests = requests.count;
    NSUInteger countCrew = self.crew.count;
    
    NSLog(@"crew# %lu, rideResult# %lu", (unsigned long)countCrew, (unsigned long)countRequests);
    
    //ADD NEW MEMBERS
    for ( NSUInteger i = 0; i < countRequests; i++)
    {
        BOOL alreadyExistsInCrew = NO;
        NSDictionary * request = [requests objectAtIndex:i];
        
        //latest designation
        NSString * designation = [request objectForKey:kDesignation];
        BOOL isCaptain = ( designation && (designation != (id)[NSNull null]) && [designation isEqualToString:kDesignationCaptain] );
        
        for (int j = 0; j < countCrew; j++)
        {
            NSMutableDictionary * crewMember = [self.crew objectAtIndex:j];
        
            //UPDATE existing crew member
            if ( [[crewMember objectForKey:kUserPublicId] compare:[request objectForKey:kUserPublicId]] == NSOrderedSame )
            {
                [dontRemoveCrewIndexList addObject:[crewMember objectForKey:kUserPublicId]];
                
                //update  - as this might be after a getting launched from push, also designation might have changed
                [crewMember setObject:[request objectForKey:kRequestedAt] forKey: kRequestedAt];

                [crewMember setObject:[request objectForKey:kCouponCodeKey] forKey: kCouponCodeKey];

                [crewMember setObject:[NSNumber numberWithBool:isCaptain] forKey: kIsCaptain];

                [crewMember setObject:[request objectForKey:kPublicId] forKey: kRequestPublicId];

                alreadyExistsInCrew = YES;
                break;  // already exists
            }
        }
        
        if (alreadyExistsInCrew)
            continue;
            
        //new member in ride response, add this to crew
        NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary:
                                        @{  kFbId:              [request objectForKey:kFbId],
                                            kUserPublicId:      [request objectForKey:kUserPublicId],
                                            kRequestedAt:       [request objectForKey:kRequestedAt],
                                            kRequestPublicId:   [request objectForKey:kPublicId],
                                            kIsCaptain:         [NSNumber numberWithBool:isCaptain]
                                        }
                                      ];
   
        [dontRemoveCrewIndexList addObject:[request objectForKey:kUserPublicId]]; //add the new member to dont remove list
        
        [self.crew addObject:dict];
    }

    //REMOVE STALE MEMBERS
    for (int j = 0; j < self.crew.count; j++)
    {
        BOOL removeIt = YES;
        NSDictionary * crewMember = [self.crew objectAtIndex:j];
        
        for (int i = 0; i < dontRemoveCrewIndexList.count; i++)
        {
            if ( [[crewMember objectForKey:kUserPublicId] compare:[dontRemoveCrewIndexList objectAtIndex:i]] == NSOrderedSame )
            {
                removeIt = NO;
                break;
            }
        }
        
        if (!removeIt)
            continue;
        
        //remove the crew member
        [self.crew removeObjectAtIndex:j];
        j--;
    }
    NSLog(@"** crew after processing ** - %@", self.crew);
    
    //UPDATE VIEW with updated crew and new cd time
    [self updateFindingCrewView];

    //save loc channel, suggested locn, if the ride is FULFILLED
    NSString * rideStatus = [response objectForKey:kStatus];
    if ( [rideStatus isEqualToString:KStatusFulfilled] || [rideStatus isEqualToString:kStatusCheckedin] )//kStatusCheckedin in case of lonerider
    {
        NSLog(@"ride status %@ (viewDidLoadFinished %d)...... we are ready to go to 'meet your crew'",rideStatus, self.viewDidLoadFinished);
        
        self.isReadyToGoToMeetCrew = YES;
        
        //cancel timer expiry notif
        //[self cancelTimerExpiryNotificationSchedule];
        
        // get suggested locn
        self.suggestedLocations = @{kSuggestedDropOffAddr: [response objectForKey:kSuggestedDropOffAddr],
                                    kSuggestedDropOffLong: [response objectForKey:kSuggestedDropOffLong],
                                    kSuggestedDropOffLat: [response objectForKey:kSuggestedDropOffLat],
                                    kSuggestedPickUpAddr: [response objectForKey:kSuggestedPickUpAddr],
                                    kSuggestedPickUpLong: [response objectForKey:kSuggestedPickUpLong],
                                    kSuggestedPickUpLat: [response objectForKey:kSuggestedPickUpLat]};
        
        //pick up time
        self.pickUpTime = [response objectForKey:kSuggestedPickUpTime];
        NSLog(@"%s: %@", __func__, self.pickUpTime);
        
        //get loc channel
        self.locationChannel = [response objectForKey:kLocationChannel];
        
        //go to "meet the crew" view if view has been loaded
        if (self.viewDidLoadFinished)
            [self performSegueWithIdentifier: @"toMeetCrew" sender: self];

    }
}

#pragma mark prepare meetCrew view

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ( [segue.identifier isEqualToString:@"toMeetCrew"] )
    {
        if ([segue.destinationViewController class] == [MeetCrewViewController class])
        {
            MeetCrewViewController * meetCrewVC = segue.destinationViewController;
            
            meetCrewVC.userID   = self.userID;
            meetCrewVC.rideID   = self.rideID;
            meetCrewVC.requestID   = self.requestID;
            meetCrewVC.crew     = self.crew;
            meetCrewVC.locationChannel  = self.locationChannel;
            meetCrewVC.suggestedLocations = self.suggestedLocations;
            
            meetCrewVC.rideCredits = self.rideCredits;

            NSTimeInterval pickUpTimeDouble = [self.pickUpTime intValue];
            NSDate * date = [NSDate dateWithTimeIntervalSince1970:pickUpTimeDouble];
            
            NSDateFormatter * df = [[NSDateFormatter alloc]init];
            [df setDateStyle:NSDateFormatterNoStyle];
            [df setTimeStyle:NSDateFormatterShortStyle];
            meetCrewVC.rideTimeLabel = [df stringFromDate:date];
            
            [self.serverPollingTimer invalidate];
            
            [self unSetCrewFindingTimeoutNotification];
        }
    }
}

#pragma mark animation

void swap (NSUInteger *a, NSUInteger *b)
{
    NSUInteger temp = *a;
    *a = *b;
    *b = temp;
}

-(void) setupAnimationForImageNumber:(NSUInteger)imageNumber
{
    // images to be circulated
    NSMutableArray * faces = [[NSMutableArray alloc] initWithCapacity:TOTAL_FACES_COUNT];
    for (int i=1; i < TOTAL_FACES_COUNT; i++)
        [faces addObject:[NSString stringWithFormat:@"%d.png",i] ];
    
    //non repeating random numbers
    NSUInteger shuffledNumbers[TOTAL_FACES_COUNT];
    for (NSUInteger i = 0 ; i < TOTAL_FACES_COUNT; i++)
        shuffledNumbers[i] = i;
  
    uint32_t randBoundary = (uint32_t)(TOTAL_FACES_COUNT-1);
    while ( randBoundary > 1)
    {
        NSUInteger randIndex = arc4random_uniform(randBoundary); // rand between 0 - (randboundary-1)
        
        randBoundary--;

        swap(&shuffledNumbers[randBoundary], &shuffledNumbers[randIndex]);
    }

    switch (imageNumber)
    {
        case 1:
            if ( self.animationImages1 )
                return;
            
            self.animationImages1 = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < FACES_USED_FOR_ANIMATION; i++)
                [self.animationImages1 addObject:[UIImage imageNamed:[faces objectAtIndex:shuffledNumbers[i]]]];
            
            break;
       
        case 2:
            if ( self.animationImages2 )
                return;
            
            self.animationImages2 = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < FACES_USED_FOR_ANIMATION; i++)
                [self.animationImages2 addObject:[UIImage imageNamed:[faces objectAtIndex:shuffledNumbers[i]]]];

            break;
        
        case 3:
            if ( self.animationImages3 )
                return;
            
            self.animationImages3 = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < FACES_USED_FOR_ANIMATION; i++)
                [self.animationImages3 addObject:[UIImage imageNamed:[faces objectAtIndex:shuffledNumbers[i]]]];

            break;
            
        default:
            break;
    }
}


-(void) startAnimatingImageForCrewNumber:(NSUInteger)crewNumber
{
    UIImageView * imageView = nil;
    
    [self setupAnimationForImageNumber:crewNumber];
    
    switch (crewNumber)
    {
        case 1:
            imageView = self.imageView1;
            imageView.animationImages   = self.animationImages1;

            break;

        case 2:
            imageView = self.imageView2;
            imageView.animationImages   = self.animationImages2;

            break;
            
        case 3:
            imageView = self.imageView3;
            imageView.animationImages   = self.animationImages3;

            break;
            
        default:
            break;
    }
    
    imageView.animationDuration = kFindingCrewFacesAnimationDelay;
    
    [imageView startAnimating];
}


-(void) stopAnimatingImage:(UIImageView *)imageView
{
    [imageView stopAnimating];
}

#pragma mark countdown timer

-(void)reCalculateCDTimer
{
    double rideRequestedAt = [[[self.crew objectAtIndex:0] objectForKey:kRequestedAt] doubleValue];
    double minRideRequestedAt = rideRequestedAt;
    
    for (int i = 1; i < self.crew.count; i++)
    {
        double iRideRequestedAt = [[[self.crew objectAtIndex:i] objectForKey:kRequestedAt] doubleValue];
        NSLog(@"iRide_req_at %f, minRideReq %f, i%d", iRideRequestedAt, minRideRequestedAt, i);
        //compare self with the other crew members requested time, we want the minimum req time
        if ( iRideRequestedAt < minRideRequestedAt )
            minRideRequestedAt = iRideRequestedAt;
    }
    
    if ( minRideRequestedAt == rideRequestedAt)
    {
        NSLog(@"%s: there was no ride requested before mine, so dont change CDT", __func__);
        return;
    }
    
    NSTimeInterval secondsToExpire = (int)[[Environment ENV] lookup:@"kCountdownTimerToDepartureInSecs"] - (rideRequestedAt - minRideRequestedAt);
    
    self.cdt.countDownEndDate = [NSDate dateWithTimeIntervalSinceNow:secondsToExpire];;
    
    NSLog(@"reCalculateCDTimer:secondsToExpire %f, expiry date %@ ***", secondsToExpire, self.cdt.countDownEndDate);
}

-(void) armUpCountdownTimer
{
    NSLog(@"armUpCountdownTimer");
   
    self.cdt = [[CountdownTimer alloc] init];
    
    self.cdt.cdTimerDelegate = self;
    
    [self.cdt initializeWithSecondsRemaining: (int)[[Environment ENV] lookup:@"kCountdownTimerToDepartureInSecs"]
                                    ForLabel:self.countDownTimer];

    [self setTimerExpiryNotification];
}

- (void)countdownTimerExpired
{
    NSLog(@"%s, crew <%lu> %@", __func__, (unsigned long)self.crew.count, self.crew);

    //self.countDownTimer.text = @"00:00";

    //check if there is atleast one match
    if ( self.crew.count > 1)
    {
        [self cancelTimerExpiryNotificationSchedule];
        
        //going to meet crew
        [self.serverPollingTimer invalidate];
        
        // ask server for roles
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@/finalize", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.rideID];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"PUT"];
        
        [self.getRideResultActivityIndicator startAnimating];
        
        return;
    }
    
    /*
    //if there are no matches, ask user if they want to wait more
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Matches Yet !"
                                                    message:@"Do you want to wait a bit more ?"
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
    */
    
    [self sendCoupon:kCouponCodeLoneRider];
}


#pragma mark ride cancel

- (IBAction)cancelButtonTapped:(UIButton *)sender
{
    //warn user
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cancel Crew Finding !"
                                                    message:@"Do you really want to ride alone ?"
                                                   delegate:self
                                          cancelButtonTitle:@"Yes"
                                          otherButtonTitles:@"No", nil];
    [alert show];
}

-(void)cancelCrewFinding
{
    //DELETE ride request
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];    //don't need the callback, so no delegate
    
    //erase it from memory, so its not used in app restoration
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRequestPublicId];
    [[NSUserDefaults standardUserDefaults] synchronize];

    //cancel local notif
    //[self cancelTimerExpiryNotificationSchedule];
    
    [self unSetCrewFindingTimeoutNotification];
    
    //cancel server polling- going back to requests
    [self.serverPollingTimer invalidate];
    
    //go back to enter drop off pick up view
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

-(void)sendCoupon:(NSString *)couponCode
{
    //cancel local notif
    //[self cancelTimerExpiryNotificationSchedule];

    //send couponed request
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.requestID];
    
    NSString *couponRequest = [NSString stringWithFormat:@"{\"%@\": \"%@\"}",
                                                     kCouponCodeKey, couponCode];
    

    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];

    sscommunicator.sscDelegate = self;

    [sscommunicator sendServerRequest:couponRequest ForURL:url usingHTTPMethod:@"PUT"];    //don't need the callback, so no delegate
}

-(void)crewFindingTimedOut:(NSNotification *)notification
{
    NSLog(@"%s..............data %@", __func__, notification);
    
    [self cancelCrewFinding];
}

#pragma mark timer expiry localnotification

- (void)setTimerExpiryNotification
{
    NSLog(@"%s:<self.localNotification %@> AT %@", __func__, self.localNotification, self.cdt.countDownEndDate);
    
    if ( self.localNotification )
        [[UIApplication sharedApplication] cancelLocalNotification:self.localNotification];
    
    self.localNotification = [[UILocalNotification alloc] init];
    self.localNotification.fireDate = self.cdt.countDownEndDate;
    self.localNotification.alertBody = @"Your Immediate Action Required !!";
    self.localNotification.soundName = @"action_required.wav";
    [[UIApplication sharedApplication] scheduleLocalNotification:self.localNotification];

    NSLog(@"%s:SET -- <self.localNotification %@> ", __func__, self.localNotification);

}

- (void)cancelTimerExpiryNotificationSchedule
{
    self.cdt.cdTimerDelegate = nil;

    NSLog(@"cancelTimerExpiryNotificationSchedule %@ .....", self.localNotification);
    
    if ( !self.localNotification )
        return;
    
    [[UIApplication sharedApplication] cancelLocalNotification:self.localNotification];
    self.localNotification = nil;
}


#pragma mark update view

//crew and timer
-(void)updateFindingCrewView
{
    NSLog(@"updateFindingCrewView.................");
    
    //go through the crew array, set fb pic, name, stop/start animation as required
    for (NSUInteger i = 1; i < self.crew.count; i++)
    {
        NSDictionary * crewMember = [self.crew objectAtIndex:i];

        if ([crewMember objectForKey:kCrewFbImage] && [crewMember objectForKey:kCrewFbName])
        {
            NSLog(@"we already have the fb image and name for crewMember %lu", (unsigned long)i);
            continue;
        }

        [self setCrewImageAndName:i withFbUID:[crewMember objectForKey:kFbId]];
    }
    
    for (NSUInteger i = self.crew.count; i < kMaxCrewCount; i++)
    {
        NSLog(@"RESET crew#%lu ........", (unsigned long)i);

        //reset the images to animate and also reset the name to finding....
        switch (i) {
            case 1:
                [self startAnimatingImageForCrewNumber:1];
                self.nameLabel1.text = nil;
                break;
                
            case 2:
                [self startAnimatingImageForCrewNumber:2];
                self.nameLabel2.text = nil;
                break;
                
            case 3:
                [self startAnimatingImageForCrewNumber:3];
                self.nameLabel3.text = nil;
                break;

            default:
                break;
        }
    }
}


// this function can block main queue
-(void)setCrewImageAndName:(NSUInteger)crewPostion withFbUID:(NSString *)fbUID
{
    NSError* error;

    NSLog(@"find out crew#%lu's image+name with FBUID %@", (unsigned long)crewPostion, fbUID);
   
    NSURL *profilePicURL    = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?width=160&height=160", fbUID]];
    NSData *profilePicData = [NSData dataWithContentsOfURL:profilePicURL];
    UIImage *profilePic = [[UIImage alloc] initWithData:profilePicData] ;

    NSURL *firstNameURL     = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@", fbUID]];
    NSData *firstNameData = [NSData dataWithContentsOfURL:firstNameURL];
    NSDictionary* jsonDict = [NSJSONSerialization
                          JSONObjectWithData:firstNameData
                          options:kNilOptions
                          error:&error];
    NSString * fbFirstName = nil;

    if (jsonDict && !error)
        fbFirstName = [jsonDict objectForKey:@"first_name"];

    if (!fbFirstName)
        fbFirstName = @"!jack!";
    
    switch (crewPostion)
    {
        case 1:
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                NSLog(@"set crew#%lu's image+name %@", (unsigned long)crewPostion, fbFirstName);

                [self stopAnimatingImage:self.imageView1];
                
                self.imageView1.image   = profilePic;
                self.imageView1.layer.cornerRadius = self.imageView1.frame.size.height /2;
                self.imageView1.layer.masksToBounds = YES;
                self.imageView1.layer.borderWidth = 1;
                self.imageView1.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                self.nameLabel1.text    = fbFirstName;
            });
        }
            break;
            
        case 2:
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                [self stopAnimatingImage:self.imageView2];
                
                self.imageView2.image   = profilePic;
                self.imageView2.layer.cornerRadius = self.imageView2.frame.size.height /2;
                self.imageView2.layer.masksToBounds = YES;
                self.imageView2.layer.borderWidth = 1;
                self.imageView2.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                self.nameLabel2.text    = fbFirstName;
            });
        }
            break;
            
        case 3:
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                [self stopAnimatingImage:self.imageView3];
                
                self.imageView3.image   = profilePic;
                self.imageView3.layer.cornerRadius = self.imageView3.frame.size.height /2;
                self.imageView3.layer.masksToBounds = YES;
                self.imageView3.layer.borderWidth = 1;
                self.imageView3.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                self.nameLabel3.text    = fbFirstName;
            });
        }
            break;
            
        default:
            break;
    }
    
    NSMutableDictionary * mutableDict = [NSMutableDictionary dictionaryWithDictionary:[self.crew objectAtIndex:crewPostion]];
    
    if (profilePic)
        [mutableDict setObject:profilePic forKey:kCrewFbImage];
    
    [mutableDict setObject:fbFirstName forKey:kCrewFbName];
    [self.crew replaceObjectAtIndex:crewPostion withObject:mutableDict];
}


#pragma mark alert delegates

-(void)alertView:(UIAlertView *)theAlert clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"For alert %@, The %@ button was tapped.", theAlert.title, [theAlert buttonTitleAtIndex:buttonIndex]);
    
    //TODO: change all the constant texts to constant keys in a string file, that can be used for localization as well
    if ([theAlert.title isEqualToString:@"Cancel Crew Finding !"])
    {
        if ([[theAlert buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
            [self cancelCrewFinding];
    }
    
    if ([theAlert.title isEqualToString:@"No Matches Yet !"])
    {
        if ([[theAlert buttonTitleAtIndex:buttonIndex] isEqualToString:@"No"])
            [self sendCoupon:kCouponCodeLoneRider];
        else
            [self armUpCountdownTimer]; //re-start the 5mins timer
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


-(void)receivedRideCreditsUpdate:(NSNotification *)notification
{
    NSLog(@"%s..............data %@", __func__, notification);
    
    self.rideCredits = [[notification.userInfo objectForKey:@"credits"] doubleValue];
    
    NSLog(@"%s: ride creds %f, button %@", __func__, self.rideCredits,self.rideCreditsBarButton);
    
    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];
}


@end
