//
//  ProfileMenuViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "ProfileMenuViewController.h"
#import "SWRevealViewController.h"
#import <FacebookSDK/FacebookSDK.h>

@interface ProfileMenuViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *revealButtonItem;
@property (strong, nonatomic) IBOutlet UIImageView *fbProfileImageView;
@property (strong, nonatomic) IBOutlet UILabel *userFullName;
@end

@implementation ProfileMenuViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)setUpRevealMenuButton
{  //set up the reveal button
    [self.revealButtonItem setTarget: self.revealViewController];
    [self.revealButtonItem setAction: @selector( revealToggle: )];
    [self.navigationController.navigationBar addGestureRecognizer: self.revealViewController.panGestureRecognizer];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setUpRevealMenuButton];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *userImageURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=normal", [defaults objectForKey:@"fbProfileId"]];
    self.fbProfileImageView.image =  [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:userImageURL]]];
    self.userFullName.text = [defaults objectForKey:@"fullName"];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


@end
