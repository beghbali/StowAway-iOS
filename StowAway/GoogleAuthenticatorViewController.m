//
//  GoogleAuthenticatorViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "GoogleAuthenticatorViewController.h"
#include "GTMOAuth2Authentication.h"
#include "GTMOAuth2ViewControllerTouch.h"
#include "GTMOAuth2SignIn.h"

#define CLIENT_ID       @"959311382355-ev9e7hcsktb9hothfpo1ip27c92fd726.apps.googleusercontent.com"
#define CLIENT_SECRET   @"pz62Gn5ZrRObzaRDEWVz9kyz"

static NSString *const kKeychainItemName = @"OAuth StowAway: Google";


@interface GoogleAuthenticatorViewController ()

@property (nonatomic)  GTMOAuth2Authentication * googleAuth;
@property GTMOAuth2ViewControllerTouch * gtmVC;

@end

@implementation GoogleAuthenticatorViewController

- (IBAction)cancelBarButtonAction:(UIBarButtonItem *)sender {
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);

}

- (GTMOAuth2Authentication *)getGoogleAuth
{
    
        NSLog(@"getting auth from google");
    
    GTMOAuth2Authentication * googleAuth = [GTMOAuth2Authentication authenticationWithServiceProvider:kGTMOAuth2ServiceProviderGoogle
                                                                                             tokenURL:[GTMOAuth2SignIn googleTokenURL]
                                                                                          redirectURI:[GTMOAuth2SignIn nativeClientRedirectURI]
                                                                                             clientID:CLIENT_ID
                                                                                         clientSecret:CLIENT_SECRET];
    googleAuth.scope = @"openid email";
    
    return googleAuth;
}


- (void)signInToGoogle
{

    GTMOAuth2Authentication * auth = [self googleAuth];

    // Display the authentication view
//    GTMOAuth2ViewControllerTouch * gtmVC;
    self.gtmVC = [[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:auth
                                                                 authorizationURL:[GTMOAuth2SignIn googleAuthorizationURL]
                                                                 keychainItemName:kKeychainItemName
                                                                         delegate:self
                                                                 finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
   /*
    self.gtmVC.rightBarButtonItem = self.cancelBarButton;
    self.gtmVC.rightBarButtonItem.enabled = YES;

    self.gtmVC.navigationItem.rightBarButtonItem = self.cancelBarButton;
    */
    
  [self.gtmVC setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self presentViewController:self.gtmVC animated:YES completion:nil];

    //TODO:: fix the google auth view
 
   // [self.navigationController pushViewController:self.gtmVC animated:YES];
   // self.webView = gtmVC.webView;

}


- (void)viewController:(GTMOAuth2ViewControllerTouch * )viewController
      finishedWithAuth:(GTMOAuth2Authentication * )auth
                 error:(NSError * )error
{

    [self.navigationController popToViewController:self animated:NO];

    if (error != nil) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error Authorizing with Google"
                                                         message:[error localizedDescription]
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        [alert show];
    } else {
        //Authorization was successful - get location information
        
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Success Authorizing with Google"
                                                         message:[auth accessToken]
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        
        [alert show];
        self.googleAuth = auth;
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        NSLog(@"finished google auth, error:%@, auth accessToken %@, refresh token %@", error, [auth accessToken], [auth refreshToken]);
        [self performSelectorOnMainThread:@selector(authWithGoogleReturned) withObject:nil waitUntilDone:NO];}];

}

- (void) authWithGoogleReturned
{
    //do all the UI stuff on the main thread
    
    //SUCCESS - move to the next screen - ie credit card
    
    //FAILURE - go back to receipts linking screen
}

// verify if the user is already connected or not
- (void)beginGoogleAuthProcess
{
    // Check for authorization.
    GTMOAuth2Authentication *authFromKeychain =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                          clientID:CLIENT_ID
                                                      clientSecret:CLIENT_SECRET];
    if ([authFromKeychain canAuthorize]) {
        self.googleAuth = authFromKeychain;
        NSLog(@"already logged in, auth token expires in %@", [self.googleAuth expiresIn]);
        
        [self.navigationController popViewControllerAnimated:YES];

    }else {
        self.googleAuth = [self getGoogleAuth];

        [self signInToGoogle];
    }
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);

    [self beginGoogleAuthProcess];
}

@end
