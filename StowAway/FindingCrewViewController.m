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

//dictionary contains user_id, fb_id, picture, name, iscaptain
@property (strong, nonatomic) NSMutableArray * /*of NSDictionary*/ crew; //index 0 being self and upto 3

//my ID's - used for finalize ride and delete request
@property (strong, nonatomic) NSString *rideID;
@property (strong, nonatomic) NSString *userID;
@property (strong, nonatomic) NSString *requestID;

@property (strong, nonatomic) NSDictionary *suggestedLocations;
@property (strong, nonatomic) NSString * locationChannel;

@end

@implementation FindingCrewViewController


-(void) viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"viewdidload");

    //process ride request reply from server -- also sets cd timer value
    [self processRideRequestResponse:self.rideRequestResponse];

    [self setupAnimation];
}


-(void)viewDidAppear:(BOOL)animated
{
    
    [super viewDidAppear:animated];
    NSLog(@"view did appear");

    //outlets are loaded, now arm the timer, this is only set once
    [self armUpCountdownTimer];

    //update the view - pics, names
    [self updateCrewView];
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
    NSLog(@"processRideRequestResponse:: %@", response);
    
    id nsNullObj = (id)[NSNull null];
    NSUInteger requestedTime = 0;
    
    if ( !self.crew )
    { //this is the immediate ride request response
        NSLog(@"process immediate ride req response");
        self.crew = [NSMutableArray arrayWithCapacity: 1];
        self.userID = [response objectForKey:kUserPublicId];
        self.requestID = [response objectForKey:kPublicId];
        //parse the response to fill in SELF request_id, user_id
        NSDictionary * dict = @{kRequestPublicId: self.requestID,
                                kUserPublicId: self.userID};
        [self.crew insertObject:dict atIndex:0];
        
        requestedTime = [[response objectForKey:kRequestedAt] integerValue]; //needed for calculating the countdown timer value
    }
    
    NSString * ride_id = [response objectForKey:kRidePublicId];
    self.rideID = ride_id;
    NSLog(@"ride id %@", ride_id);
    
    if ( ride_id && (ride_id != nsNullObj) )
    { // there is a match - get ride result
        
        NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/rides/%@", self.userID, ride_id];
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
        
        [self.getRideResultActivityIndicator startAnimating];
    }
    else
    { // there is no match -  update the crew list
        // this is possible when there was just one match, and that person canceled the ride
        while ( self.crew.count > 1 )
            [self.crew removeLastObject];
        
        [self updateCrewView];
    }
}


-(void)processRideResult:(NSDictionary *)response
{
    NSLog(@"processRideResult:: %@", response);

    NSMutableArray * dontRemoveCrewIndexList = [NSMutableArray arrayWithCapacity:2];;
    
    NSArray * requests = [response objectForKey:@"requests"];
    
    int countRequests = requests.count;
    int countCrew = self.crew.count;
    
    //ADD NEW MEMBERS
    for ( int i = 0; i < countRequests; i++)
    {
        BOOL alreadyExistsInCrew = NO;
        NSDictionary * request = [requests objectAtIndex:i];
        
        for (int j = 0; j < countCrew; j++)
        {
            NSDictionary * crewMember = [self.crew objectAtIndex:j];
        
            if ( [[crewMember objectForKey:kUserPublicId] isEqualToString:[request objectForKey:kUserPublicId]] )
            {
                [dontRemoveCrewIndexList addObject:[crewMember objectForKey:kUserPublicId]];
                alreadyExistsInCrew = YES;
                break;  // already exists
            }
        }
        
        if (alreadyExistsInCrew)
            continue;
            
        //new memmber, add this to crew
        BOOL isCaptain = [[request objectForKey:kDesignation] isEqualToString:kDesignationCaptain];
        NSDictionary * dict = @{kFbId: [request objectForKey:kFbId],
                                kUserPublicId: [request objectForKey:kUserPublicId],
                                kRequestedAt: [request objectForKey:kRequestedAt],
                                kIsCaptain: [NSNumber numberWithBool:isCaptain]};
   
        [self.crew addObject:dict];
    }
    NSLog(@"after add - %@", self.crew);

    //REMOVE STALE MEMBERS
    for (int j = 0; j < self.crew.count; j++)
    {
        BOOL removeIt = YES;
        NSDictionary * crewMember = [self.crew objectAtIndex:j];
        
        for (int i = 0; i < dontRemoveCrewIndexList.count; i++)
        {
            if ( [[crewMember objectForKey:kUserPublicId] isEqualToString:[dontRemoveCrewIndexList objectAtIndex:i]] )
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
    NSLog(@"after remove - %@", self.crew);
    
    //save loc channel, suggested locn, if the ride is fulfilled
    if ([[response objectForKey:kStatus] isEqualToString:KStatusFulfilled])
    {
        // get suggested locn
        self.suggestedLocations = @{kSuggestedDropOffAddr: [response objectForKey:kSuggestedDropOffAddr],
                                    kSuggestedDropOffLong: [response objectForKey:kSuggestedDropOffLong],
                                    kSuggestedDropOffLat: [response objectForKey:kSuggestedDropOffLat],
                                    kSuggestedPickUpAddr: [response objectForKey:kSuggestedPickUpAddr],
                                    kSuggestedPickUpLong: [response objectForKey:kSuggestedPickUpLong],
                                    kSuggestedPickUpLat: [response objectForKey:kSuggestedPickUpLat]};
        //get loc channel
        self.locationChannel = [response objectForKey:kLocationChannel];
        
        //figure out who is the captain
        
        //go to "meet the crew" view
        [self performSegueWithIdentifier: @"toMeetCrew" sender: self];
    } else
    {
        //update the view with updated crew and new cd time
        [self updateCrewView];
    }
}

#pragma mark prepare segue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ( [segue.identifier isEqualToString:@"toMeetCrew"] )
    {
 /*       if ([segue.destinationViewController class] == [FindingCrewViewController class])
        {
            FindingCrewViewController * findingCrewVC = segue.destinationViewController;
            findingCrewVC.rideRequestResponse = self.rideRequestResponse;
        }
  */
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
    self.cdt = [[CountdownTimer alloc] init];
    self.cdt.cdTimerDelegate = self;
    [self.cdt initializeWithSecondsRemaining:kCountdownTimerMaxSeconds ForLabel:self.countDownTimer];
}

- (void)countdownTimerExpired
{
    NSLog(@"%s", __func__);
    [self stopAnimatingImage:self.imageView1];
    [self stopAnimatingImage:self.imageView2];
    [self stopAnimatingImage:self.imageView3];

    [self rideFindTimeExpired];
}

-(void)rideFindTimeExpired
{
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
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/requests/%@", self.userID, self.rideID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];
    
    //go back to enter drop off pick up view
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}


#pragma mark update view

-(void)updateCrewView
{ //go through the crew array, set fb pic, name, stop/start animation as required, and adjust CDTimer
    
    //set the cd timer
    [self reCalculateCDTimer];
    
    for (NSUInteger i = 1; i < self.crew.count; i++)
        [self setCrewImageAndName:i withFbUID:[[self.crew objectAtIndex:i] objectForKey:kFbId]];
    
}

-(void)reCalculateCDTimer
{
    NSInteger rideRequestedAt = [[[self.crew objectAtIndex:0] objectForKey:kRequestedAt] integerValue];
    NSInteger minRideRequestedAt = rideRequestedAt;
    
    for (int i = 1; i < self.crew.count; i++)
    {
        NSInteger iRideRequestedAt = [[[self.crew objectAtIndex:i] objectForKey:kRequestedAt] integerValue];
        //compare self with the other crew members requested time, we want the minimum req time
        if ( iRideRequestedAt < minRideRequestedAt )
            minRideRequestedAt = iRideRequestedAt;
    }

    [self.cdt setSecondsRemaining:(kCountdownTimerMaxSeconds - (rideRequestedAt - minRideRequestedAt))];
}

// run this function on a background thread
-(void)setCrewImageAndName:(NSUInteger)crewPostion withFbUID:(NSString *)fbUID
{
    NSURL *profilePicURL    = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large", fbUID]];
    NSURL *firstNameURL     = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/profile", fbUID]];
   
    NSData *profilePicData = [NSData dataWithContentsOfURL:profilePicURL];
    UIImage *profilePic = [[UIImage alloc] initWithData:profilePicData] ;

    NSData *firstNameData = [NSData dataWithContentsOfURL:firstNameURL];
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:firstNameData
                          
                          options:kNilOptions
                          error:&error];
    
    NSString * fbName = [[[json objectForKey:@"data"]objectAtIndex:0] objectForKey:@"name"];

    switch (crewPostion)
    {
        case 1:

            [self stopAnimatingImage:self.imageView1];
            self.imageView1.image   = profilePic;
            self.nameLabel1.text    = fbName;

            break;
            
        case 2:
            
            [self stopAnimatingImage:self.imageView2];
            self.imageView2.image   = profilePic;
            self.nameLabel2.text    = fbName;
            
            break;
            
        case 3:
            
            [self stopAnimatingImage:self.imageView1];
            self.imageView3.image   = profilePic;
            self.nameLabel3.text    = fbName;
            
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
