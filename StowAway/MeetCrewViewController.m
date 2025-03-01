//
//  MeetCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "MeetCrewViewController.h"
#import <MapKit/MapKit.h>
#import "StowawayServerCommunicator.h"
#import "MeetCrewMapViewManager.h"
#import "CountdownTimer.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MeetCrewViewController () <StowawayServerCommunicatorDelegate, CountdownTimerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *requestUberButton;
@property (weak, nonatomic) IBOutlet UIButton *finalActionButton;

@property (strong, nonatomic) CountdownTimer * cdt;

@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel1;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel2;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel3;
@property (weak, nonatomic) IBOutlet UILabel *additionalRideInfoLabel;

@property (weak, nonatomic) IBOutlet UILabel *designationLabel;
@property (weak, nonatomic) IBOutlet UILabel *instructionsLabel;
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationBarItem;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) MeetCrewMapViewManager * meetCrewMapViewManager;

@property (strong, nonatomic) UIImage * checkMarkBadgeImage;
@property (strong, nonatomic) UIImage * crossMarkBadgeImage;

@property BOOL isLoneRider;
@property BOOL isAlreadyInitiated;

@end

@implementation MeetCrewViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];
    
    [self subscribeToNotifications];
    
#ifdef DEBUG
    NSLog(@"MeetCrewViewController viewDidLoad: *** crew %@, \n suggLoc %@, locChannel %@ ****",
          self.crew, self.suggestedLocations, self.locationChannel);
#endif
    self.nameLabel1.text = self.nameLabel2.text = self.nameLabel3.text = nil;
    self.imageView1.image = self.imageView2.image = self.imageView3.image = nil;
    
    //show the crew on map
    self.meetCrewMapViewManager = [[MeetCrewMapViewManager alloc]init];
    
    [self.meetCrewMapViewManager initializeCrew: self.crew forRideID: self.rideID];
    
    [self.meetCrewMapViewManager startUpdatingMapView:self.mapView
                               withSuggestedLocations:self.suggestedLocations
                                     andPusherChannel:self.locationChannel];
    
    //update the crew names and images and role
    [self updateCrewInfoInView];
    
    //get the ride object incase the app is relaunched, we need to get the ride-object
    [self getRideObject];
    
}


#pragma mark - signals subscription

-(void)subscribeToNotifications
{
#ifdef DEBUG
    NSLog(@"%s:", __func__);
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mcReceivedRideUpdateFromServer:)
                                                 name:@"rideUpdateFromServer"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedRideCreditsUpdate:)
                                                 name:@"updateRideCredits"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appReturnsActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

-(void)unSubscribeToNotifications
{
#ifdef DEBUG
    NSLog(@"%s:", __func__);
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"rideUpdateFromServer"
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"updateRideCredits"
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

#pragma mark - process signals

-(void)mcReceivedRideUpdateFromServer:(NSNotification *)notification
{
#ifdef DEBUG
    NSLog(@"%s: %@", __func__, notification);
#endif
    self.rideID = [notification.userInfo objectForKey:kPublicId];
    if ( !self.rideID || (self.rideID == (id)[NSNull null]) )
    {
        NSLog(@"ride got CANCELED go back to enter drop off pick up view");

        [self doneWithTheRide];
        
        return;
    }
    //get the ride object and figure out who needs to be removed from the view, who needs to be checked-in
    [self getRideObject];
}

- (void)appReturnsActive:(NSNotification *)notification
{
#ifdef DEBUG
    NSLog(@"%s............is lone rider %d\n", __func__, self.isLoneRider);
#endif
    //get update on the riders
    if (!self.isLoneRider)
        [self getRideObject];
}

-(void)getRideObject
{
#ifdef DEBUG
    NSLog(@"ride update - get ride object from server..........");
#endif
    NSString *url = [NSString stringWithFormat:@"%@%@/rides/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.rideID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
}

#pragma mark - ride object processing

-(void)processRideObject:(NSDictionary *)response
{
#ifdef DEBUG
    NSLog(@"%s: crew before processing: %@", __func__, self.crew);
#endif
    NSArray * requests = [response objectForKey:@"requests"];
    
    NSUInteger countRequests = requests.count;
    NSUInteger countCrew = self.crew.count;
    
#ifdef DEBUG
    NSLog(@"MC:: crew# %lu, rideResult# %lu", (unsigned long)countCrew, (unsigned long)countRequests);
#endif
    
    //UPDATE CREW
    for (int j = 0; j < self.crew.count; j++)
    {
        BOOL removeIt = YES;
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:j];
        
        for (int i = 0; i < countRequests; i++)
        {
            NSDictionary * request = [requests objectAtIndex:i];

            if ( [[crewMember objectForKey:kUserPublicId] compare:[request objectForKey:kUserPublicId]] == NSOrderedSame )
            {
                removeIt = NO;
                //update status
#ifdef DEBUG
                NSLog(@"%s: update status for crew#%d --- STATUS %@",__func__, j, [request objectForKey:kStatus]);
#endif
                if ([[request objectForKey:kStatus] isEqualToString:kStatusCheckedin])
                    [crewMember setObject:[NSNumber numberWithBool:YES] forKey: kIsCheckedIn];
                
                if ([[request objectForKey:kStatus] isEqualToString:kStatusMissed])
                    [crewMember setObject:[NSNumber numberWithBool:NO] forKey: kIsCheckedIn];
  
                if ([[request objectForKey:kStatus] isEqualToString:kStatusInitiated])
                    [crewMember setObject:[NSNumber numberWithBool:YES] forKey: kStatusInitiated];
                else
                    [crewMember setObject:[NSNumber numberWithBool:NO] forKey: kStatusInitiated];

                break;
            }
        }
        
        if (!removeIt)
            continue;
        
        //remove the crew member
#ifdef DEBUG
        NSLog(@"%s: remove the crew member  kUserPublicId = %@",__func__, [crewMember objectForKey:kUserPublicId]);
#endif
        [self.crew removeObjectAtIndex:j];
        //update the map view
        [self.meetCrewMapViewManager initializeCrew: self.crew forRideID: self.rideID];

        j--;
    }
    
#ifdef DEBUG
    NSLog(@"** MC crew after processing ** - %@", self.crew);
#endif
    //UPDATE VIEW with updated crew
    [self updateCrewInfoInView];
}

#pragma mark - crew view 

-(void)updateCrewInfoInView
{
#ifdef DEBUG
    NSLog(@"%s......crew count %lu", __func__, (unsigned long)self.crew.count);
#endif
    if (self.crew.count == 0)
    {
        [self doneWithTheRide];
        return;
    }
    
    NSString *  prevDesg        = nil;
    UIImage *   badgedImage     = nil;
    NSString *  couponCode      = nil;
    NSString *  displayName     = nil;
    BOOL        isCaptain       = NO;
    BOOL        isInitiated     = NO;
    
    for (int i = 0; i < self.crew.count; i++)
    {
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:i];
#ifdef DEBUG
        NSLog(@"%s: <%d> updateCrewInfoInView for crewMember %@", __func__, i, crewMember);
#endif
        prevDesg    = nil;
        badgedImage = nil;
        isCaptain   = [[crewMember objectForKey:kIsCaptain] boolValue];
        displayName = isCaptain? [NSString stringWithFormat:@"CAPT. %@",[crewMember objectForKey:kCrewFbName]]: [crewMember objectForKey:kCrewFbName];
        
        if (i == 0 )
        {
            //process myself
            
            //check coupon code -- lone rider
            couponCode = [crewMember objectForKey:kCouponCodeKey];
            if (couponCode == (NSString *)[NSNull null])
                couponCode = nil;
            
            self.isLoneRider = [couponCode isEqualToString:kCouponCodeLoneRider];
            
            prevDesg = self.designationLabel.text;
            
            //is ride initiated
#ifdef DEBUG
            NSLog(@"%s: ME::  isCaptain %d,  isLoneRider %d, isInitiated %d, isAlreadyInitiated %d", __func__,
                  isCaptain, self.isLoneRider, isInitiated, self.isAlreadyInitiated);
#endif
            isInitiated = [[crewMember objectForKey:kStatusInitiated] boolValue];
            if (isInitiated && !self.isAlreadyInitiated && !self.isLoneRider)
            {
#ifdef DEBUG
                NSLog(@"%s: ride got initiated, starting pusher & location updates now...", __func__);
#endif
                self.isAlreadyInitiated = YES;
                
                //start location updates
                [self.meetCrewMapViewManager startLocationUpdates];
                
                //start pusher updates
                [self.meetCrewMapViewManager startPusherUpdates];

                //schedule auto checkin
                NSTimeInterval secondsRemainingToDeparture = [self.rideDepartureDate timeIntervalSinceNow];
#ifdef DEBUG
                NSLog(@"%s: secondsRemainingToDeparture %f", __func__, secondsRemainingToDeparture);
#endif
                if (secondsRemainingToDeparture < 0)
                    secondsRemainingToDeparture = 5;
                [self armUpCountdownTimerFor:secondsRemainingToDeparture];

            }

#ifdef DEBUG
            NSLog(@"isInitiated %d",isInitiated);
#endif
            if ( isCaptain )
            {
                self.designationLabel.text  = self.isLoneRider? @"YOU'RE RIDING SOLO TODAY": @"YOU ARE THE CAPTAIN !";
                self.instructionsLabel.text = self.isLoneRider? @"Order Uber alone this time and get 50% in ride credit.":
                [NSString stringWithFormat:@"Crew will be at the pick up point at %@", self.rideTimeLabel];

                self.additionalRideInfoLabel.hidden = (isInitiated || self.isLoneRider)? YES: NO;
                self.requestUberButton.hidden = !self.additionalRideInfoLabel.hidden ;// (isInitiated || self.isLoneRider)? NO: YES;
                
                self.navigationBarItem.title  = self.isLoneRider? @"Lone Rider" : @"Meet Your Crew";
                
                //You'll be able order to  send notifications as we find other riders and finalize ride status by XX:XX pm.
                NSArray * components = [self.rideTimeLabel componentsSeparatedByString:@" "];
                NSString * ampm = [components objectAtIndex:1];
                NSArray * components1 = [[components objectAtIndex:0] componentsSeparatedByString:@":"];
                int hrs = [[components1 objectAtIndex:0] intValue];
                int mins = [[components1 objectAtIndex:1] intValue]-5;
                if (mins < 0)
                {
                    hrs --;
                    mins = 55;
                    if (hrs < 0) {
                        hrs = 11;
                        ampm = @"pm";
                    }
                }
                self.additionalRideInfoLabel.text = [NSString stringWithFormat:@"You will be able to order an UberX at %d:%02d %@", hrs, mins, ampm];

                if (self.isLoneRider)
                    [self.finalActionButton setTitle:@" No Thanks " forState:UIControlStateNormal];
            }
            else
            {
                self.designationLabel.text = @"YOU ARE A STOWAWAY !";
                self.instructionsLabel.text = [NSString stringWithFormat:@"Please be at the pick-up point by %@.\nDon't be late.", self.rideTimeLabel];
                self.requestUberButton.hidden = YES;
                self.navigationBarItem.title  = @"Meet Your Captain";
                self.additionalRideInfoLabel.text = @"Your captain will call the car.";
            }
            
            if ( ![prevDesg isEqualToString:self.designationLabel.text] )   //play sound based on my role
                [self playSound:isCaptain? @"you-are-captain":@"you-are-stowaway"];
            
            //check in status
            int keepRunningAutoCheckinProcess = [self getCheckedInStatus:crewMember];
#ifdef DEBUG
            NSLog(@"%s: keepRunningAutoCheckinProcess %d", __func__, keepRunningAutoCheckinProcess);
#endif
            switch (keepRunningAutoCheckinProcess)
            {
                case 1:
                    //checked in
                    self.navigationBarItem.title  = @"Bon Voyage !";
                    if (!self.isLoneRider)
                        self.instructionsLabel.text = @"Enjoy the ride,\nyou'll only be charged for your share of this ride.";
                    break;
                    
                case -1:
                    //missed the ride
                    self.navigationBarItem.title  = @"Missed Your Ship  :(";
                    if (!self.isLoneRider)
                        self.instructionsLabel.text = @"Argh... the crew left without you,\nyou won't be charged for this.";
                    break;
                    
                default:
                    break;
            }
            
            if (keepRunningAutoCheckinProcess != 0)
            {
                //if i am captain, then i need to wait for stowaways to determine their checkin status
                if (isCaptain)
                {
                    BOOL isWholeCrewCheckinStatusDetermined = YES;
#ifdef DEBUG
                    NSLog(@"%s: i'm a captain, checking crews checkin status", __func__);
#endif
                    for (int k = 0; k < self.crew.count; k++)
                    {
                        NSMutableDictionary * crewMember = [self.crew objectAtIndex:k];
                        int keepRunningAutoCheckinProcess = [self getCheckedInStatus:crewMember];
                        NSLog(@"crew#%d, keepRunningAutoCheckinProcess %d", k, keepRunningAutoCheckinProcess);
                        if (keepRunningAutoCheckinProcess==0)
                        {
                            isWholeCrewCheckinStatusDetermined = NO;
                            break;
                        }
                    }
                    if (!isWholeCrewCheckinStatusDetermined)
                        continue;
                }
                
#ifdef DEBUG
                NSLog(@"%s: checkin status determined, now stop auto-checkin mode...., is lone rider %d", __func__, self.isLoneRider);
#endif
                if ( !self.isLoneRider )
                    [self.finalActionButton setTitle:@"   DONE  " forState:UIControlStateNormal];
                
                [self.meetCrewMapViewManager stopAutoCheckinMode];
            }
            continue; //end of processing myself
        }
        
        //process others now
        switch (i)
        {
            case 1:
                self.nameLabel1.text = displayName;
                self.imageView1.image = [crewMember objectForKey:kCrewFbImage];
                self.imageView1.layer.cornerRadius = self.imageView1.frame.size.height /2;
                self.imageView1.layer.masksToBounds = YES;
                self.imageView1.layer.borderWidth = 1;
                self.imageView1.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView1.image = badgedImage;
                
                break;
                
            case 2:
                self.nameLabel2.text = displayName;
                self.imageView2.image = [crewMember objectForKey:kCrewFbImage];
                self.imageView2.layer.cornerRadius = self.imageView2.frame.size.height /2;
                self.imageView2.layer.masksToBounds = YES;
                self.imageView2.layer.borderWidth = 1;
                self.imageView2.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView2.image = badgedImage;
                
                break;
                
            case 3:
                self.nameLabel3.text = displayName;
                self.imageView3.image = [crewMember objectForKey:kCrewFbImage];
                self.imageView3.layer.cornerRadius = self.imageView3.frame.size.height /2;
                self.imageView3.layer.masksToBounds = YES;
                self.imageView3.layer.borderWidth = 1;
                self.imageView3.layer.borderColor = (__bridge CGColorRef)([UIColor colorWithRed:82/256.0 green:65/256.0 blue:49/256.0 alpha:1.0]);
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView3.image = badgedImage;
                
                break;
                
            default:
                break;
        }
    }
    
    
    //process empty crew spots
    for (NSUInteger i = self.crew.count; i < kMaxCrewCount; i++)
    {
#ifdef DEBUG
        NSLog(@"RESET image and name for crew #%lu ........isLoneRider %d", (unsigned long)i, self.isLoneRider);
#endif
        //reset the images to nil and also reset the name to nil....
        switch (i)
        {
            case 1:
                self.imageView1.image = self.isLoneRider? [UIImage imageNamed:@"50.png"]: nil;
                self.nameLabel1.text = nil;
                break;
                
            case 2:
                self.imageView2.image = self.isLoneRider? [UIImage imageNamed:@"percent.png"]: nil;
                self.nameLabel2.text = nil;
                break;
                
            case 3:
                self.imageView3.image = self.isLoneRider? [UIImage imageNamed:@"off.png"]: nil;
                self.nameLabel3.text = nil;
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - checkin image badging

-(UIImage *)drawImage:(UIImage*)profileImage withBadge:(UIImage *)badge
{
    UIGraphicsBeginImageContextWithOptions(profileImage.size, NO, 0.0f);
    
    [profileImage drawInRect:CGRectMake(0, 0, profileImage.size.width, profileImage.size.height)];
    
    [badge drawInRect:
     CGRectMake(profileImage.size.width*0.25, profileImage.size.height*0.25, profileImage.size.width*0.50, profileImage.size.height*0.50)];
   
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
   
    UIGraphicsEndImageContext();
    
    return resultImage;
}

//1 = checked in, 0 = unknown, -1 = missed
-(int)getCheckedInStatus:(NSDictionary *)crewMember
{
    int         status          = 0;
    NSNumber *  isCheckedInNum  = nil;
    
    if (!crewMember)
        return status;
    
    isCheckedInNum = [crewMember objectForKey:kIsCheckedIn];
    
    if (isCheckedInNum )
        status = [isCheckedInNum boolValue] ? 1: -1;
    
    return status;
}

-(UIImage *)getBadgedCheckedInImageForCrewMember:(NSDictionary *)crewMember
{
    int status = 0;
    UIImage * badgedImage = nil;
    UIImage * crewImage = nil;
    
    status = [self getCheckedInStatus:crewMember];
#ifdef DEBUG
    NSLog(@"updateCheckedInStatusForCrewMember %@, status %d", crewMember, status);
#endif
    if ( status == 0 )
        return badgedImage;

    crewImage = [crewMember objectForKey:kCrewFbImage];
    if (status == 1)
    {
#ifdef DEBUG
        NSLog(@"check this one in !!!");
#endif
        if ( !self.checkMarkBadgeImage )
            self.checkMarkBadgeImage = [UIImage imageNamed: @"check-mark-256.png"];
        
        badgedImage = [self drawImage:crewImage withBadge:self.checkMarkBadgeImage];
    } else
    {
#ifdef DEBUG
        NSLog(@"this one missed !!!");
#endif
        if ( !self.crossMarkBadgeImage )
            self.crossMarkBadgeImage = [UIImage imageNamed: @"cross-mark-256.png"];
        
        badgedImage = [self drawImage:crewImage withBadge:self.crossMarkBadgeImage];
    }
    
    return badgedImage;
}

#pragma mark - sounds
-(void) playSound:(NSString *)soundFile
{
    NSString *soundPath = [[NSBundle mainBundle] pathForResource:soundFile ofType:@"wav"];
    if (!soundPath) {
        NSLog(@"%s: can't find %@.wav", __func__, soundFile);
        return;
    }
    SystemSoundID soundID;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:soundPath], &soundID);
    AudioServicesPlaySystemSound (soundID);
}

-(void)animateDesignationLabel:(BOOL)isCaptain withEffect:(BOOL)isSpecial
{
    NSLog(@"\n--------- %s ---------- %d %d\n",__func__, isCaptain, isSpecial);
    NSString * designation = isCaptain ? @"You are the Captain !!" : @"You are a Stowaway !";
    
    if (!isSpecial) {
        self.designationLabel.text = designation;
        return;
    }
    
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:designation];
    
    [s addAttribute:NSBackgroundColorAttributeName
              value:isCaptain? [UIColor greenColor]:[UIColor yellowColor]
              range:NSMakeRange(0, s.length)];
    
    self.designationLabel.attributedText = s;
}

#pragma mark - countdown timer
-(void) armUpCountdownTimerFor:(NSUInteger)seconds
{
#ifdef DEBUG
    NSLog(@"%s: armUpCountdownTimer %lu", __func__, (unsigned long)seconds);
#endif
    self.cdt = [[CountdownTimer alloc] init];
    self.cdt.cdTimerDelegate = self;
    [self.cdt initializeWithSecondsRemaining:seconds ForLabel:nil];
}

- (void)countdownTimerExpired
{
#ifdef DEBUG
    NSLog(@"%s, now start auto checkin mode", __func__);
#endif
    [self.meetCrewMapViewManager startAutoCheckinMode];
}

#pragma mark - end of ride

- (void)doneWithTheRide
{
#ifdef DEBUG
    NSLog(@"%s: we are DONE here....go back to enter drop off pick up view", __func__);
#endif
    [self unSubscribeToNotifications];
    
    [self.meetCrewMapViewManager stopAutoCheckinMode];

    //erase it from memory, so its not used in app restoration
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRequestPublicId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
}

- (IBAction)finalActionButtonTapped:(UIButton *)sender
{
    if ([sender.titleLabel.text isEqualToString:@"Cancel Ride"])
    {
        //warn user that they are canceling a ride
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Your crew would be disappointed !"
                                                        message:@"Do you really want cancel this ride ?"
                                                       delegate:self
                                              cancelButtonTitle:@"Yes"
                                              otherButtonTitles:@"No", nil];
        [alert show];
        return;
    }
    
    //lone rider - no thanks == dont give the ride credits
    if ([sender.titleLabel.text isEqualToString:@" No Thanks "])
    {
        //warn user that they are canceling a ride
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Free ride credits !"
                                                        message:@"Do you really want to forgo 50% ride credit ?"
                                                       delegate:self
                                              cancelButtonTitle:@"Yes"
                                              otherButtonTitles:@"No", nil];
        [alert show];
        return;
    }

    //done button
    [self doneWithTheRide];

}

-(void)cancelRide
{
    [self.meetCrewMapViewManager stopAutoCheckinMode];
    
    //DELETE ride request
    NSString *url = [NSString stringWithFormat:@"%@%@/requests/%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = nil; //don't need to process the response
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];
    
    NSLog(@"go back to enter drop off pick up view");

    //erase it from memory, so its not used in app restoration and go back to home
    [self doneWithTheRide];
}

#pragma mark - alert delegates

-(void)alertView:(UIAlertView *)theAlert clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //TODO: change all the constant texts to constant keys in a string file, that can be used for localization as well
    if ([theAlert.title isEqualToString:@"Your crew would be disappointed !"] ||
        [theAlert.title isEqualToString:@"Free ride credits !"])
    {
        if ([[theAlert buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
            [self cancelRide];
    }
}

#pragma mark - launch uber

-(void)getUberXProductId
{
    double pickupLat, pickupLong;
    pickupLat   = [[self.suggestedLocations objectForKey:kSuggestedPickUpLat] doubleValue],
    pickupLong  = [[self.suggestedLocations objectForKey:kSuggestedPickUpLong] doubleValue];
    
    //curl -H 'Authorization: Token kUberApiServerToken' 'https://api.uber.com/v1/products?latitude=37.7759792&longitude=-122.41823'
    
    NSString *url = [NSString stringWithFormat:@"https://api.uber.com/v1/products?latitude=%f&longitude=%f",pickupLat, pickupLong];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:@"uber" ForURL:url usingHTTPMethod:@"GET"];
    
    
}

- (IBAction)requestUberButtonTapped:(UIButton *)sender
{
#ifdef DEBUG
    NSLog(@"%s: isLoneRider %d", __func__, self.isLoneRider);
#endif
    NSString *stringURL = @"uber://";
    NSURL *url = [NSURL URLWithString:stringURL];
    
    if ([[UIApplication sharedApplication] canOpenURL:url])
    {
        double pickupLat, pickupLong, dropOffLat, dropOffLong;
        dropOffLat  = [[self.suggestedLocations objectForKey:kSuggestedDropOffLat] doubleValue],
        dropOffLong = [[self.suggestedLocations objectForKey:kSuggestedDropOffLong] doubleValue];
        
        pickupLat   = [[self.suggestedLocations objectForKey:kSuggestedPickUpLat] doubleValue],
        pickupLong  = [[self.suggestedLocations objectForKey:kSuggestedPickUpLong] doubleValue];
        
        NSString *pickUpAddress     = pickUpPointAnnotationTitle;
        NSString *dropOffAddress    = dropOffPointAnnotationTitle;

        for(MKPointAnnotation* annotation in self.mapView.annotations)
        {
            if ([annotation.title isEqualToString:pickUpPointAnnotationTitle])
                pickUpAddress = annotation.subtitle;

            if ([annotation.title isEqualToString:dropOffPointAnnotationTitle])
                dropOffAddress = annotation.subtitle;
        }

        pickUpAddress = [pickUpAddress stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        dropOffAddress = [dropOffAddress stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        /*
         uber://?action=setPickup&pickup[latitude]=37.775818&pickup[longitude]=-122.418028&pickup[nickname]=UberHQ&pickup[formatted_address]=1455%20Market%20St%2C%20San%20Francisco%2C%20CA%2094103&dropoff[latitude]=37.802374&dropoff[longitude]=-122.405818&dropoff[nickname]=Coit%20Tower&dropoff[formatted_address]=1%20Telegraph%20Hill%20Blvd%2C%20San%20Francisco%2C%20CA%2094133&product_id=a1111c8c-c720-46c3-8534-2fcdd730040d
         */
        //TODO: don't hardcode uberx product id

        NSString *stringURL = [NSString stringWithFormat:@"uber://?action=setPickup&pickup[latitude]=%f&pickup[longitude]=%f&pickup[nickname]=%@&dropoff[latitude]=%f&dropoff[longitude]=%f&dropoff[nickname]=%@&product_id=a1111c8c-c720-46c3-8534-2fcdd730040d",
                               pickupLat, pickupLong,
                               pickUpAddress,
                               dropOffLat, dropOffLong,
                               dropOffAddress];
        NSURL *url = [NSURL URLWithString:stringURL];
        
        [[UIApplication sharedApplication] openURL:url];
    }
    else
    {
        NSLog(@"not installed, open app store");
        
        NSString *stringURL = @"https://appsto.re/us/4hz-v.i";
        NSURL *url = [NSURL URLWithString:stringURL];
        [[UIApplication sharedApplication] openURL:url];
    }
    
    self.requestUberButton.enabled = NO;
    
    if (self.isLoneRider)
    {
        [self.finalActionButton setTitle:@"   DONE  " forState:UIControlStateNormal];

        self.navigationBarItem.title  = @"Bon Voyage !";
    }
}


#pragma mark - stowawayServer

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
#ifdef DEBUG
    NSLog(@"%s:\n-- %@ -- %@ -- \n", __func__, data, sError);
#endif
    if (sError)
        return;
    
    NSArray * products = [data objectForKey:@"products"];
    if ( products && products.count )
    {
        //uber api response
        NSLog(@"%@", products);
        
        return;
    }
    
    //process the ride object to update the crew
    [self processRideObject:data];
}


#pragma mark - ride credits
- (IBAction)rideCreditsBarButtonTapped:(UIBarButtonItem *)sender
{
    NSString * msg = [NSString stringWithFormat:kRideCreditsAlertMsgFormat, self.rideCredits];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ride Credits"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    [alert show];
}

-(void)receivedRideCreditsUpdate:(NSNotification *)notification
{
#ifdef DEBUG
   NSLog(@"%s..............data %@", __func__, notification);
#endif
    self.rideCredits = [[notification.userInfo objectForKey:@"credits"] doubleValue];
    
#ifdef DEBUG
    NSLog(@"%s: ride creds %f, button %@", __func__, self.rideCredits,self.rideCreditsBarButton);
#endif
    self.rideCreditsBarButton.title = [NSString stringWithFormat:@"%@%0.2f",@"💰", self.rideCredits];
}

@end
