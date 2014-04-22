//
//  PageContentViewController.h
//  StowAway
//
//  Created by Vin Pallen on 4/12/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TutorialViewController.h"

@interface PageContentViewController : UIViewController

@property NSUInteger pageIndex;
@property NSString *imageFile;
@property TutorialViewController * tutVC;

@end
