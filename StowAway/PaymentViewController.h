//
//  PaymentViewController.h
//  StowAway
//
//  Created by Vin Pallen on 2/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PaymentViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (weak, nonatomic) IBOutlet UITextField *cardNumberField;
@property (weak, nonatomic) IBOutlet UITextField *expiryField;
@property (weak, nonatomic) IBOutlet UITextField *cvvField;
@property (weak, nonatomic) IBOutlet UITextField *zipField;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rightBarButton;
@property BOOL isForMenu;
@end
