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

@end

@implementation FindingCrewViewController

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //outlets are loaded, now arm the timer
    [self armUpCountdownTimer];
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
}


@end
