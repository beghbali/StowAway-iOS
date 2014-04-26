//
//  PageContentViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/12/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "PageContentViewController.h"

@interface PageContentViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (weak, nonatomic) IBOutlet UIButton *letsRideButton;

@end

@implementation PageContentViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
    
    if (self.pageIndex == 3)
        self.letsRideButton.hidden = NO;
    else
        self.letsRideButton.hidden = YES;
}

- (IBAction)gotItButtonTapped:(UIButton *)sender
{
    [self.tutVC endTutorial];
}

@end
