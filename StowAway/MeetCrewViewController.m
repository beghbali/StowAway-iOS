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


@interface MeetCrewViewController () <StowawayServerCommunicatorDelegate, CountdownTimerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *requestUberButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

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

@end

@implementation MeetCrewViewController



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //remember that ride has been finalized, to be used if app gets killed and relaunched
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:kIsRideFinalized];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"MeetCrewViewController viewDidLoad: *** crew %@, \n suggLoc %@, locChannel %@ ****", self.crew,
                                                                self.suggestedLocations, self.locationChannel);
    
    self.nameLabel1.text = self.nameLabel2.text = self.nameLabel3.text = nil;
    self.imageView1.image = self.imageView2.image = self.imageView3.image = nil;
    
    //update the crew names and images and role
    [self updateCrewInfoInView];
    
    self.meetCrewMapViewManager = [[MeetCrewMapViewManager alloc]init];
    [self.meetCrewMapViewManager initializeCrew: self.crew];
    [self.meetCrewMapViewManager startUpdatingMapView:self.mapView withSuggestedLocations:self.suggestedLocations andPusherChannel:self.locationChannel];
    
    //    //outlets are loaded, now arm the timer, this is only set once
    [self armUpCountdownTimer];

}


-(void)updateCrewInfoInView
{
    for (int i = 0; i < self.crew.count; i++)
    {
        NSDictionary * crewMember = [self.crew objectAtIndex:i];

        if (i == 0 )
        {
            if ( [[crewMember objectForKey:kIsCaptain] boolValue])
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
            
            continue;
        }
        switch (i)
        {
            case 1:
                self.nameLabel1.text = [crewMember objectForKey:kCrewFbName];
                self.imageView1.image = [crewMember objectForKey:kCrewFbImage];

                break;
            case 2:
                self.nameLabel2.text = [crewMember objectForKey:kCrewFbName];
                self.imageView2.image = [crewMember objectForKey:kCrewFbImage];
                
                break;
            case 3:
                self.nameLabel3.text = [crewMember objectForKey:kCrewFbName];
                self.imageView3.image = [crewMember objectForKey:kCrewFbImage];
                
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
    //DELETE ride request
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/requests/%@", self.userID, self.requestID];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = nil; //don't need to process the response
    [sscommunicator sendServerRequest:nil ForURL:url usingHTTPMethod:@"DELETE"];
    
    //go back to enter drop off pick up view
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

#pragma mark stowawayServer

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
    //process the result to update the crew
}



@end
