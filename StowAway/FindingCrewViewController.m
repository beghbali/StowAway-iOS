//
//  FindingCrewViewController.m
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "FindingCrewViewController.h"
#import "CountdownTimer.h"

@interface FindingCrewViewController () <CountdownTimerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *countDownTimer;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (strong, nonatomic) NSMutableArray * /*of UIImage*/ animationImages;

@end

@implementation FindingCrewViewController

-(void) viewDidLoad
{
    
    [super viewDidLoad];
    
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

-(void) armUpCountdownTimer
{
    CountdownTimer * cdt = [[CountdownTimer alloc] init];
    cdt.cdTimerDelegate = self;
    [cdt initializeWithSecondsRemaining:self.secondsToExpire ForLabel:self.countDownTimer];
}

- (IBAction)cancelButtonTapped:(UIButton *)sender
{
    //go back to enter drop off pick up
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

#pragma CountdownTimer Delegate
- (void)countdownTimerExpired
{
    NSLog(@"%s", __func__);
    [self stopAnimatingImage:self.imageView1];
    [self stopAnimatingImage:self.imageView2];
    [self stopAnimatingImage:self.imageView3];

}


@end
