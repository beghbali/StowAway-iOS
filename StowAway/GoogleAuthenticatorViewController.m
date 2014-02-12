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

@end

@implementation GoogleAuthenticatorViewController


- (GTMOAuth2Authentication *)getGoogleAuth
{
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);
    
    //TODO: save it in keychain and check keychain before asking google again
    
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
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);

    GTMOAuth2Authentication * auth = [self googleAuth];

    // Display the authentication view
    GTMOAuth2ViewControllerTouch * gtmVC;
    gtmVC = [[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:auth
                                                                 authorizationURL:[GTMOAuth2SignIn googleAuthorizationURL]
                                                                 keychainItemName:kKeychainItemName
                                                                         delegate:self
                                                                 finishedSelector:@selector(viewController:finishedWithAuth:error:)];

    [gtmVC setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self presentViewController:gtmVC animated:YES completion:nil];

    //TODO:: fix the google auth view
    
   // [self.navigationController pushViewController:viewController animated:YES];
}


- (void)viewController:(GTMOAuth2ViewControllerTouch * )viewController
      finishedWithAuth:(GTMOAuth2Authentication * )auth
                 error:(NSError * )error
{
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);

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

    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    NSLog(@"\n** %s **\n", __PRETTY_FUNCTION__);
    self.googleAuth = [self getGoogleAuth];

    [self signInToGoogle];
}

@end
