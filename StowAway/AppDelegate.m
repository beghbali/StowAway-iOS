//
//  AppDelegate.m
//  StowAway
//
//  Created by Francis Fernandes on 1/20/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//


#import "AppDelegate.h"
#import <FacebookSDK/FacebookSDK.h>
#import "FindingCrewViewController.h"
#import "MeetCrewViewController.h"
#import "EnterPickupDropOffViewController.h"
#import "StowawayServerCommunicator.h"
#import <Crashlytics/Crashlytics.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if ([[Environment ENV] lookup:@"kCrashlyticsAPIKey"] != nil)
    {
        [Crashlytics startWithAPIKey:[[Environment ENV] lookup:@"kCrashlyticsAPIKey"]];
        NSLog(@"Crashlytics Enabled");
    }
    
    NSString *environment = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Environment"];

    NSLog(@"app launched in %@ environment with launch options %@", environment, launchOptions);

#warning ios 8 remote notifications broken
    //TODO: fix this for ios 8
    // Let the device know we want to receive push notifications
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
                                            (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    
    //facebook login
    [FBLoginView class];
    [FBProfilePictureView class];
    
    return YES;
}

#pragma mark - remote push notifications

- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo
{
	NSLog(@"\n didReceiveRemoteNotification: %@ \n", userInfo);
    
    NSArray * allKeys = [userInfo allKeys];
    if (!allKeys || !(allKeys.count) )
    {
        NSLog(@"%s: empty push.......... ignoring \n", __func__);
        return;
    }
    
    /*
     ride id valid:
                    someone joined the ride
                    someone dropped but there are more riders
                    ride got initiated/checkedin/missed
     
     ride id null:
                    someone dropped, ride got canceled
     */
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"rideUpdateFromServer"
                                                        object:self
                                                      userInfo:userInfo];
    
    /*
     "finding crew" will get this if not on "meet crew" view and then poll the server
     
     otherwise
     
     "meet crew" will get latest ride object or go back home if ride is canceled
     */
}

#pragma mark - local notif

-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSLog(@"%s: %@", __func__, notification);
    
    //crew matching timed out -- failed to find ::generate notif which finding crew will respond to by deleting the request
    [[NSNotificationCenter defaultCenter] postNotificationName:@"crewFindingTimedOut"
                                                        object:self
                                                      userInfo:nil];
}

#pragma mark device token apns

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    if ( !deviceToken ) {
        NSLog(@"null token.. ERROR !!!");
        return;
    }
    
    NSString *newToken = [deviceToken description];
	newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
	newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSLog(@"parsed token %@", newToken);
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardDefaults)
    {
        [standardDefaults setObject:newToken forKey:kDeviceToken];
        [standardDefaults synchronize];
        
        //if user id exists, update its device token
        NSString * userId = [standardDefaults objectForKey:kUserPublicId];
        if (userId)
        {
            NSString *userdata = [NSString stringWithFormat:@"{\"%@\":\"%@\"}",kDeviceToken, newToken];
            NSString *url = [NSString stringWithFormat:@"%@%@",[[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], userId];
            
            StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
            sscommunicator.sscDelegate = nil;//dont need the cb
            [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];
        }
    }
    else
        NSLog(@"null standardUserDefaults ..ERROR !!");
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	NSLog(@"Failed to get token, error: %@", error);
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    // Call FBAppCall's handleOpenURL:sourceApplication to handle Facebook app responses
    BOOL wasHandled = [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
        
    return wasHandled;
}
@end
