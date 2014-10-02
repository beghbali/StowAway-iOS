//
//  UberSettingsGuideViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/20/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "UberSettingsGuideViewController.h"

@interface UberSettingsGuideViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation UberSettingsGuideViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}


- (IBAction)gotItButtonTapped:(UIButton *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSString * enquiryurl = @"https://getstowaway.com/setup/change-email.html";
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:enquiryurl]];
    
    [self.webView loadRequest: request];

}


@end
