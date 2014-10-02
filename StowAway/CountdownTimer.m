//
//  CountdownTimer.m
//  StowAway
//
//  Created by Vin Pallen on 3/2/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "CountdownTimer.h"

@interface CountdownTimer ()

@property   NSTimer *           countDownTimer;
@property   NSCalendar *        gregorianCalendar;
@property   NSDateFormatter *   countDownDateFormatter;

@end


@implementation CountdownTimer

-(void) initializeWithSecondsRemaining:(NSUInteger)seconds ForLabel:(UILabel *)label
{
#ifdef DEBUG
    NSLog(@"init CountdownTimer:: %@, %lusecs", label.text, (unsigned long)seconds);
#endif
    self.countdownTimerLabel = label;
    self.countDownEndDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    
    self.gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    self.countDownDateFormatter = [[NSDateFormatter alloc] init];
    [self.countDownDateFormatter setDateFormat:@"mm:ss"];

    self.countDownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateClock:) userInfo:nil repeats:YES];
    
    [self.countDownTimer fire];
}


-(void)updateClock:(NSTimer *)timer
{
    NSDate *now = [NSDate date];
    NSString *strTimeRemaining = nil;
    
    NSDateComponents *comp = [self.gregorianCalendar components:NSMinuteCalendarUnit|NSSecondCalendarUnit
                                                  fromDate:now
                                                    toDate:self.countDownEndDate
                                                   options:0];
    
    
    // if date have not expired
    if([now compare:self.countDownEndDate] == NSOrderedAscending)
    {
        strTimeRemaining = [[NSString alloc] initWithFormat:@"%02ld:%02ld", (long)[comp minute], (long)[comp second]];
        self.countdownTimerLabel.text = strTimeRemaining;

    }
    else
    {
        NSLog(@"-- %s : expired--", __func__);

        // time has expired, set time to 00:00 and call delegate function
        self.countdownTimerLabel.text = @"00:00";

        [self.countDownTimer invalidate];
        
        [self.cdTimerDelegate countdownTimerExpired];
    }
}


@end
