//
//  ViewController.h
//  StowAway
//
//  Created by Francis Fernandes on 1/20/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>

@interface LoginViewController : UIViewController <FBLoginViewDelegate> {

    NSMutableData *_responseData;

}

@property (nonatomic)  BOOL facebookLoginStatus;

@property (nonatomic, strong) FBSession *session;

+(BOOL)isFBLoggedIn;

@end