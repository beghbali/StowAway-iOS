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

@end

@implementation PageContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.backgroundImageView.image = [UIImage imageNamed:self.imageFile];
}


@end
