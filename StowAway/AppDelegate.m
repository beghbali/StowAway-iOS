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
#import "EnterPickupDropOffViewController.h"


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    NSLog(@"app launched with launch options %@", launchOptions);
/*
    //set bar color - #7ac7cf
    [UINavigationBar appearance].barTintColor = [UIColor colorWithRed:122.0/256.0 green:199.0/256.0 blue:207.0/256.0 alpha:1.0];
    //bar tint color - white
    [UINavigationBar appearance].tintColor = [UIColor whiteColor];
*/
    if (launchOptions != nil)
	{
		NSDictionary *dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
		if (dictionary != nil)
		{
			NSLog(@"Launched from remote push notification: %@", dictionary);
			[self processStowawayPushNotification:dictionary isAppRunning:NO];
		}
        
        NSDictionary *local_dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
		if (local_dictionary != nil)
		{
			NSLog(@"Launched from local push notification: %@", local_dictionary);
			[self processUILocalNotification:local_dictionary isAppRunning:NO];
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

#pragma mark remote notif

- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo
{
	NSLog(@"didReceiveRemoteNotification: %@ ..........", userInfo);
    
    [self processStowawayPushNotification:userInfo isAppRunning:YES];
}


- (void)processStowawayPushNotification:(NSDictionary*)pushMsg isAppRunning:(BOOL)isAppRunning
{
    NSLog(@"isAppRunning %d, processStowawayPushNotification........", isAppRunning);
    
    NSString * status = [pushMsg valueForKey:kStatus];
    NSNumber * ride_id = [pushMsg valueForKey:kPublicId];
    NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
    
    BOOL isRideFinalized = [[[NSUserDefaults standardUserDefaults] objectForKey:kIsRideFinalized] boolValue];

    NSLog(@"\n **** publicUserId %@, ride_id %@, status %@, isRideFinalized %d **** \n", publicUserId, ride_id, status, isRideFinalized);

    if (ride_id && (ride_id != (id)[NSNull null]))
        self.fakeRideRequestResponse =  @{kRidePublicId: ride_id, kUserPublicId: publicUserId};
    else
        self.fakeRideRequestResponse =  @{kUserPublicId: publicUserId};
    
    NSLog(@"fake ride req: %@", self.fakeRideRequestResponse);

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
/*
   NSLog(@"\n ******* TEST: myc_vc window %@\n fc_vc window %@ \n ***********",
         ((MeetCrewViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"MeetCrewViewController"]).view.window,
          ((FindingCrewViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"FindingCrewViewController"]).view.window);
*/
    //we have a update while finding crew - that means new crew joined or someone dropped out
    if ( !isRideFinalized )
    {
        //prepare find crew view to be launched
        NSLog(@" **** prepare find crew view to be launched **** ");
        
        if (isAppRunning)
        {
            //send notification to the FC vc
            NSLog(@" *** app was running so post a notification to FC_vc");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFindCrew"
                                                                object:self
                                                              userInfo:self.fakeRideRequestResponse];
        } else
        {
            /*
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"wasAppLaunchedDueToPush"];
            [[NSUserDefaults standardUserDefaults] synchronize];
*/
              //NSLog(@"self.window.rootViewController %@", self.window.rootViewController);
            
           // self.window.rootViewController = enterPickUpDropOffCrewVC;
           // [self.window.rootViewController presentViewController:enterPickUpDropOffCrewVC animated:NO completion:Nil];
            //[enterPickUpDropOffCrewVC presentViewController:findingCrewVC animated:YES completion:Nil];
            //[self.window.rootViewController addS  presentViewController:findingCrewVC animated:NO completion:Nil];
            UIViewController * rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
            NSLog(@"rootViewController %@", rootViewController);

            NSLog(@"app was not running, so build view hierarchy and go to FC view");
            EnterPickupDropOffViewController *enterPickUpDropOffCrewVC = (EnterPickupDropOffViewController *)[mainStoryboard
                                                                                                              instantiateViewControllerWithIdentifier:@"EnterPickupDropOffViewController"];
            NSLog(@"enterPickUpDropOffCrewVC %@", enterPickUpDropOffCrewVC);
            
            FindingCrewViewController *findingCrewVC = (FindingCrewViewController *)[mainStoryboard
                                                                                     instantiateViewControllerWithIdentifier:@"FindingCrewViewController"];
            
            NSLog(@"findingCrewVC %@", findingCrewVC);
            
            [rootViewController addChildViewController:enterPickUpDropOffCrewVC];
            NSLog(@"enterpickup vc added as childviewcontroller $$$");
          
            [rootViewController addChildViewController:findingCrewVC];
            NSLog(@"findingCrewVC vc added as childviewcontroller $$$");
#warning fix the view to be presented modally here....
//            [enterPickUpDropOffCrewVC presentViewController:findingCrewVC animated:NO completion:Nil];
        }
        return;
    }
    
    NSLog(@" **** prepare meet your crew view to be launched **** ");

    //notification after we have been on meet your crew
    
    if (isAppRunning)
    {
        //send notification to the meet your crew vc
        NSLog(@" *** updateMeetCrew");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateMeetCrew"
                                                            object:self
                                                          userInfo:pushMsg];
    } else
    {
        if (ride_id && (ride_id != (id)[NSNull null]))
        {
            NSLog(@"ride canceled");
            //captain canceled the ride, so cancel it for everyone, take them to FindingCrewViewController
            
            FindingCrewViewController *findingCrewVC = (FindingCrewViewController *)[mainStoryboard
                                                                                     instantiateViewControllerWithIdentifier:@"FindingCrewViewController"];
            
            NSLog(@"findingCrewVC %@", findingCrewVC);
            
            
            findingCrewVC.rideRequestResponse = self.fakeRideRequestResponse;
            NSLog(@"self.window.rootViewController %@", self.window.rootViewController);
            
            // self.window.rootViewController = enterPickUpDropOffCrewVC;
            // [self.window.rootViewController presentViewController:enterPickUpDropOffCrewVC animated:NO completion:Nil];
            //[enterPickUpDropOffCrewVC presentViewController:findingCrewVC animated:YES completion:Nil];
            [self.window.rootViewController presentViewController:findingCrewVC animated:NO completion:Nil];

        }
        //TODO:
        //we have a update while crew is meeting -- either a stowaway dropped or captain dropped(ride_id==nil)
        //need to fill the crew property before loading the VC - view did load calls initiatecrew and puts stuff on map
        MeetCrewViewController *meetCrewVC = (MeetCrewViewController *)[mainStoryboard
                                                                        instantiateViewControllerWithIdentifier:@"MeetCrewViewController"];
        
        NSLog(@"**** we have a update while crew is meeting %@ ***", meetCrewVC.view.window);

        [self.window.rootViewController presentViewController:meetCrewVC animated:YES completion:NULL];
    }

    

    
}

#pragma mark local notif

-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSLog(@"local notif: %@", notification);
    
    [self processUILocalNotification:notification.userInfo isAppRunning:YES];

}

- (void)processUILocalNotification:(NSDictionary*)pushMsg isAppRunning:(BOOL)isAppRunning
{
    NSLog(@"processUILocalNotification: %@, isAppRunning %d", pushMsg, isAppRunning);
}

#pragma mark device token apns

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
