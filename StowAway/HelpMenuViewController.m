//
//  HelpViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/15/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "HelpMenuViewController.h"
#import "SWRevealViewController.h"

@interface HelpMenuViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *revealButtonItem;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation HelpMenuViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(void)setUpRevealMenuButton
{  //set up the reveal button
    [self.revealButtonItem setTarget: self.revealViewController];
    [self.revealButtonItem setAction: @selector( revealToggle: )];
    [self.navigationController.navigationBar addGestureRecognizer: self.revealViewController.panGestureRecognizer];
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setUpRevealMenuButton];
    
    NSString * enquiryurl = @"https://getstowaway.com/legal/faq.html";
    
#ifdef DEBUG
    NSLog(@"loading page from %@", enquiryurl);
#endif
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:enquiryurl]];
    
    [self.webView loadRequest: request];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
