//
//  AppDelegate.m
//  StowAway
//
//  Created by Francis Fernandes on 1/20/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//


#import "AppDelegate.h"
#import <FacebookSDK/FacebookSDK.h>
#import "StowawayConstants.h"
#import "FindingCrewViewController.h"
#import "MeetCrewViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    NSLog(@"app launched with launch options %@", launchOptions);

    if (launchOptions != nil)
	{
		NSDictionary *dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
		if (dictionary != nil)
		{
			NSLog(@"Launched from push notification: %@", dictionary);
			[self processStowawayPushNotification:dictionary isAppRunning:NO];
		}
	}
    
    // Let the device know we want to receive push notifications
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    
    //facebook login
    [FBLoginView class];
    [FBProfilePictureView class];
    
    return YES;
}

- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo
{
	NSLog(@"Received notification: %@", userInfo);
    
    [self processStowawayPushNotification:userInfo isAppRunning:YES];
}

- (void)processStowawayPushNotification:(NSDictionary*)pushMsg isAppRunning:(BOOL)isAppRunning
{
    NSLog(@"isAppRunning %d, process push: %@", pushMsg, isAppRunning);
    
    //NSString *status = [pushMsg valueForKey:kStatus];
    NSString *ride_id = [pushMsg valueForKey:kRidePublicId];
    
    BOOL isRideFinalized = [[[NSUserDefaults standardUserDefaults] objectForKey:kIsRideFinalized] boolValue];

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];

    //we have a update while finding crew
    if ( !isRideFinalized )
    {
        //prepare find crew view to be launched
        NSLog(@" **** prepare find crew view to be launched **** ");
        
        FindingCrewViewController *findingCrewVC = (FindingCrewViewController *)[mainStoryboard
                                                                                 instantiateViewControllerWithIdentifier:@"FindingCrewViewController"];

        NSString * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];

        NSDictionary * fakeRideRequestResponse = @{kRidePublicId: ride_id, kUserPublicId: publicUserId};
        
        findingCrewVC.rideRequestResponse = fakeRideRequestResponse;
        [self.window.rootViewController presentViewController:findingCrewVC animated:YES completion:NULL];
        
    } else
    {
        //we have a update while crew is meeting
        NSLog(@"**** we have a update while crew is meeting ***");
        MeetCrewViewController *meetCrewVC = (MeetCrewViewController *)[mainStoryboard
                                                                        instantiateViewControllerWithIdentifier:@"MeetCrewViewController"];
        [self.window.rootViewController presentViewController:meetCrewVC animated:YES completion:NULL];


    }
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	NSLog(@"My token is: %@",deviceToken.description);
    // add it to nsuserdefaults, so we can send it along with FB login info

    if ( !deviceToken ) {
        NSLog(@"null token.. ERROR !!!");
        return;
    }
    
    NSString *newToken = [deviceToken description];
	newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
	newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSLog(@"parsed token %@", newToken);
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    //TODO: update the server with device token everytime
    if (standardDefaults)
    {
        [standardDefaults setObject:newToken forKey:kDeviceToken];
        [standardDefaults synchronize];
    }
    else
        NSLog(@"null standardUserDefaults ..ERROR !!");
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	NSLog(@"Failed to get token, error: %@", error);
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    //TODO: add code to check that notifcations are enabled otherwise prompt user to enable it
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    // Call FBAppCall's handleOpenURL:sourceApplication to handle Facebook app responses
    BOOL wasHandled = [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
        
    return wasHandled;
}
@end
