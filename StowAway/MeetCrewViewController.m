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
#import "PTPusher.h"
#import "StowawayServerCommunicator.h"

@interface MeetCrewViewController ()

@property (weak, nonatomic) IBOutlet UIButton *requestUberButton;
@property (weak, nonatomic) IBOutlet UILabel *countDownTimer;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel1;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel2;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel3;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation MeetCrewViewController

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
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@/requests/%@", self.userID, self.rideID];
    
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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
