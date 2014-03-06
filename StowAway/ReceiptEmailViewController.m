//
//  ReceiptEmailViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/10/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "ReceiptEmailViewController.h"
#import "LoginViewController.h"
#import "GoogleAuthenticator.h"
#import "StowawayServerCommunicator.h"
#import "StowawayConstants.h"

@interface ReceiptEmailViewController () <UITextFieldDelegate, GoogleAuthenticatorDelegate, StowawayServerCommunicatorDelegate>

@property (strong, nonatomic)  NSString * email;
@property (strong, nonatomic)  NSString * emailProvider;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UILabel *askMailProviderLabel;
@property (weak, nonatomic) IBOutlet UIButton *googleMailProviderButton;
@property (weak, nonatomic) IBOutlet UIButton *otherMailProviderButton;
@property (weak, nonatomic) IBOutlet UIButton *authenticateWithGoogleButton;
@property (weak, nonatomic) IBOutlet UIButton *gotItButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *nextBarButton;
@property (weak, nonatomic) IBOutlet UILabel *stowawayEmailFooterLabel;
@property (weak, nonatomic) IBOutlet UITextView *changeUberEmailTextView;

@end

@implementation ReceiptEmailViewController

-(void) viewDidLoad
{
    [super viewDidLoad];
  
    //TODO: encapsulate the buttons appearence and hiding into a function
    
    //hide labels, buttons and text view
    self.askMailProviderLabel.hidden = YES;
    self.googleMailProviderButton.hidden = YES;
    self.otherMailProviderButton.hidden = YES;
    self.changeUberEmailTextView.hidden = YES;
    self.stowawayEmailFooterLabel.hidden = YES;
    self.authenticateWithGoogleButton.hidden = YES;
    self.gotItButton.hidden = YES;
    self.nextBarButton.enabled = NO;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    //auto bring up keyboard to enter email
    [self.emailTextField becomeFirstResponder];
    
    //hide labels, buttons and text view
    self.askMailProviderLabel.hidden = YES;
    self.googleMailProviderButton.hidden = YES;
    self.otherMailProviderButton.hidden = YES;
    self.changeUberEmailTextView.hidden = YES;
    self.stowawayEmailFooterLabel.hidden = YES;
    self.authenticateWithGoogleButton.hidden = YES;
    self.gotItButton.hidden = YES;
    self.nextBarButton.enabled = NO;
    
    self.googleMailProviderButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
    self.otherMailProviderButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
}

// to check what the user is writting -- show red/green text box
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString * email = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    textField.layer.borderWidth = 1.0f;
    
    if ([self isEmailValid:email])
    {
        textField.layer.borderColor = [[UIColor greenColor] CGColor];
        
    } else
    {
        textField.layer.borderColor = [[UIColor redColor] CGColor];
    }
    
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
    
    if ( [self.emailProvider caseInsensitiveCompare:@"gmail"] == NSOrderedSame ) {
        NSLog(@"gmail = show auth button");
        
        self.askMailProviderLabel.hidden = YES;
        self.googleMailProviderButton.hidden = YES;
        self.otherMailProviderButton.hidden = YES;
        
        self.changeUberEmailTextView.hidden = YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        
        self.authenticateWithGoogleButton.hidden = NO;
        
        self.gotItButton.hidden = YES;
    } else
    {
        NSLog(@"not gmail = ask provider");

        self.askMailProviderLabel.hidden = NO;
        self.googleMailProviderButton.hidden = NO;
        self.otherMailProviderButton.hidden = NO;
        
        self.changeUberEmailTextView.hidden = YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        
        self.authenticateWithGoogleButton.hidden = YES;
        
        self.gotItButton.hidden = YES;
    }
    
    [self.emailTextField resignFirstResponder];
    return YES;
}

-(void)setOtherMailTexts
{
    //TODO: changing this to textview would be better ?
    NSString * stowawayEmail = [[NSUserDefaults standardUserDefaults] objectForKey:kStowawayEmail];
    self.changeUberEmailTextView.text = [NSString stringWithFormat:
                                              @"To read uber receipts, you will need to set your email in ubers account settings to %@", stowawayEmail];

    self.stowawayEmailFooterLabel.text = [NSString stringWithFormat:
                                              @"Don't worry... you will also get uber receipts at %@", self.email];
}

- (IBAction)mailProviderSelected:(UIButton *)sender
{
    if ([sender.titleLabel.text isEqualToString:@"Google"]) {
        NSLog(@"google selected");
        sender.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
        self.otherMailProviderButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        self.authenticateWithGoogleButton.hidden = NO;
        
        self.changeUberEmailTextView.hidden = YES;
        self.stowawayEmailFooterLabel.hidden = YES;
        self.gotItButton.hidden = YES;
    } else
    {
        NSLog(@"other selected");
        [self setOtherMailTexts];
        sender.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
        self.googleMailProviderButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        self.authenticateWithGoogleButton.hidden = YES;
        
        self.changeUberEmailTextView.hidden = NO;
        self.stowawayEmailFooterLabel.hidden = NO;
        self.gotItButton.hidden = NO;

    }
}

- (void)googleAuthenticatorResult: (NSError *)error
{
    NSLog(@"%s::: error %@", __func__, error);
    if ( !error ) {
        [self performSegueWithIdentifier: @"go to payment" sender: self];
    }
}


- (IBAction)authenticateWithGoogle:(UIButton *)sender {
    
    GoogleAuthenticator * googleAuthenticator = [[GoogleAuthenticator alloc]init];
    googleAuthenticator.googleAuthDelegate = self;
    googleAuthenticator.email = self.email;
    googleAuthenticator.emailProvider = self.emailProvider;
    
    //show gtm view
    [googleAuthenticator authenticateWithGoogle:self ForEmail:self.email];
}

- (IBAction)confirmedOtherEmailButtonTapped:(UIButton *)sender
{
    //send the other email to server
    //SUCCESS - move to the next screen - ie credit card
    NSString * stowawayPublicId = [[NSUserDefaults standardUserDefaults] objectForKey:kPublicId];
    NSLog(@"\n** %s %@: %@**\n", __PRETTY_FUNCTION__, kPublicId, stowawayPublicId);
    
    NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@", stowawayPublicId];
    
    NSString *userdata = [NSString stringWithFormat:@"{\"%@\":\"%@\", \"%@\":\"%@\"}",
                                                      kUserEmail, self.email,
                                                      kUserEmailProvider, self.emailProvider];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];

    // segue to payment screen
    [self performSegueWithIdentifier: @"go to payment" sender: self];
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
}


-(void) viewDidDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController) {
        NSLog(@"isMovingFromParentViewController");
        LoginViewController *loginVC = (LoginViewController *)self.parentViewController; // get results out of vc, which I presented
        loginVC.facebookLoginStatus = YES; //you can only reach receipts after login
    }
}



@end
