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
#include "Environment.h"

#define CLIENT_ID       @"91236755086-hnkvlu1h2ltagv3cjtkj37ohp2h51r90.apps.googleusercontent.com"
#define CLIENT_SECRET   @"W7e1b6OQaJjWuTF-m5oDyDEQ"

static NSString *const kKeychainItemName = @"OAuth StowAway: Google";

@interface GoogleAuthenticator() <StowawayServerCommunicatorDelegate>

@property (strong, nonatomic)   GTMOAuth2Authentication * googleAuth;
@property (strong, nonatomic)   GTMOAuth2ViewControllerTouch * gtmVC;
@property ReceiptEmailViewController * receiptVC;

- (void) authWithGoogleReturnedWithError: (NSError *)error;

@end

@implementation GoogleAuthenticator

// check if the user is already google auth'ed
- (BOOL)isGoogleAuthInKeychain
{
    return NO; //TODO: remove this hack
    
    // Check for authorization saved in keychain
    GTMOAuth2Authentication *authFromKeychain =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                          clientID:CLIENT_ID
                                                      clientSecret:CLIENT_SECRET];
    if ([authFromKeychain canAuthorize])
    {
        self.googleAuth = authFromKeychain;
#ifdef DEBUG
        NSLog(@"authFromKeychain%@ got google auth in keychain already for %@, auth expires on %@",authFromKeychain, self.googleAuth.userEmail, self.googleAuth.expirationDate);
#endif
//TODO: revisit this check , it should never happen
        if ( ![self.email isEqualToString:self.googleAuth.userEmail] )
        {
            NSLog(@"auth is not for the user email provided");
            return NO;
        }
        
        return YES;
    }else
    {
        NSLog(@"don't have the google auth");
        return NO;
    }
}


- (void)authControllerWebViewStoppedLoading:(NSNotification *)notification
{
    // Assume emailAddress is a property that holds the email address you
    // you want to pre-populate the Email entity with....
    
    NSString *javascript = [NSString stringWithFormat:
                            @"var elem = document.getElementById(\"Email\");"
                            @"elem.value = \"%@\";", self.email];
    
#ifdef DEBUG
    NSLog(@"%s: prefil email add %@", __func__, self.email);
#endif
    [self.gtmVC.webView
     stringByEvaluatingJavaScriptFromString:javascript];
}

- (NSError *)authenticateWithGoogle: (ReceiptEmailViewController *) receiptVC ForEmail:(NSString *)email
{

    NSError * error = Nil;
    
    self.email = email;
    self.receiptVC = receiptVC;
   
    //for some javascript magic, to autofill email address
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authControllerWebViewStoppedLoading:)
                                                 name:kGTMOAuth2WebViewStoppedLoading
                                               object:nil];

    if ( [self isGoogleAuthInKeychain]) {
        NSLog(@"in keychain, lets move to payments...");

        //return without showing signin view and send the data to server
        [self authWithGoogleReturnedWithError:nil];
        return error;
    }
    
    //show user google sign-in view
    [self signInToGoogle];
    
    return error;
}

- (void)signInToGoogle
{

    GTMOAuth2Authentication * googleAuth = [GTMOAuth2Authentication
                                            authenticationWithServiceProvider:kGTMOAuth2ServiceProviderGoogle
                                                                     tokenURL:[GTMOAuth2SignIn googleTokenURL]
                                                                  redirectURI:[GTMOAuth2SignIn nativeClientRedirectURI]
                                                                     clientID:CLIENT_ID
                                                                 clientSecret:CLIENT_SECRET];
    googleAuth.scope = @"https://mail.google.com/";
    
    
    // Prepare to display the authenticator view
    
//TODO: to make it pretty auth can be initiated by sotwaway server, app gives email and password to the server and server talks to google
//https://developers.google.com/accounts/docs/OAuth2ServiceAccount
    
    self.gtmVC = [[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:googleAuth
                                                             authorizationURL:[GTMOAuth2SignIn googleAuthorizationURL]
                                                             keychainItemName:kKeychainItemName
                                                                     delegate:self
                                                             finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    //prefill email field
#ifdef DEBUG
    NSLog(@"%s: prefill email field with <%@>", __func__, self.email);
#endif
    GTMOAuth2SignIn *signIn = self.gtmVC.signIn;
    signIn.additionalAuthorizationParameters = @{@"login_hint" :self.email};

    //present it modally
    [self.gtmVC setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self.receiptVC presentViewController:self.gtmVC animated:YES completion:nil];
}

- (void)viewController:(GTMOAuth2ViewControllerTouch * )viewController
      finishedWithAuth:(GTMOAuth2Authentication * )auth
                 error:(NSError * )error
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kGTMOAuth2WebViewStoppedLoading
                                                  object:nil];
    

    self.googleAuth = auth;
    
    [viewController dismissViewControllerAnimated:YES
                                       completion:^{
#ifdef DEBUG
                                        NSLog(@"finished google auth, error:%@, auth accessToken %@, refresh token %@, user email %@ ",
                                              error, [auth accessToken], [auth refreshToken], auth.userEmail);
#endif
                                        [self performSelectorOnMainThread:@selector(authWithGoogleReturnedWithError:)
                                                               withObject:error waitUntilDone:NO];
                                       }];
    
}

- (void) authWithGoogleReturnedWithError: (NSError *)error
{
    //do all the UI stuff on the main thread
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
        NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];

        NSString *url = [NSString stringWithFormat:@"%@%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], publicUserId];
        
        NSString *userdata = [NSString stringWithFormat:@"{\"%@\":\"%@\", \"%@\":\"%@\", \"%@\":\"%@\", \"%@\":\"%@\", \"%@\":\"%@\"}",
                              kUserEmail, self.googleAuth.userEmail, kUserEmailProvider, @"gmail",
                              kGmailAccessToken, self.googleAuth.accessToken, kGmailRefreshToken, self.googleAuth.refreshToken, kGmailAccessTokenExpiration, self.googleAuth.expirationDate];
        
        
        StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
        sscommunicator.sscDelegate = self;
        [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];
        
        [[NSUserDefaults standardUserDefaults] setObject: self.googleAuth.userEmail forKey:@"linkedReceiptEmail"];
        
        [self.googleAuthDelegate googleAuthenticatorResult: error];

    }
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
#ifdef DEBUG
    NSLog(@"%s: -- %@ -- %@ --", __func__, data, sError);
#endif
}

@end
