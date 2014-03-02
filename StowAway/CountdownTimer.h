//
//  CountdownTimer.h
//  StowAway
//
//  Created by Vin Pallen on 3/2/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol CountdownTimerDelegate <NSObject>

- (void)countdownTimerExpired;

@end


@interface CountdownTimer : NSObject

@property (weak, nonatomic) UILabel * countdownTimerLabel;

@property (nonatomic, weak) id<CountdownTimerDelegate> cdTimerDelegate;

-(void)initializeWithSecondsRemaining:(NSUInteger)seconds ForLabel:(UILabel *)label;


@end
