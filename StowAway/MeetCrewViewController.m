//
//  MeetCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "MeetCrewViewController.h"
#import <MapKit/MapKit.h>
#import "StowawayConstants.h"
#import "StowawayServerCommunicator.h"
#import "MeetCrewMapViewManager.h"
#import "CountdownTimer.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MeetCrewViewController () <StowawayServerCommunicatorDelegate, CountdownTimerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *requestUberButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;

@property (weak, nonatomic) IBOutlet UILabel *countDownTimer;
@property (strong, nonatomic) CountdownTimer * cdt;

@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel1;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel2;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel3;

@property (weak, nonatomic) IBOutlet UILabel *designationLabel;
@property (weak, nonatomic) IBOutlet UILabel *instructionsLabel;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) MeetCrewMapViewManager * meetCrewMapViewManager;

@property (strong, nonatomic) UIImage * checkMarkBadgeImage;
@property (strong, nonatomic) UIImage * crossMarkBadgeImage;

@end

@implementation MeetCrewViewController



- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //remember that ride has been finalized, to be used if app gets killed and relaunched
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:kIsRideFinalized];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteNotification:)
                                                 name:@"updateMeetCrew"
                                               object:nil];
    

    NSLog(@"MeetCrewViewController viewDidLoad: *** crew %@, \n suggLoc %@, locChannel %@ ****", self.crew,
                                                                self.suggestedLocations, self.locationChannel);
    
    self.nameLabel1.text = self.nameLabel2.text = self.nameLabel3.text = nil;
    self.imageView1.image = self.imageView2.image = self.imageView3.image = nil;
    
    //update the crew names and images and role
    [self updateCrewInfoInView];
    
    self.meetCrewMapViewManager = [[MeetCrewMapViewManager alloc]init];
    [self.meetCrewMapViewManager initializeCrew: self.crew forRideID: self.rideID];
    [self.meetCrewMapViewManager startUpdatingMapView:self.mapView withSuggestedLocations:self.suggestedLocations andPusherChannel:self.locationChannel];
    
    //    //outlets are loaded, now arm the timer, this is only set once
    [self armUpCountdownTimer];

}

-(void)didReceiveRemoteNotification:(NSNotification *)notification
{
    NSLog(@"%s: MC_vc  %@", __func__, notification);
    self.rideID = [notification.userInfo objectForKey:kPublicId];
    if ( !self.rideID || (self.rideID == (id)[NSNull null]) )
    {
        NSLog(@"go back to enter drop off pick up view");
        [self.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
        return;
    }
    //get the ride object and figure out who needs to be removed from the view, who needs to be checked-in
    [self getRideObject];
    //TODO: stowaway server communicator should handle this -- getRideObject
    
}

-(void)getRideObject
{
    NSLog(@"there is a ride update - get ride object from server..........");
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/rides/%@", self.userID, self.rideID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"GET"];
}


-(void)processRideObject:(NSDictionary *)response
{
    NSLog(@"MC: processRideObject......................................");
    
    NSLog(@"MC: crew before processing: %@", self.crew);
    
    NSArray * requests = [response objectForKey:@"requests"];
    
    NSUInteger countRequests = requests.count;
    NSUInteger countCrew = self.crew.count;
    
    NSLog(@"MC:: crew# %lu, rideResult# %lu", (unsigned long)countCrew, (unsigned long)countRequests);
    
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
                NSLog(@"%s: update status",__func__);
                if ([[response objectForKey:kStatus] isEqualToString:kStatusCheckedin])
                    [crewMember setObject:[NSNumber numberWithBool:YES] forKey: kIsCheckedIn];
                if ([[response objectForKey:kStatus] isEqualToString:kStatusMissed])
                    [crewMember setObject:[NSNumber numberWithBool:NO] forKey: kIsCheckedIn];
  
                break;
            }
        }
        
        if (!removeIt)
            continue;
        
        //remove the crew member
        NSLog(@"%s: remove the crew member  kUserPublicId = %@",__func__, [crewMember objectForKey:kUserPublicId]);
        [self.crew removeObjectAtIndex:j];
        j--;
    }
    
    NSLog(@"** MC crew after processing ** - %@", self.crew);
    
    //UPDATE VIEW with updated crew
    [self updateCrewInfoInView];
    
    
}

-(UIImage *)drawImage:(UIImage*)profileImage withBadge:(UIImage *)badge
{
    NSLog(@"profileImage.size.width %f, profileImage.size.height %f", profileImage.size.width, profileImage.size.height);
    NSLog(@"badge.size.width %f, badge.size.height %f", badge.size.width, badge.size.height);
    
    UIGraphicsBeginImageContextWithOptions(profileImage.size, NO, 0.0f);
    
    [profileImage drawInRect:CGRectMake(0, 0, profileImage.size.width, profileImage.size.height)];
    
    [badge drawInRect:
     CGRectMake(profileImage.size.width*0.25, profileImage.size.height*0.25, profileImage.size.width*0.50, profileImage.size.height*0.50)];
   
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
   
    UIGraphicsEndImageContext();
    
    return resultImage;
}

-(UIImage *)getBadgedCheckedInImageForCrewMember:(NSDictionary *)crewMember
{
    NSNumber * isCheckedInNum = nil;
    UIImage * badgedImage = nil;
    UIImage * crewImage = nil;
    
    if ( !crewMember )
        return badgedImage;
    
    NSLog(@"updateCheckedInStatusForCrewMember %@", crewMember);
    isCheckedInNum = [crewMember objectForKey:kIsCheckedIn];

    if (!isCheckedInNum )
        return badgedImage;
    
    crewImage = [crewMember objectForKey:kCrewFbImage];
    if ([isCheckedInNum boolValue])
    {
        NSLog(@"check this one in !!!");
        
        if ( !self.checkMarkBadgeImage )
            self.checkMarkBadgeImage = [UIImage imageNamed: @"check-mark-256.png"];
        
        badgedImage = [self drawImage:crewImage withBadge:self.checkMarkBadgeImage];
    } else
    {
        NSLog(@"this one missed !!!");
        
        if ( !self.crossMarkBadgeImage )
            self.crossMarkBadgeImage = [UIImage imageNamed: @"cross-mark-256.png"];
        
        badgedImage = [self drawImage:crewImage withBadge:self.crossMarkBadgeImage];
    }
    
    return badgedImage;
}

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

-(void)updateCrewInfoInView
{
    NSLog(@"%s......", __func__);
    
    NSString * prevDesg = nil;
    UIImage * badgedImage = nil;

    for (int i = 0; i < self.crew.count; i++)
    {
        NSMutableDictionary * crewMember = [self.crew objectAtIndex:i];
        NSLog(@"updateCrewInfoInView for crewMember %@", crewMember);
        
        prevDesg = nil;
        badgedImage = nil;

        if (i == 0 )
        {
            BOOL isCaptain = [[crewMember objectForKey:kIsCaptain] boolValue];
            prevDesg = self.designationLabel.text;

            if ( isCaptain )
            {
                self.designationLabel.text = @"You are the Captain !!";
                self.instructionsLabel.text = @"Please get to the pick up point and call Uberx";
                self.requestUberButton.hidden = NO;
            } else
            {
                self.designationLabel.text = @"You are a Stowaway !";
                self.instructionsLabel.text = @"Please get to the pick up point and you don't have to call Uberx";
                self.requestUberButton.hidden = YES;
            }
            
            if ( ![prevDesg isEqualToString:self.designationLabel.text] )   //do fancy only oncefr
            {
                //sound travels slower than light :)
                if ( ![prevDesg isEqualToString:self.designationLabel.text] )
                    [self playSound:isCaptain? @"you-are-captain":@"you-are-stowaway"];
                
                //visual effect
                [self animateDesignationLabel:isCaptain withEffect:YES];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self animateDesignationLabel:isCaptain withEffect:NO];
                });

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self animateDesignationLabel:isCaptain withEffect:YES];
                });
            }
            
            //if checked in, hide uber and cancel buttons and show done button
            if ([crewMember objectForKey:kIsCheckedIn])
            {
                self.doneButton.hidden = NO;
                self.requestUberButton.hidden = YES;
                self.cancelButton.hidden = YES;
            }
            continue;
        }
        
        switch (i)
        {
            case 1:
                self.nameLabel1.text = [crewMember objectForKey:kCrewFbName];
                self.imageView1.image = [crewMember objectForKey:kCrewFbImage];
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView1.image = badgedImage;
                
                break;
                
            case 2:
                self.nameLabel2.text = [crewMember objectForKey:kCrewFbName];
                self.imageView2.image = [crewMember objectForKey:kCrewFbImage];
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView2.image = badgedImage;
                
                break;
                
            case 3:
                self.nameLabel3.text = [crewMember objectForKey:kCrewFbName];
                self.imageView3.image = [crewMember objectForKey:kCrewFbImage];
                
                badgedImage = [self getBadgedCheckedInImageForCrewMember:crewMember];
                if (badgedImage)
                    self.imageView3.image = badgedImage;
                
                break;
                
            default:
                break;
        }
    }
    
    for (NSUInteger i = self.crew.count; i < kMaxCrewCount; i++)
    {
        NSLog(@"RESET image and name for crew #%lu ........", (unsigned long)i);
        
        //reset the images to nil and also reset the name to nil....
        switch (i) {
            case 1:
                self.imageView1.image = nil;
                self.nameLabel1.text = nil;
                break;
                
            case 2:
                self.imageView2.image = nil;
                self.nameLabel2.text = nil;
                break;
                
            case 3:
                self.imageView3.image = nil;
                self.nameLabel3.text = nil;
                break;
                
            default:
                break;
        }
    }
    

}

#pragma mark countdown timer
-(void) armUpCountdownTimer
{
    NSLog(@"armUpCountdownTimer");
    self.cdt = [[CountdownTimer alloc] init];
    self.cdt.cdTimerDelegate = self;
    [self.cdt initializeWithSecondsRemaining:kCountdownTimerMaxSeconds ForLabel:self.countDownTimer];
}

- (void)countdownTimerExpired
{
    NSLog(@"%s", __func__);
    [self.meetCrewMapViewManager startAutoCheckinMode];
}

#pragma mark cancel ride

- (IBAction)cancelRideButtonTapped:(UIButton *)sender
{
    //warn user
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Your crew would be disappointed !"
                                                    message:@"Do you really want cancel this ride ?"
                                                   delegate:self
                                          cancelButtonTitle:@"Yes"
                                          otherButtonTitles:@"No", nil];
    [alert show];
}

-(void)cancelRide
{
    [self.meetCrewMapViewManager stopAutoCheckinMode];
    
    //DELETE ride request
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/requests/%@", self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = nil; //don't need to process the response
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];
    
    NSLog(@"go back to enter drop off pick up view");
    [self.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
}

#pragma mark alert delegates

-(void)alertView:(UIAlertView *)theAlert clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"For alert %@, The %@ button was tapped.", theAlert.title, [theAlert buttonTitleAtIndex:buttonIndex]);
    
    //TODO: change all the constant texts to constant keys in a string file, that can be used for localization as well
    if ([theAlert.title isEqualToString:@"Your crew would be disappointed !"])
    {
        if ([[theAlert buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
            [self cancelRide];
    }
}

#pragma mark launch uber

- (IBAction)requestUberButtonTapped:(UIButton *)sender
{
    NSString *stringURL = @"uber://";
    NSURL *url = [NSURL URLWithString:stringURL];
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        NSLog(@"uber installed, launch");
        [[UIApplication sharedApplication] openURL:url];
    }
    else {
        NSLog(@"not installed, open app store");
        
        NSString *stringURL = @"https://appsto.re/us/4hz-v.i";
        NSURL *url = [NSURL URLWithString:stringURL];
        [[UIApplication sharedApplication] openURL:url];
    }
    
    self.requestUberButton.titleLabel.textColor = [UIColor grayColor];
}

- (IBAction)doneButtonTapped:(UIButton *)sender
{
    NSLog(@"we are DONE here....go back to enter drop off pick up view");
    [self.presentingViewController.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
}

#pragma mark stowawayServer

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
    //process the ride object to update the crew
    [self processRideObject:data];
}



@end
