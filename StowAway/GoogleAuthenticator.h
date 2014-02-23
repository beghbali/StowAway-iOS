//
//  GoogleAuthenticator.h
//  StowAway
//
//  Created by Vin Pallen on 2/19/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReceiptEmailViewController.h"

@protocol GoogleAuthenticatorDelegate <NSObject>

- (void)googleAuthenticatorResult: (NSError *)error;

@end

@interface GoogleAuthenticator : NSObject

@property (strong, nonatomic)   NSString * email;
@property (strong, nonatomic)   NSString * emailProvider;

@property (nonatomic, weak) id<GoogleAuthenticatorDelegate> googleAuthDelegate;

- (NSError *)authenticateWithGoogle: (ReceiptEmailViewController *) receiptVC ForEmail:(NSString *)email;

@end
