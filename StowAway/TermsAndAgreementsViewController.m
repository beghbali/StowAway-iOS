//
//  TermsAndAgreementsViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/24/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "TermsAndAgreementsViewController.h"

@interface TermsAndAgreementsViewController ()
@property (weak, nonatomic) IBOutlet UIButton *agreeButton;
@property (weak, nonatomic) IBOutlet UIWebView *termsWebView;

@end

@implementation TermsAndAgreementsViewController

- (IBAction)termsAgreedButtonTapped:(UIButton *)sender
{
    NSLog(@"agreed to terms ");

    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:@"isTermsAndAgreementsDone"];
    [[NSUserDefaults standardUserDefaults] synchronize];

}

-(void)viewDidLoad
{
    BOOL isTermsAndAgreementsDone = [[[NSUserDefaults standardUserDefaults] objectForKey:@"isTermsAndAgreementsDone"] boolValue];
    
    if ( isTermsAndAgreementsDone)
    {
        NSLog(@"terms and agreement already done... move to next view");
        [self performSegueWithIdentifier: @"enter pickup dropoff" sender: self];
    }
    
    NSString * enquiryurl = @"https://getstowaway.com/legal/terms.html";
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:enquiryurl]];

    [self.termsWebView loadRequest: request];
}

@end
