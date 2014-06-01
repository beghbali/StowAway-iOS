//
//  FindingCrewViewController.h
//  StowAway
//
//  Created by Vin Pallen on 3/1/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FindingCrewViewController : UIViewController

@property (weak, nonatomic) NSDictionary * rideRequestResponse;

@property (strong, nonatomic) NSString *rideTypeLabel;
@property (strong, nonatomic) NSString *rideTimeLabel;
@property double rideCredits;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rideCreditsBarButton;

@property (strong, nonatomic) NSDate *rideDepartureDate;

@end
