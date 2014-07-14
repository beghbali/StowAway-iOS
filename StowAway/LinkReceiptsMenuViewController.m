//
//  LinkReceiptsMenuViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "LinkReceiptsMenuViewController.h"
#import "SWRevealViewController.h"
#import "StowawayServerCommunicator.h"
#import "GoogleAuthenticator.h"

@interface LinkReceiptsMenuViewController () <UITextFieldDelegate, GoogleAuthenticatorDelegate, StowawayServerCommunicatorDelegate>

@property (strong, nonatomic)  NSString * email;
@property (strong, nonatomic)  NSString * emailProvider;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;

@property (weak, nonatomic) IBOutlet UILabel *changeUberEmailTextView;
@property (weak, nonatomic) IBOutlet UIButton *showMeHowButton;
@property (weak, nonatomic) IBOutlet UILabel *stowawayEmailFooterLabel;

@property (weak, nonatomic) IBOutlet UILabel *isUsingGmailLabel;
@property (weak, nonatomic) IBOutlet UIButton *isGmailYesButton;
@property (weak, nonatomic) IBOutlet UIButton *isGmailNoButton;

@property (weak, nonatomic) IBOutlet UIButton *finalActionButton;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *revealButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButton;

@end

@implementation LinkReceiptsMenuViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(void)setUpRevealMenuButton
{
    //set up the reveal button
    [self.revealButtonItem setTarget: self.revealViewController];
    [self.revealButtonItem setAction: @selector( revealToggle: )];
    [self.navigationController.navigationBar addGestureRecognizer: self.revealViewController.panGestureRecognizer];
}

- (void)viewDidLoad
{
    super.emailTextField = self.emailTextField;
        
    super.changeUberEmailTextView = self.changeUberEmailTextView;
    super.showMeHowButton = self.showMeHowButton;
    super.stowawayEmailFooterLabel = self.stowawayEmailFooterLabel;
        
    super.isUsingGmailLabel = self.isUsingGmailLabel;
    super.isGmailYesButton = self.isGmailYesButton;
    super.isGmailNoButton = self.isGmailNoButton;
        
    super.finalActionButton = self.finalActionButton;

    [super viewDidLoad];

    self.emailTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"linkedReceiptEmail"];

    [self setUpRevealMenuButton];

    //show the change uber email text, as a reminder to user
    NSNumber * isUsingStowawayEmailNum = [[NSUserDefaults standardUserDefaults] objectForKey:kIsUsingStowawayEmail];
    if (isUsingStowawayEmailNum && [isUsingStowawayEmailNum boolValue])
    {
        self.changeUberEmailTextView.hidden = NO;
        self.stowawayEmailFooterLabel.hidden = NO;

        NSString * stowawayEmail = [[NSUserDefaults standardUserDefaults] objectForKey:kStowawayEmail];
        self.changeUberEmailTextView.text = [NSString stringWithFormat:
                                             @"To use Stowaway, you'll need to update your email in the Uber app to: %@", stowawayEmail];
        
        NSLog(@"%@", self.changeUberEmailTextView.text );
        self.changeUberEmailTextView.attributedText = [StowawayConstants boldify:stowawayEmail
                                                                    ofFullString:self.changeUberEmailTextView.text
                                                                        withFont:[UIFont boldSystemFontOfSize:13]];
        
        self.stowawayEmailFooterLabel.text = [NSString stringWithFormat:
                                              @"Don't worry... you will also get Uber receipts at %@", self.emailTextField.text];
        NSLog(@"%@", self.stowawayEmailFooterLabel.text);
        self.stowawayEmailFooterLabel.attributedText = [StowawayConstants boldify:self.emailTextField.text
                                                                     ofFullString:self.stowawayEmailFooterLabel.text
                                                                         withFont:[UIFont boldSystemFontOfSize:10]];
        self.showMeHowButton.hidden = NO;

    }
    
}

- (IBAction)editBarButtonTapped:(UIBarButtonItem *)sender
{
    self.changeUberEmailTextView.hidden = YES;
    self.stowawayEmailFooterLabel.hidden = YES;
    self.showMeHowButton.hidden = YES;

    self.emailTextField.userInteractionEnabled = YES;
    [self.emailTextField becomeFirstResponder];
}



- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"%s: -- %@ -- %@ -- ", __func__, data, sError);
    
    if (sError)
        return;
    
    [[NSUserDefaults standardUserDefaults] setObject: self.email forKey:@"linkedReceiptEmail"];
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusReceiptsDone];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self doneEditing];
}

- (void)googleAuthenticatorResult: (NSError *)error
{
    NSLog(@"%s::: error %@", __func__, error);
    if ( error )
        return;
    
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusReceiptsDone];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self doneEditing];
}

-(void)doneEditing
{
    self.changeUberEmailTextView.text =  @"Your change has been saved,\nnow go Request Ride from menu option\nor Edit to change again.";
    self.changeUberEmailTextView.attributedText = [StowawayConstants boldify:@"Request Ride"
                                                   ofFullString:self.changeUberEmailTextView.text
                                                       withFont:[UIFont boldSystemFontOfSize:14]];
    
    self.emailTextField.userInteractionEnabled = NO;
    
    self.showMeHowButton.hidden = YES;
    self.stowawayEmailFooterLabel.hidden = YES;
    
    self.isUsingGmailLabel.hidden = YES;
    self.isGmailYesButton.hidden = YES;
    self.isGmailNoButton.hidden = YES;
    
    self.finalActionButton.hidden = YES;
    
}

@end
