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
#import "PTPusherChannel.h"
#import "PTPusher.h"
#import "PTPusherEvent.h"
#import "StowawayServerCommunicator.h"
#import "Reachability.h"
#import "PTPusherErrors.h"
#import "PTPusherConnection.h"


@interface MeetCrewViewController ()
<PTPusherDelegate, StowawayServerCommunicatorDelegate, CLLocationManagerDelegate, MKMapViewDelegate>

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



@property (strong, nonatomic) PTPusher * pusher;

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

#pragma mark Pusher

- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel withRequest:(NSMutableURLRequest *)request
{
    [request setValue:@"some-authentication-token" forHTTPHeaderField:@"X-MyCustom-AuthTokenHeader"];
}

- (void)handleCrewLocationUpdate:(PTPusherEvent *)event
{
    NSDictionary * locationUpdate = event.data;
    
    NSString * userID = [locationUpdate objectForKey:kUserPublicId];
    
    //if one of the crew member id, match this one, update it
}

-(void)sendDataToPusher:(CLLocationCoordinate2D )locationCoordinates
{
    PTPusherConnection * connection = self.pusher.connection;
    
    NSDictionary * locationUpdate = @{@"lat": [NSNumber numberWithDouble:locationCoordinates.latitude],
                                      @"long": [NSNumber numberWithDouble:locationCoordinates.longitude],
                                      kUserPublicId: self.userID};
    
    [connection send:locationUpdate];
}

-(void)startPusherUpdates
{
    //create pusher
    self.pusher = [PTPusher pusherWithKey:kPusherApiKey delegate:self encrypted:YES];
    
//TODO: authorise for private channel
    //self.client.authorizationURL = [NSURL URLWithString:@"http://api.getstowaway.com/api/v1/authorize"];

    [self.pusher connect];
    
    //subscribe to location channel created by server
    PTPusherChannel *channel = [self.pusher subscribeToChannelNamed:self.locationChannel];

    [channel bindToEventNamed:kPusherCrewLocationEvent target:self action:@selector(handleCrewLocationUpdate:)];

}

-(void)stopPusherUpdates
{
    PTPusherChannel *channel = [self.pusher channelNamed:self.locationChannel];
    [channel unsubscribe];
    
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection failedWithError:(NSError *)error
{
    [self handleDisconnectionWithError:error];
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error willAttemptReconnect:(BOOL)willAttemptReconnect
{
    if (!willAttemptReconnect) {
        [self handleDisconnectionWithError:error];
    }
}

- (void)handleDisconnectionWithError:(NSError *)error
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    
    if (error && [error.domain isEqualToString:PTPusherErrorDomain]) {
        NSLog(@"FATAL PUSHER ERROR, COULD NOT CONNECT! %@", error);
    }
    else {
        if ([reachability isReachable]) {
            // we do have reachability so let's wait for a set delay before trying again
            [self.pusher performSelector:@selector(connect) withObject:nil afterDelay:5];
        }
        else {
            // we need to wait for reachability to change
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(_reachabilityChanged:)
                                                         name:kReachabilityChangedNotification
                                                       object:reachability];
            
            [reachability startNotifier];
        }
    }
}

- (void)_reachabilityChanged:(NSNotification *)note
{
    Reachability *reachability = [note object];
    if ([reachability isReachable]) {
        // we're reachable, we can try and reconnect, otherwise keep waiting
        [self.pusher connect];
        
        // stop watching for reachability changes
        [reachability stopNotifier];
        
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:kReachabilityChangedNotification
         object:reachability];
    }
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
