//
//  FindingCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "FindingCrewViewController.h"
#import "CountdownTimer.h"

@interface FindingCrewViewController () <CountdownTimerDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *countDownTimer;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel1;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel2;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel3;

@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages;

@end

@implementation FindingCrewViewController

-(void) viewDidLoad
{
    [super viewDidLoad];
    [self setupAnimation];
}


-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //outlets are loaded, now arm the timer
    [self armUpCountdownTimer];
    
    //start the animation of images
    [self startAnimatingImage:self.imageView1];
    [self startAnimatingImage:self.imageView2];
    [self startAnimatingImage:self.imageView3];
}


#pragma animation
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

#pragma countdown timer
-(void) armUpCountdownTimer
{
    CountdownTimer * cdt = [[CountdownTimer alloc] init];
    cdt.cdTimerDelegate = self;
    [cdt initializeWithSecondsRemaining:self.secondsToExpire ForLabel:self.countDownTimer];
}

- (void)countdownTimerExpired
{
    NSLog(@"%s", __func__);
    [self stopAnimatingImage:self.imageView1];
    [self stopAnimatingImage:self.imageView2];
    [self stopAnimatingImage:self.imageView3];

    [self rideFindTimeExpired];
}

#pragma ride cancel

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
    //TODO: DELETE ride request
    //cancel ride request using the ride request public id
    /*URL = http://api.getstowaway.com/api/v1/users/2156610/requests/publicid
     BODY = nil
     METHOD = delete
     */
    
    //go back to enter drop off pick up
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}


#pragma find ride

-(void)rideFindTimeExpired
{
    //if there are no matches, ask user if they want to wait more
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Matches Yet !"
                                                    message:@"Do you want to wait a bit more ?"
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
    

    //check if there is atleast one match,
        //if so ask server for roles
            //move to meet crew screen
    
    
}

#pragma process ride response
/*
 push notification for a ride match(this is the match):
 {"location_channel"=>"447fffe534a9cd816332", "public_id"=>7384424, :requests=>[{"status"=>"matched", "designation"=>nil, "public_id"=>1200365, "requested_at"=>1394082222, :user_public_id=>3275123, :uid=>"3374"}]
 
 push notification for a fulfilled ride:
 
 {"location_channel"=>"447fffe534a9cd816332", "public_id"=>7384424, :requests=>[{"status"=>"fulfilled", "designation"=>nil, "public_id"=>1200365, "requested_at"=>1394082222, :user_public_id=>3275123, :uid=>"3374"}]
 */

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
}


#pragma alert delegates
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
    }

}

// to take care of user pressing home button on the alert

- (void)alertViewCancel:(UIAlertView *)alertView
{
    //wait for another 5mins, if no matches
    
}
@end
