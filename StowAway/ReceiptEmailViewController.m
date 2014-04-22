//
//  ReceiptEmailViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/10/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "EnterPickupDropOffViewController.h"

#import "ReceiptEmailViewController.h"
#import "LoginViewController.h"
#import "GoogleAuthenticator.h"
#import "StowawayServerCommunicator.h"
#import "StowawayConstants.h"
#import "SWRevealViewController.h"

@interface ReceiptEmailViewController () <UITextFieldDelegate, GoogleAuthenticatorDelegate, StowawayServerCommunicatorDelegate>

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

@end

@implementation ReceiptEmailViewController


-(void)viewDidLoad
{
    [super viewDidLoad];
  
    [self.emailTextField becomeFirstResponder];

}


- (IBAction)skipTapped:(UIBarButtonItem *)sender
{
    UIViewController * presentingVC = self.presentingViewController;
    
    while ( [presentingVC class] != [SWRevealViewController class] )
        presentingVC = presentingVC.presentingViewController;
    
    [EnterPickupDropOffViewController setOnBoardingStatusChecked:YES];

    [presentingVC dismissViewControllerAnimated:YES completion:nil];
}

// to check what the user is writting -- show red/green text box
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString * email = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    textField.layer.borderWidth = 1.0f;
    
    if ([self isEmailValid:email])
        textField.layer.borderColor = [[UIColor greenColor] CGColor];
    else
        textField.layer.borderColor = [[UIColor redColor] CGColor];
    
    return YES;
}


-(BOOL)isEmailValid:(NSString *)checkString
{
    BOOL stricterFilter = YES; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSString *laxString = @".+@([A-Za-z0-9]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:checkString];
}


-(NSString *) getEmailProvider: (NSString *)email
{
    NSString * provider = nil;
    
    NSArray *components = [email componentsSeparatedByString: @"@"];
    
    NSString *domain = [components objectAtIndex:1];
    
    provider = [[domain componentsSeparatedByString:@"."] objectAtIndex:0];

    if (![[NSArray arrayWithObjects:*kSupportedEmailProviders, nil] containsObject:[provider lowercaseString]])
        provider = @"other";
    
    return  provider;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@"email entered <%@>",self.emailTextField.text);
    
    if ( ![self isEmailValid:self.emailTextField.text] )
    {
        NSLog(@"invalid email format");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Argh !!"
                                                        message: @"did you mistype your email..."
                                                       delegate: nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return NO;
    }

    self.email = self.emailTextField.text;
    self.emailProvider = [self getEmailProvider:self.email];
    NSLog(@"provider -- %@",self.emailProvider);
    
    if ( [self.emailProvider caseInsensitiveCompare:@"gmail"] == NSOrderedSame )
    {
        NSLog(@"gmail = show auth button");
        
        //hide is gmail question and answer
        self.isUsingGmailLabel.hidden = YES;
        self.isGmailNoButton.hidden = YES;
        self.isGmailYesButton.hidden = YES;
        
        //hide uber email change instructions
        self.changeUberEmailTextView.hidden = YES;
        self.showMeHowButton.hidden =   YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        
        //set final action button
        self.finalActionButton.titleLabel.text = @"Connect Inbox";
        self.finalActionButton.hidden = NO;
    } else
    {
        NSLog(@"not gmail = ask provider");

        //show is gmail question and answer
        self.isUsingGmailLabel.hidden = NO;
        self.isGmailNoButton.hidden = NO;
        self.isGmailNoButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        self.isGmailYesButton.hidden = NO;
        self.isGmailYesButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        
        //hide uber email change instructions
        self.changeUberEmailTextView.hidden = YES;
        self.showMeHowButton.hidden =   YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        
        //hide final action button
        self.finalActionButton.hidden = YES;
    }
    
    [self.emailTextField resignFirstResponder];
    return YES;
}


-(void)setOtherMailTexts
{
    //TODO: make the email bold - nsattributed text
    NSString * stowawayEmail = [[NSUserDefaults standardUserDefaults] objectForKey:kStowawayEmail];
    self.changeUberEmailTextView.text = [NSString stringWithFormat:
                                              @"To use Stowaway, you'll need to update your email in the Uber app to %@", stowawayEmail];

    self.stowawayEmailFooterLabel.text = [NSString stringWithFormat:
                                              @"Don't worry... you will also get uber receipts at %@", self.email];
}

- (IBAction)mailProviderSelected:(UIButton *)sender
{
    if ([sender.titleLabel.text isEqualToString:@"Yes"])
    {
        NSLog(@"google selected");
        
        //highlight yes button
        sender.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        self.isGmailNoButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        
        //hide uber change email stuff
        self.changeUberEmailTextView.hidden = YES;
        self.showMeHowButton.hidden =   YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        
        //set final action button
        self.finalActionButton.titleLabel.text = @"Connect Inbox";
        self.finalActionButton.hidden = NO;
    } else
    {
        NSLog(@"other selected");
        
        //highlight no button
        sender.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        self.isGmailYesButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        
        // set uber email change instruction
        [self setOtherMailTexts];

        //show uber change email stuff
        self.changeUberEmailTextView.hidden = NO;
        self.showMeHowButton.hidden =   NO;
        self.stowawayEmailFooterLabel.hidden = NO;
        
        //set final action button
        self.finalActionButton.titleLabel.text = @"        Done     ";
        self.finalActionButton.hidden = NO;
    }
}

- (void)googleAuthenticatorResult: (NSError *)error
{
    NSLog(@"%s::: error %@", __func__, error);
    if ( !error )
    {
        [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusReceiptsDone];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self performSegueWithIdentifier: @"go to payment" sender: self];
    }
}


- (IBAction)authenticateWithGoogle:(UIButton *)sender
{
    if ( [sender.titleLabel.text isEqualToString:@"Connect Inbox"] )
    {
        GoogleAuthenticator * googleAuthenticator = [[GoogleAuthenticator alloc]init];
        googleAuthenticator.googleAuthDelegate = self;
        googleAuthenticator.email = self.email;
        googleAuthenticator.emailProvider = self.emailProvider;
        
        //show gtm view
        [googleAuthenticator authenticateWithGoogle:self ForEmail:self.email];
    } else
        [self confirmedOtherEmailButtonTapped];
        
}

- (void)confirmedOtherEmailButtonTapped
{
    //send the other email to server
    //SUCCESS - move to the next screen - ie credit card
    NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
    
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@", publicUserId];
    
    NSString *userdata = [NSString stringWithFormat:@"{\"%@\":\"%@\", \"%@\":\"%@\"}",
                                                      kUserEmail, self.email,
                                                      kUserEmailProvider, self.emailProvider];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];

    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusReceiptsDone];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // segue to payment screen
    [self performSegueWithIdentifier: @"go to payment" sender: self];
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
}


-(void) viewDidDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController)
    {
        NSLog(@"isMovingFromParentViewController");
        
        if ([self.parentViewController class] == [LoginViewController class])
        {
            LoginViewController *loginVC = (LoginViewController *)self.parentViewController; // get results out of vc, which I presented
            loginVC.facebookLoginStatus = YES; //you can only reach receipts after login
        }
    }
}



@end
