//
//  ViewController.m
//  StowAway
//
//  Created by Francis Fernandes on 1/20/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "LoginViewController.h"
#import <FacebookSDK/FacebookSDK.h>
#import "ReceiptEmailViewController.h"
#import "StowawayServerCommunicator.h"
#import "StowawayConstants.h"

@interface LoginViewController () <StowawayServerCommunicatorDelegate>

@property (strong, nonatomic) IBOutlet FBLoginView *loginView;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePictureView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property BOOL gotLogInUserInfo;
@property UIImage * fbImage;
@end

@implementation LoginViewController

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
    id nsNullObj = (id)[NSNull null];
    
    //write user data to userdefaults
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

    NSString * userEmail = [data objectForKey:kUserEmail];
    if ( userEmail != nsNullObj ) [standardDefaults setObject: userEmail          forKey:kUserEmail];
    
    NSString * userEmailProvider = [data objectForKey:kUserEmailProvider];
    if ( userEmailProvider != nsNullObj ) [standardDefaults setObject: userEmailProvider  forKey:kUserEmailProvider];

    NSNumber * fbId = [data objectForKey:kFbId];
    if ( fbId != nsNullObj ) [standardDefaults setObject: fbId               forKey:kFbId];
    
    NSNumber * publicId = [data objectForKey:kPublicId];
    if ( publicId != nsNullObj ) [standardDefaults setObject: publicId           forKey:kUserPublicId];
    
    NSString * firstName = [data objectForKey:kFirstName];
    if ( firstName != nsNullObj ) [standardDefaults setObject: firstName          forKey:kFirstName];
    
    NSString * lastName = [data objectForKey:kLastName];
    if ( lastName != nsNullObj ) [standardDefaults setObject: lastName           forKey:kLastName];
    
    NSString * stowawayEmail = [data objectForKey:kStowawayEmail];
    if ( stowawayEmail != nsNullObj ) [standardDefaults setObject: stowawayEmail      forKey:kStowawayEmail];
    
    /*
    UIImage *contactImage = self.fbImage;
    NSData *imageData = UIImageJPEGRepresentation(contactImage, 100);
    [standardDefaults setObject:imageData forKey: @"fbImage"];
    */
    
    [standardDefaults synchronize];
     
    [self moveToEmailRegistration];
}

- (void) setFacebookLoginStatus:(BOOL)facebookLoginStatus
{
    NSLog(@"enable next button %d", facebookLoginStatus);
}

-( void) moveToEmailRegistration
{
    NSLog(@"%s: moveToEmailRegistration", __func__);
    [self performSegueWithIdentifier: @"fbLoginToReceipt" sender: self];

}

- (IBAction)cancelBarButtonTapped:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.loginView.delegate = self;
    self.loginView.readPermissions = @[@"basic_info", @"email", @"user_likes"];
    
    if (FBSession.activeSession.isOpen)
    {
        NSLog(@"viewDidLoad: fb already logged in");
        //[self moveToEmailRegistration];
    } else {
        NSLog(@"viewDidLoad: fb not logged in");
    }
}

+(BOOL)isFBLoggedIn
{
    
    NSLog(@"%s: FB activeSession %@", __func__ ,FBSession.activeSession);
    return (FBSession.activeSession.isOpen)||(FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded)? YES: NO;
}



#pragma mark - FBLoginView Delegate methods

// This method will be called when the user information has been fetched
- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView user:(id<FBGraphUser>)user
{
    NSLog(@"%s, gotLogInUserInfo %d", __func__, self.gotLogInUserInfo);
    
    if (self.gotLogInUserInfo)
        return;
    self.gotLogInUserInfo = YES;

    //for the login UI
    self.profilePictureView.profileID = user.id;
    self.nameLabel.text = user.name;
    
    NSString *url = @"http://api.getstowaway.com/api/v1/users/";
    
    NSDate *fbAccessTokenExpirationDate = [[[FBSession activeSession] accessTokenData] expirationDate];
    NSString *fbAccessToken = [[[FBSession activeSession] accessTokenData] accessToken];
    NSString *provider = @"facebook";
    NSString * fbImageURL = [NSString stringWithFormat:@"http://graph.facebook.com/%@/picture?type=square", user.id];
   
    //read device token from userdefaults
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString * deviceToken = [standardDefaults objectForKey:kDeviceToken];
    
//TODO: FIXIT fixIt - blocking the main Q
    self.fbImage = [UIImage imageWithData: [NSData dataWithContentsOfURL: [NSURL URLWithString: fbImageURL]]];

    NSString *userdata = [NSString stringWithFormat:@"{\"first_name\":\"%@\", \"last_name\":\"%@\", \"image_url\":\"%@\", \"location\":\"%@\", \"profile_url\":\"https://www.facebook.com/%@\",\"token\":\"%@\",\"expires_at\":\"%@\", \"%@\":\"%@\", \"%@\":\"%@\"}",
                          user.first_name, user.last_name, fbImageURL, user.location.name, user.username, fbAccessToken, fbAccessTokenExpirationDate,
                          kDeviceType, @"ios", kDeviceToken, deviceToken];
    
    NSString *post = [NSString stringWithFormat:@"{\"uid\":%@,\"provider\":\"%@\",\"user\":%@}", user.id, provider, userdata];
    

    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:post ForURL:url usingHTTPMethod:@"POST"];
}

// Logged-in user experience
- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView
{
    NSLog(@"fb: just logged in");
    self.facebookLoginStatus = YES;

   // [self moveToEmailRegistration];
    
}

// Logged-out user experience
- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView
{
    NSLog(@"fb: just logged out");
    self.gotLogInUserInfo = NO;
    
    self.profilePictureView.profileID = nil;
    self.nameLabel.text = @"";
    self.facebookLoginStatus = NO;
}

// Handle possible errors that can occur during login
- (void)loginView:(FBLoginView *)loginView handleError:(NSError *)error {
    NSString *alertMessage, *alertTitle;
    
    // If the user should perform an action outside of you app to recover,
    // the SDK will provide a message for the user, you just need to surface it.
    // This conveniently handles cases like Facebook password change or unverified Facebook accounts.
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        alertTitle = @"Facebook error";
        alertMessage = [FBErrorUtility userMessageForError:error];
        
        // This code will handle session closures that happen outside of the app
        // You can take a look at our error handling guide to know more about it
        // https://developers.facebook.com/docs/ios/errors
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession) {
        alertTitle = @"Session Error";
        alertMessage = @"Your current session is no longer valid. Please log in again.";
        
        // If the user has cancelled a login, we will do nothing.
        // You can also choose to show the user a message if cancelling login will result in
        // the user not being able to complete a task they had initiated in your app
        // (like accessing FB-stored information or posting to Facebook)
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
        NSLog(@"user cancelled login");
        
        // For simplicity, this sample handles other errors with a generic message
        // You can checkout our error handling guide for more detailed information
        // https://developers.facebook.com/docs/ios/errors
    } else {
        alertTitle  = @"Something went wrong";
        alertMessage = @"Please try again later.";
        NSLog(@"Unexpected error:%@", error);
    }
    
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:alertTitle
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

@end
