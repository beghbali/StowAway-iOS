//
//  TermsAndAgreementsViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/24/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "EnterPickupDropOffViewController.h"

#import "TermsAndAgreementsViewController.h"
#import "StowawayConstants.h"
#import "SWRevealViewController.h"

@interface TermsAndAgreementsViewController ()
@property (weak, nonatomic) IBOutlet UIButton *agreeButton;
@property (weak, nonatomic) IBOutlet UIWebView *termsWebView;

@end

@implementation TermsAndAgreementsViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (IBAction)skipTapped:(id)sender
{
    NSLog(@"skipping ...  terms ");
    [self goToStowAwayHome];
}

- (IBAction)termsAgreedButtonTapped:(UIButton *)sender
{
    NSLog(@"agreed to terms ");

    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusTermsDone];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self goToStowAwayHome];
}

-(void)goToStowAwayHome
{
    UIViewController * presentingVC = self.presentingViewController;
  
    NSLog(@"presenting vc %@ ", presentingVC);

    while ( [presentingVC class] != [SWRevealViewController class] )
    {
        presentingVC = presentingVC.presentingViewController;
        NSLog(@"next presenting vc %@", presentingVC);
    }
    NSLog(@" ======= return home =====");
    [EnterPickupDropOffViewController setOnBoardingStatusChecked:YES];

    [presentingVC dismissViewControllerAnimated:YES completion:nil];
    
}
-(void)viewDidLoad
{
    [super viewDidLoad];

    NSString * enquiryurl = @"https://getstowaway.com/legal/terms.html";

    NSLog(@"loading page from %@", enquiryurl);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:enquiryurl]];

    [self.termsWebView loadRequest: request];
}

@end
