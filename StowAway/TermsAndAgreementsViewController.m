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

-(void)viewDidLoad
{
    NSString * enquiryurl =
    @"http://www.apple.com/legal/internet-services/itunes/us/terms.html#SERVICE";
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:enquiryurl]];

    [self.termsWebView loadRequest: request];
}

@end
