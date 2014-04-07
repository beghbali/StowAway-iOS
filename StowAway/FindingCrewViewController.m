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

@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages;

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

@end

@implementation FindingCrewViewController


-(void) viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"viewdidload - FC_vc %@, rideRequestResponse %@", self, self.rideRequestResponse);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteNotification:)
                                                 name:@"updateFindCrew"
                                               object:nil];
    
    [self.getRideResultActivityIndicator stopAnimating];

    [self setupAnimation];

    //process ride request reply from server -- also sets cd timer value
    [self processRideRequestResponse:self.rideRequestResponse];
}

-(void)didReceiveRemoteNotification:(NSNotification *)notification
{
    NSLog(@"%s:  %@", __func__, notification);
    [self processRideRequestResponse:notification.userInfo];
}

-(void)viewDidAppear:(BOOL)animated
{
    /*
    BOOL wasAppLaunchedDueToPush = [[[NSUserDefaults standardUserDefaults] objectForKey:@"wasAppLaunchedDueToPush"] boolValue];
    
    if (wasAppLaunchedDueToPush) {
        NSLog(@"%s: call view did load \n", __func__);
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"wasAppLaunchedDueToPush"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [self viewDidLoad];
    }
     */
    [super viewDidAppear:animated];
    
    self.viewDidLoadFinished = YES;

    NSLog(@"FindingCrewViewController::view did appear .............., isReadyToGoToMeetCrew %d", self.isReadyToGoToMeetCrew);

    //outlets are loaded, now arm the timer, this is only set once
    [self armUpCountdownTimer];

    //update the view - pics, names
    [self updateFindingCrewView]; //?? verify that this is not requied -- since on launch due to push, it will be processed
    
    //go to "meet the crew" view
    if ( self.isReadyToGoToMeetCrew && self.viewDidLoadFinished )
        [self performSegueWithIdentifier: @"toMeetCrew" sender: self];
}

#pragma mark stowawayServer

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    [self.getRideResultActivityIndicator stopAnimating];

    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    if ( !sError)
        [self processRideResult:data];
}

#pragma mark process response

-(void)processRideRequestResponse:(NSDictionary *)response
{
    NSLog(@"processRideRequestResponse........................, isReadyToGoToMeetCrew %d, viewDidLoadFinished %d, rideRequestResponse %@", self.isReadyToGoToMeetCrew, self.viewDidLoadFinished, self.rideRequestResponse);

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
        NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/rides/%@", self.userID, ride_id];
        
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

//either GET ride or FINALIZE ride result
-(void)processRideResult:(NSDictionary *)response
{
    NSLog(@"processRideResult......................................");

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
        
        //NSLog(@"processing <%d>request %@", i, request);
        
        for (int j = 0; j < countCrew; j++)
        {
            NSMutableDictionary * crewMember = [self.crew objectAtIndex:j];
        
           // NSLog(@"processing <%d>crewmember %@", j, crewMember);
            
            if ( [[crewMember objectForKey:kUserPublicId] compare:[request objectForKey:kUserPublicId]] == NSOrderedSame )
            {
                [dontRemoveCrewIndexList addObject:[crewMember objectForKey:kUserPublicId]];
                
                //update  - as this might be after a getting launched from push, also designation might have changed
                [crewMember setObject:[request objectForKey:kRequestedAt] forKey: kRequestedAt];
                
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
    //NSLog(@"after add - %@", self.crew);

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
    if ([[response objectForKey:kStatus] isEqualToString:KStatusFulfilled])
    {
        NSLog(@"ride has been FULFILLED (viewDidLoadFinished %d)...... we are ready to go to 'meet your crew'", self.viewDidLoadFinished);
        
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
        }
    }
}

#pragma mark animation
-(void) setupAnimation
{
    // Load images
    NSArray *imageNames = @[@"win_1.png", @"win_2.png", @"win_3.png", @"win_4.png",
                            @"win_5.png", @"win_6.png", @"win_7.png", @"win_8.png",
                            @"win_9.png", @"win_10.png", @"win_11.png", @"win_12.png",
                            @"win_13.png", @"win_14.png", @"win_15.png", @"win_16.png"];
    
    self.animationImages = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < imageNames.count; i++)
        [self.animationImages addObject:[UIImage imageNamed:[imageNames objectAtIndex:i]]];
}

-(void) startAnimatingImage:(UIImageView *)imageView
{    
    imageView.animationImages = self.animationImages;
    imageView.animationDuration = 1;    //secs between each image
    
    [imageView startAnimating];
}


-(void) stopAnimatingImage:(UIImageView *)imageView
{
    [imageView stopAnimating];
}

#pragma mark countdown timer

-(void) armUpCountdownTimer
{
    NSLog(@"armUpCountdownTimer");
   
    self.cdt = [[CountdownTimer alloc] init];
    
    self.cdt.cdTimerDelegate = self;
    
    [self.cdt initializeWithSecondsRemaining:kCountdownTimerMaxSeconds ForLabel:self.countDownTimer];

    [self setTimerExpiryNotification];
}

- (void)countdownTimerExpired
{
    NSLog(@"%s, crew <%lu> %@", __func__, (unsigned long)self.crew.count, self.crew);
  //  [self stopAnimatingImage:self.imageView1];
    //[self stopAnimatingImage:self.imageView2];
    //[self stopAnimatingImage:self.imageView3];

   //check if there is atleast one match
    if ( self.crew.count > 1)
    {
        // ask server for roles
        NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/rides/%@/finalize", self.userID, self.rideID];
        
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
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/requests/%@", self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];    //don't need the callback, so no delegate
    
    //go back to enter drop off pick up view
    [self dismissViewControllerAnimated:YES completion:^(void){}];
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
{ //go through the crew array, set fb pic, name, stop/start animation as required, and adjust CDTimer
    
  //  NSLog(@"update crew view <count %lu> %@", (unsigned long)self.crew.count, self.crew);
    NSLog(@"updateFindingCrewView ............");
    //set the cd timer
    [self reCalculateCDTimer];
    
    NSLog(@"updateFindingCrewView: CDT updated...");
    
    for (NSUInteger i = 1; i < self.crew.count; i++)
    {
        NSDictionary * crewMember = [self.crew objectAtIndex:i];

        if ([crewMember objectForKey:kCrewFbImage] && [crewMember objectForKey:kCrewFbName])
        {
            NSLog(@"we already have the fb image and name for crewMember %lu", (unsigned long)i);
            continue;
        }

        [self setCrewImageAndName:i withFbUID:[crewMember objectForKey:kFbId]];
/*
        if ( i == (kMaxCrewCount-1) ) {
            NSLog(@"for the last person, wait till we get the fb image and name");
            [self setCrewImageAndName:i withFbUID:[crewMember objectForKey:kFbId]];
        } else
        {
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
                //Background Thread
                [self setCrewImageAndName:i withFbUID:[crewMember objectForKey:kFbId]];
            });
        }
 */
    }
    
    for (NSUInteger i = self.crew.count; i < kMaxCrewCount; i++)
    {
        NSLog(@"RESET crew#%lu ........", (unsigned long)i);

        //reset the images to animate and also reset the name to finding....
        switch (i) {
            case 1:
                [self startAnimatingImage:self.imageView1];
                self.nameLabel1.text = @"finding...";
                break;
                
            case 2:
                [self startAnimatingImage:self.imageView2];
                self.nameLabel2.text = @"finding...";
                break;
                
            case 3:
                [self startAnimatingImage:self.imageView3];
                self.nameLabel3.text = @"finding...";
                break;

            default:
                break;
        }
    }
    
}

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

   // self.timerExpiryDate = [NSDate dateWithTimeIntervalSinceNow:secondsToExpire];
    
    self.cdt.countDownEndDate = [NSDate dateWithTimeIntervalSinceNow:secondsToExpire];;
    
    NSLog(@"reCalculateCDTimer:secondsToExpire %f, expiry date %@ ***", secondsToExpire, self.cdt.countDownEndDate);
}

// run this function on a background thread
-(void)setCrewImageAndName:(NSUInteger)crewPostion withFbUID:(NSString *)fbUID
{
    NSError* error;

    NSLog(@"find out crew#%lu's image+name with FBUID %@", (unsigned long)crewPostion, fbUID);
   
    NSURL *profilePicURL    = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large", fbUID]];
    NSData *profilePicData = [NSData dataWithContentsOfURL:profilePicURL];
    UIImage *profilePic = [[UIImage alloc] initWithData:profilePicData] ;

    NSURL *firstNameURL     = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/profile", fbUID]];
    NSData *firstNameData = [NSData dataWithContentsOfURL:firstNameURL];
    NSDictionary* jsonDict = [NSJSONSerialization
                          JSONObjectWithData:firstNameData
                          options:kNilOptions
                          error:&error];
    NSString * fbName = nil;
   // NSLog(@"jsonDict %@", jsonDict);
    
    if (jsonDict && !error)
        fbName = [[[jsonDict objectForKey:@"data"]objectAtIndex:0] objectForKey:@"name"];

    switch (crewPostion)
    {
        case 1:
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                NSLog(@"set crew#%lu's image+name %@", (unsigned long)crewPostion, fbName);

                [self stopAnimatingImage:self.imageView1];
                self.imageView1.image   = profilePic;
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
                self.nameLabel3.text    = fbName;
            });
        }
            break;
            
        default:
            break;
    }
    
    NSMutableDictionary * mutableDict = [NSMutableDictionary dictionaryWithDictionary:[self.crew objectAtIndex:crewPostion]];
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
            [self cancelRide];
        else
            [self armUpCountdownTimer]; //re-start the 5mins timer
    }

}

@end
