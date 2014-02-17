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

@interface LoginViewController ()
@property (strong, nonatomic) IBOutlet FBLoginView *loginView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *nextBarButton;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePictureView;
//@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property BOOL sequeAlreadyDone;
@end

@implementation LoginViewController


- (void) setFacebookLoginStatus:(BOOL)facebookLoginStatus
{
    NSLog(@"facebookLoginStatus %d", facebookLoginStatus);
    self.navigationItem.rightBarButtonItem.enabled = facebookLoginStatus; //hide next button if not logged in
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
        NSLog(@"segue id: %@", segue.identifier);
    
    if ([segue.identifier isEqualToString:@"fbNextToReceipts"] || [segue.identifier isEqualToString:@"fbLoginToReceipt"]) {
        if ([segue.destinationViewController class] == [ReceiptEmailViewController class]) {
            ReceiptEmailViewController * receiptVC = segue.destinationViewController; //incase we need to setup some stuff - for autosuggestion of stowaway email address
        }
    }
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    self.facebookLoginStatus = NO;
    self.loginView.delegate = self;
    self.loginView.readPermissions = @[@"basic_info", @"email", @"user_likes"];

    if (FBSession.activeSession.isOpen)
    {
        NSLog(@"fb: already logged in");
        self.facebookLoginStatus = YES;
        [self moveToEmailRegistration];
    } else {
        NSLog(@"fb: not logged in");
    }
}

-( void) moveToEmailRegistration
{
    if (!self.sequeAlreadyDone) {
        
        self.sequeAlreadyDone = YES;
        [self performSegueWithIdentifier: @"fbLoginToReceipt" sender: self];
    }
    else
        NSLog(@"segue already done");

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - FBLoginView Delegate methods

// This method will be called when the user information has been fetched
- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView user:(id<FBGraphUser>)user
{
    //for the login UI
    self.profilePictureView.profileID = user.id;
    self.nameLabel.text = user.name;
    
    /*Send User Data to API on the user TODO Should be made into an object!!!!*/
    //NSString *url =@"http://ec2-54-214-145-124.us-west-2.compute.amazonaws.com/api/v1/users/";
    NSString *url =@"http://api.getstowaway.com/api/v1/users/";
    
    // Like the post request I showed you before, I'm going to send the deviceId again, because that is generally useful for establishing
    
    NSDate *fbAccessTokenExpirationDate = [[[FBSession activeSession] accessTokenData] expirationDate];
    NSString *fbAccessToken = [[[FBSession activeSession] accessTokenData] accessToken];
    NSString *provider = @"facebook";
    
    NSString *userdata = [NSString stringWithFormat:@"{\"first_name\":\"%@\", \"last_name\":\"%@\", \"image_url\":\"http://graph.facebook.com/%@/picture?type=square\", \"location\":\"%@\", \"profile_url\":\"https://www.facebook.com/%@\",\"token\":\"%@\",\"expires_at\":\"%@\"}",user.first_name,user.last_name,user.id,user.location.name,user.username,fbAccessToken,fbAccessTokenExpirationDate];
    NSLog(@"userdata:\n%@",userdata);
    
    NSString *post = [NSString stringWithFormat:@"{\"uid\":%@,\"provider\":\"%@\",\"user\":%@}", user.id, provider, userdata];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
   // NSURLResponse *response;
    //NSError *error;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config];

    /*
     
     sessionConfiguration.HTTPAdditionalHeaders = @{
     @"api-key"       : @"API_KEY",
     };

     */
    NSURLSessionDataTask *postDataTask = [session
                                          dataTaskWithRequest:request
                                            completionHandler:^(NSData *jsonData,
                                                                NSURLResponse *response,
                                                                NSError *error)
    {

   /* NSURLSessionUploadTask *uploadTask = [session
                                          uploadTaskWithRequest:request
                                          fromData:nil
                                          completionHandler:^(NSData *jsonData,
                                                              NSURLResponse *response,
                                                              NSError *error)
    {
    */
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
        
        NSLog(@"httpResp.statusCode %d, error %@",httpResp.statusCode , error );

        if (!error && httpResp.statusCode == 201)   //201=post successful
        {
            
            NSDictionary *results = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error]: nil;
            
            NSLog(@"results: %@, error %@", results, error);
        } else {
            NSLog(@"ERROR !!" );
        }
    }];
    
    [postDataTask resume];
   // NSData *jsonData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    
    /*End of Code for Adding User*/
    
    /*  Example for JSON data
curl -X POST -d '{ "provider":"facebook", 
     "uid":123123, 
     "user":{"first_name":"Joe", "last_name":"Bloggs", "image_url":"http://graph.facebook.com/12345678/picture?type=square",
     "token":"AF4234B3C", "expires_at":1321747205, "gender":"male", "location":"Palo Alto, California", "verified":true, "profile_url":"https://www.facebook.com/thebashir"}}' http://ec2-54-214-145-124.us-west-2.compute.amazonaws.com//api/v1/users -H "Content-Type:application/json"
     */
    
    
}

// Logged-in user experience
- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView {
   /* status is obvious
    self.statusLabel.text = @"You're logged in as";
    */
    NSLog(@"fb: just logged in");
    self.facebookLoginStatus = YES;

    [self moveToEmailRegistration];
    
}

// Logged-out user experience
- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView {
    NSLog(@"fb: just logged out");
    self.profilePictureView.profileID = nil;
    self.nameLabel.text = @"";
    self.facebookLoginStatus = NO;
    self.sequeAlreadyDone = NO;
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
