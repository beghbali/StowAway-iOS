//
//  GoogleAuthenticator.m
//  StowAway
//
//  Created by Vin Pallen on 2/19/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "GoogleAuthenticator.h"

#include "GTMOAuth2Authentication.h"
#include "GTMOAuth2ViewControllerTouch.h"
#include "GTMOAuth2SignIn.h"
#include "StowawayServerCommunicator.h"
#include "StowawayConstants.h"

#define CLIENT_ID       @"959311382355-ev9e7hcsktb9hothfpo1ip27c92fd726.apps.googleusercontent.com"
#define CLIENT_SECRET   @"pz62Gn5ZrRObzaRDEWVz9kyz"

static NSString *const kKeychainItemName = @"OAuth StowAway: Google";

@interface GoogleAuthenticator() <StowawayServerCommunicatorDelegate>

@property (strong, nonatomic)   GTMOAuth2Authentication * googleAuth;
@property (strong, nonatomic)   GTMOAuth2ViewControllerTouch * gtmVC;
@property (strong, nonatomic)   NSString * email;
@property ReceiptEmailViewController * receiptVC;

- (void) authWithGoogleReturnedWithError: (NSError *)error;

@end

@implementation GoogleAuthenticator

// check if the user is already google auth'ed
- (BOOL)isGoogleAuthInKeychain
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
        NSLog(@"got google auth in keychain already for %@, auth expires on %@", self.googleAuth.userEmail, self.googleAuth.expirationDate);
        
        if ( ![self.email isEqualToString:self.googleAuth.userEmail]) {
            NSLog(@"auth is not for the user email provided");
            return NO;
        }
        
        return YES;
    }else {

        NSLog(@"don't have the google auth");
        return NO;
    }
}

- (NSError *)authenticateWithGoogle: (ReceiptEmailViewController *) receiptVC ForEmail:(NSString *)email
{
    NSError * error = Nil;
    
    self.email = email;
    self.receiptVC = receiptVC;
    
    if ( [self isGoogleAuthInKeychain]) {
        NSLog(@"in keychain, lets move to payments...");
    }
    
    //show user google sign-in view
    [self signInToGoogle];
    
    return error;
}

- (void)signInToGoogle
{
    NSLog(@"** %s ***", __func__);

    GTMOAuth2Authentication * googleAuth = [GTMOAuth2Authentication
                                            authenticationWithServiceProvider:kGTMOAuth2ServiceProviderGoogle
                                                                     tokenURL:[GTMOAuth2SignIn googleTokenURL]
                                                                  redirectURI:[GTMOAuth2SignIn nativeClientRedirectURI]
                                                                     clientID:CLIENT_ID
                                                                 clientSecret:CLIENT_SECRET];
    googleAuth.scope = @"openid email";
    
    
    // Prepare to display the authenticator view
    
    self.gtmVC = [[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:googleAuth
                                                             authorizationURL:[GTMOAuth2SignIn googleAuthorizationURL]
                                                             keychainItemName:kKeychainItemName
                                                                     delegate:self
                                                             finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    
    //present it modally
    [self.gtmVC setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self.receiptVC presentViewController:self.gtmVC animated:YES completion:nil];
}

- (void)viewController:(GTMOAuth2ViewControllerTouch * )viewController
      finishedWithAuth:(GTMOAuth2Authentication * )auth
                 error:(NSError * )error
{
    NSLog(@"** %s ***", __func__);
    self.googleAuth = auth;
    
    [viewController dismissViewControllerAnimated:YES
                                       completion:^{
                                        NSLog(@"finished google auth, error:%@, auth accessToken %@, refresh token %@",
                                              error, [auth accessToken], [auth refreshToken]);
                                        [self performSelectorOnMainThread:@selector(authWithGoogleReturnedWithError:)
                                                               withObject:error waitUntilDone:NO];
                                       }];
    
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
        NSString * stowawayPublicId = [[NSUserDefaults standardUserDefaults] objectForKey:kPublicId];
        NSLog(@"\n** %s %@: %@**\n", __PRETTY_FUNCTION__, kPublicId, stowawayPublicId);

        NSString *url = [NSString stringWithFormat:@"http://api.getstowaway.com/api/v1/users/%@", stowawayPublicId];
        
        NSString *userdata = [NSString stringWithFormat:@"{\"gmail_access_token\":\"%@\", \"gmail_refresh_token\":\"%@\"}",
                              self.googleAuth.accessToken, self.googleAuth.refreshToken];
        
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];
    }
    
    [self.googleAuthDelegate googleAuthenticatorResult: error];
    
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
}

@end
