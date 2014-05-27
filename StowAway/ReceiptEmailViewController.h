//
//  ReceiptEmailViewController.h
//  StowAway
//
//  Created by Vin Pallen on 2/10/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ReceiptEmailViewController : UIViewController



@property (weak, nonatomic) IBOutlet UITextField *emailTextField;

@property (weak, nonatomic) IBOutlet UILabel *changeUberEmailTextView;
@property (weak, nonatomic) IBOutlet UIButton *showMeHowButton;
@property (weak, nonatomic) IBOutlet UILabel *stowawayEmailFooterLabel;

@property (weak, nonatomic) IBOutlet UILabel *isUsingGmailLabel;
@property (weak, nonatomic) IBOutlet UIButton *isGmailYesButton;
@property (weak, nonatomic) IBOutlet UIButton *isGmailNoButton;

@property (weak, nonatomic) IBOutlet UIButton *finalActionButton;

@end

