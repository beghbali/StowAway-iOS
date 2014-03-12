//
//  MeetCrewViewController.h
//  StowAway
//
//  Created by Vin Pallen on 3/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MeetCrewViewController : UIViewController

//dictionary contains user_id, fb_id, picture, name, iscaptain
@property (strong, nonatomic) NSMutableArray * /*of NSDictionary*/ crew; //index 0 being self and upto 3

//my ID's - used for finalize ride and delete request
@property (strong, nonatomic) NSString *rideID;
@property (strong, nonatomic) NSString *userID;
@property (strong, nonatomic) NSString *requestID;

//pusher channel, suggested locations
@property (strong, nonatomic) NSDictionary *suggestedLocations;
@property (strong, nonatomic) NSString * locationChannel;

@end
