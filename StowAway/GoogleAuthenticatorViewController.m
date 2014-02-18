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
#include "StowawayServerCommunicator.h"
#include "StowawayConstants.h"

#define CLIENT_ID       @"959311382355-ev9e7hcsktb9hothfpo1ip27c92fd726.apps.googleusercontent.com"
#define CLIENT_SECRET   @"pz62Gn5ZrRObzaRDEWVz9kyz"

static NSString *const kKeychainItemName = @"OAuth StowAway: Google";


@interface GoogleAuthenticatorViewController ()<StowawayServerCommunicatorDelegate>

@property (strong, nonatomic)   GTMOAuth2Authentication * googleAuth;
@property (strong, nonatomic)   GTMOAuth2ViewControllerTouch * gtmVC;
@property (strong, nonatomic)   NSString * stowawayPublicId;

- (void) authWithGoogleReturnedWithError: (NSError *)error;

@end

@implementation GoogleAuthenticatorViewController

- (void)gotServerResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
}


- (GTMOAuth2Authentication *)getGoogleAuth
{
    
    NSLog(@"getting auth from google");
    
    GTMOAuth2Authentication * googleAuth = [GTMOAuth2Authentication
                                            authenticationWithServiceProvider:kGTMOAuth2ServiceProviderGoogle
                                                                     tokenURL:[GTMOAuth2SignIn googleTokenURL]
                                                                  redirectURI:[GTMOAuth2SignIn nativeClientRedirectURI]
                                                                     clientID:CLIENT_ID
                                                                 clientSecret:CLIENT_SECRET];
    googleAuth.scope = @"openid email";
    
    return googleAuth;
}


- (void)signInToGoogle
{

    NSLog(@"** %s ***", __func__);

    GTMOAuth2Authentication * auth = [self googleAuth];

    // Prepare to display the authentication view

    self.gtmVC = [[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:auth
                                                             authorizationURL:[GTMOAuth2SignIn googleAuthorizationURL]
                                                             keychainItemName:kKeychainItemName
                                                                     delegate:self
                                                             finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
   
    //present it modally
    [self.gtmVC setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self presentViewController:self.gtmVC animated:YES completion:nil];
}


- (void)viewController:(GTMOAuth2ViewControllerTouch * )viewController
      finishedWithAuth:(GTMOAuth2Authentication * )auth
                 error:(NSError * )error
{

    //[self.navigationController popToViewController:self animated:YES];

        NSLog(@"** %s ***", __func__);
    self.googleAuth = auth;
    
    [self dismissViewControllerAnimated:YES completion:^{
        NSLog(@"finished google auth, error:%@, auth accessToken %@, refresh token %@", error, [auth accessToken], [auth refreshToken]);
        [self performSelectorOnMainThread:@selector(authWithGoogleReturnedWithError:) withObject:error waitUntilDone:NO];}];

}

- (void) authWithGoogleReturnedWithError: (NSError *)error
{
    //do all the UI stuff on the main thread
        NSLog(@"** %s ***", __func__);
    if (error != nil)
    {
        //FAILURE - go back to receipts linking screen

        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error Authorizing with Google"
                                                         message:[error localizedDescription]
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        [alert show];
    } else
    {
        //SUCCESS - move to the next screen - ie credit card
      
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Success Authorizing with Google"
                                                         message:[self.googleAuth accessToken]
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
        
        [alert show];
    }

    [self.navigationController popViewControllerAnimated:YES];

    
}

// check if the user is already google auth'ed
- (void)beginGoogleAuthProcess
{
        NSLog(@"** %s ***", __func__);
    // Check for authorization saved in keychain
    GTMOAuth2Authentication *authFromKeychain =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                          clientID:CLIENT_ID
                                                      clientSecret:CLIENT_SECRET];
    if ([authFromKeychain canAuthorize])
    {
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

    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

    self.stowawayPublicId = [standardDefaults objectForKey:kPublicId];
    NSLog(@"\n** %s %@: %@**\n", __PRETTY_FUNCTION__, kPublicId, self.stowawayPublicId);

    [self beginGoogleAuthProcess];
}

@end
