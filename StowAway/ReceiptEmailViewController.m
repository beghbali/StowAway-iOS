//
//  ReceiptEmailViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/10/14.
//  Copyright (c) 2014 Francis Fernandes. All rights reserved.
//

#import "ReceiptEmailViewController.h"
#import "LoginViewController.h"

@interface ReceiptEmailViewController ()

@end

@implementation ReceiptEmailViewController

-(void) viewDidDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController) {
        NSLog(@"isMovingFromParentViewController");
        LoginViewController *loginVC = (LoginViewController *)self.parentViewController; // get results out of vc, which I presented
        loginVC.facebookLoginStatus = YES; //you can only reach receipts after login
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
