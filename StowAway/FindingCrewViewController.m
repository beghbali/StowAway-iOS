//
//  FindingCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "FindingCrewViewController.h"
#import "CountdownTimer.h"
#import "StowawayConstants.h"
#import "StowawayServerCommunicator.h"
#import "MeetCrewViewController.h"
#import "AppDelegate.h"

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

@property (strong, nonatomic) CountdownTimer * cdt;
//@property (strong, nonatomic) NSDate * timerExpiryDate;
@property (strong, nonatomic) UILocalNotification *localNotification;
//dictionary contains user_id, fb_id, picture, name, iscaptain, requestedAt time, request_id
@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew; //index 0 being self and upto 3

//my ID's - used for finalize ride and delete request
@property (strong, nonatomic) NSNumber *rideID;
@property (strong, nonatomic) NSNumber *userID;
@property (strong, nonatomic) NSNumber *requestID;

@property (strong, nonatomic) NSDictionary *suggestedLocations;
@property (strong, nonatomic) NSString * locationChannel;

@property BOOL isReadyToGoToMeetCrew;

@property BOOL viewDidLoadFinished;

@property (strong, nonatomic) NSTimer * serverPollingTimer;

@end

@implementation FindingCrewViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}


-(void) viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"viewdidload - FC_vc %@, rideRequestResponse %@", self, self.rideRequestResponse);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteNotification:)
                                                 name:@"updateFindCrew"
                                               object:nil];
    
    [self.getRideResultActivityIndicator stopAnimating];

    //process ride request reply from server -- also sets cd timer value
    [self processRequestObject:self.rideRequestResponse];
    
    //schedule to poll the server every 30secs
    self.serverPollingTimer = [NSTimer scheduledTimerWithTimeInterval:kServerPollingIntervalSeconds
                                                               target:self
                                                             selector:@selector(pollServer)
                                                             userInfo:nil
                                                              repeats:YES];
}

-(void)didReceiveRemoteNotification:(NSNotification *)notification
{
    NSLog(@"%s:  %@", __func__, notification);
    [self processRequestObject:notification.userInfo];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.viewDidLoadFinished = YES;

    NSLog(@"FindingCrewViewController::view did appear .............., isReadyToGoToMeetCrew %d", self.isReadyToGoToMeetCrew);

    //outlets are loaded, now arm the timer, this is only set once
    [self armUpCountdownTimer];
    
    //recalculate timer
    [self reCalculateCDTimer];

    //update the view - pics, names
    [self updateFindingCrewView]; //?? verify that this is not requied -- since on launch due to push, it will be processed
    
    //go to "meet the crew" view
    if ( self.isReadyToGoToMeetCrew && self.viewDidLoadFinished )
        [self performSegueWithIdentifier: @"toMeetCrew" sender: self];
}

- (void)pollServer
{
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
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", kStowawayServerApiUrl_users, self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
    
    [self.getRideResultActivityIndicator startAnimating];
}

#pragma mark stowawayServer

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

    if (!response) {
        self.rideRequestResponse = response = ((AppDelegate *)[UIApplication sharedApplication].delegate).fakeRideRequestResponse;
    }
    
    self.isReadyToGoToMeetCrew = NO;
    
    id nsNullObj = (id)[NSNull null];
    
    if ( !self.crew )
    { //this is the immediate ride request response
        NSLog(@"process immediate ride req response, create crew array");
        self.crew = [NSMutableArray arrayWithCapacity: 1];
        self.userID = [response objectForKey:kUserPublicId];
        self.requestID = [response objectForKey:kPublicId];

        if (self.requestID)
        {
            //remember request id, incase app gets killed and is relaunced due to a match
            [[NSUserDefaults standardUserDefaults] setObject:self.requestID forKey:kRequestPublicId];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else
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
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@", kStowawayServerApiUrl_users, self.userID, ride_id];
        
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
        
        [self cancelTimerExpiryNotificationSchedule];
    }
}

#pragma mark - process RIDE

-(void)processRideObject:(NSDictionary *)response
{
    NSLog(@"processRideObject......................................");

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
                                        @{kFbId: [request objectForKey:kFbId],
                                        kUserPublicId: [request objectForKey:kUserPublicId],
                                        kRequestedAt: [request objectForKey:kRequestedAt],
                                        kIsCaptain: [NSNumber numberWithBool:isCaptain]}];
   
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
        [self cancelTimerExpiryNotificationSchedule];
        
        // get suggested locn
        self.suggestedLocations = @{kSuggestedDropOffAddr: [response objectForKey:kSuggestedDropOffAddr],
                                    kSuggestedDropOffLong: [response objectForKey:kSuggestedDropOffLong],
                                    kSuggestedDropOffLat: [response objectForKey:kSuggestedDropOffLat],
                                    kSuggestedPickUpAddr: [response objectForKey:kSuggestedPickUpAddr],
                                    kSuggestedPickUpLong: [response objectForKey:kSuggestedPickUpLong],
                                    kSuggestedPickUpLat: [response objectForKey:kSuggestedPickUpLat]};
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
            
            [self.serverPollingTimer invalidate];
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
    NSArray *faces =      @[@"1.png", @"2.png",@"3.png", @"4.png",
                            @"5.png", @"6.png",@"7.png", @"8.png",
                            @"9.png", @"10.png",@"11.png", @"12.png",
                            @"13.png", @"14.png",@"15.png", @"16.png"];
   
    NSUInteger facesCount = faces.count;
    
    //non repeating random numbers
    NSUInteger shuffledNumbers[facesCount];
    for (NSUInteger i = 0 ; i < facesCount; i++)
        shuffledNumbers[i] = i;
  
    uint32_t randBoundary = (uint32_t)facesCount;
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
            
            for (int i = 0; i < facesCount; i++)
                [self.animationImages1 addObject:[UIImage imageNamed:[faces objectAtIndex:shuffledNumbers[i]]]];

            break;
       
        case 2:
            if ( self.animationImages2 )
                return;
            
            self.animationImages2 = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < facesCount; i++)
                [self.animationImages2 addObject:[UIImage imageNamed:[faces objectAtIndex:shuffledNumbers[i]]]];

            break;
        
        case 3:
            if ( self.animationImages3 )
                return;
            
            self.animationImages3 = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < facesCount; i++)
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
    
    NSTimeInterval secondsToExpire = kCountdownTimerMaxSeconds - (rideRequestedAt - minRideRequestedAt);
    
    self.cdt.countDownEndDate = [NSDate dateWithTimeIntervalSinceNow:secondsToExpire];;
    
    NSLog(@"reCalculateCDTimer:secondsToExpire %f, expiry date %@ ***", secondsToExpire, self.cdt.countDownEndDate);
}

-(void) armUpCountdownTimer
{
    NSLog(@"armUpCountdownTimer");
   
    self.cdt = [[CountdownTimer alloc] init];
    
    self.cdt.cdTimerDelegate = self;
    
    [self.cdt initializeWithSecondsRemaining: kCountdownTimerMaxSeconds
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
        NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@/finalize", kStowawayServerApiUrl_users, self.userID, self.rideID];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"PUT"];
        
        [self.getRideResultActivityIndicator startAnimating];
        
        return;
    }
    
    //if there are no matches, ask user if they want to wait more
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Matches Yet !"
                                                    message:@"Do you want to wait a bit more ?"
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
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

-(void)cancelRide
{
    //DELETE ride request
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", kStowawayServerApiUrl_users, self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];    //don't need the callback, so no delegate
    
    //cancel local notif
    [self cancelTimerExpiryNotificationSchedule];
    
    //cancel server polling- going back to requests
    [self.serverPollingTimer invalidate];
    
    //go back to enter drop off pick up view
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

-(void)sendCoupon:(NSString *)couponCode
{
    //cancel local notif
    [self cancelTimerExpiryNotificationSchedule];

    //send couponed request
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", kStowawayServerApiUrl_users, self.userID, self.requestID];
    
    NSString *couponRequest = [NSString stringWithFormat:@"{\"%@\": \"%@\"}",
                                                     kCouponCodeKey, couponCode];
    

    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];

    sscommunicator.sscDelegate = self;

    [sscommunicator sendServerRequest:couponRequest ForURL:url usingHTTPMethod:@"PUT"];    //don't need the callback, so no delegate
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

    NSURL *firstNameURL     = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/profile", fbUID]];
    NSData *firstNameData = [NSData dataWithContentsOfURL:firstNameURL];
    NSDictionary* jsonDict = [NSJSONSerialization
                          JSONObjectWithData:firstNameData
                          options:kNilOptions
                          error:&error];
    NSString * fbFullName = nil;
   // NSLog(@"jsonDict %@", jsonDict);
    
    if (jsonDict && !error)
        fbFullName = [[[jsonDict objectForKey:@"data"]objectAtIndex:0] objectForKey:@"name"];

    NSString * fbName = [[fbFullName componentsSeparatedByString: @" "] objectAtIndex:0];

    switch (crewPostion)
    {
        case 1:
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                NSLog(@"set crew#%lu's image+name %@", (unsigned long)crewPostion, fbName);

                [self stopAnimatingImage:self.imageView1];
                
                self.imageView1.image   = profilePic;
                self.imageView1.layer.cornerRadius = self.imageView1.frame.size.height /2;
                self.imageView1.layer.masksToBounds = YES;
                self.imageView1.layer.borderWidth = 1;
                self.imageView1.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                self.nameLabel1.text    = fbName;
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
                
                self.nameLabel2.text    = fbName;
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
                
                self.nameLabel3.text    = fbName;
            });
        }
            break;
            
        default:
            break;
    }
    
    NSMutableDictionary * mutableDict = [NSMutableDictionary dictionaryWithDictionary:[self.crew objectAtIndex:crewPostion]];
    
    if (profilePic)
        [mutableDict setObject:profilePic forKey:kCrewFbImage];
    
    [mutableDict setObject:fbName forKey:kCrewFbName];
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
            [self cancelRide];
    }
    
    if ([theAlert.title isEqualToString:@"No Matches Yet !"])
    {
        if ([[theAlert buttonTitleAtIndex:buttonIndex] isEqualToString:@"No"])
            [self sendCoupon:kCouponCodeLoneRider];
        else
            [self armUpCountdownTimer]; //re-start the 5mins timer
    }

}

@end
