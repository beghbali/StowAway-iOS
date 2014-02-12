//
//  ReceiptEmailViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/10/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "ReceiptEmailViewController.h"
#import "LoginViewController.h"

@interface ReceiptEmailViewController ()

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
//@property (weak, nonatomic) IBOutlet UIButton *receiptsContinueButton;
@end

@implementation ReceiptEmailViewController



- (void) showGoogleAuthenticator
{
    
}


-(void) viewDidDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController) {
        NSLog(@"isMovingFromParentViewController");
        LoginViewController *loginVC = (LoginViewController *)self.parentViewController; // get results out of vc, which I presented
        loginVC.facebookLoginStatus = YES; //you can only reach receipts after login
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@"email entered <%@>",self.emailTextField.text);
    [self.emailTextField resignFirstResponder];
    return YES;
}

@end
