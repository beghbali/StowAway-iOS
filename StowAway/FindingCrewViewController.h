//
//  FindingCrewViewController.h
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FindingCrewViewController : UIViewController

@property NSUInteger secondsToExpire; //need this for showing the countdown timer
@property NSUInteger rideRequestPublicId; // need this for deleting the ride request
@property NSUInteger crewFbId_1;
@property NSUInteger crewFbId_2;
@property NSUInteger crewFbId_3;

-(void) armUpCountdownTimer;

@end
