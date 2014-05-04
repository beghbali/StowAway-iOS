//
//  MeetCrewViewController.h
//  StowAway
//
//  Created by Vin Pallen on 3/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MeetCrewViewController : UIViewController

//TODO: create crew member class

//dictionary contains user_id, fb_id, picture, name, iscaptain
@property (strong, nonatomic) NSMutableArray * /*of NSMutableDictionary*/ crew; //index 0 being self and upto 3

//my ID's - used for finalize ride and delete request
@property (strong, nonatomic) NSNumber *rideID;
@property (strong, nonatomic) NSNumber *userID;
@property (strong, nonatomic) NSNumber *requestID;

//pusher channel, suggested locations
@property (strong, nonatomic) NSDictionary *suggestedLocations;
@property (strong, nonatomic) NSString * locationChannel;

@property (strong, nonatomic) NSString *rideTypeLabel;
@property (strong, nonatomic) NSString *rideTimeLabel;


@end
