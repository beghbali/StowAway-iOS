//
//  ViewController.m
//  StowAway
//
//  Created by Francis Fernandes on 1/20/14.
//  Copyright (c) 2014 Francis Fernandes. All rights reserved.
//

#import "ViewController.h"
#import <FacebookSDK/FacebookSDK.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet FBLoginView *loginView;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePictureView;
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    _loginView.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
// This method will be called when the user information has been fetched
- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView
                            user:(id<FBGraphUser>)user {
    self.profilePictureView.profileID = user.id;
    self.nameLabel.text = user.name;
}
@end
