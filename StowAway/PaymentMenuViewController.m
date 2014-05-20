//
//  PaymentMenuViewController.m
//  StowAway
//
//  Created by Vin Pallen on 4/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "PaymentMenuViewController.h"
#import "SWRevealViewController.h"
#import "EnterPickupDropOffViewController.h"
#import "StowawayServerCommunicator.h"
@interface PaymentMenuViewController () <UITextFieldDelegate, StowawayServerCommunicatorDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *revealButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rightBarButton;

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (weak, nonatomic) IBOutlet UITextField *cardNumberField;
@property (weak, nonatomic) IBOutlet UITextField *expiryField;
@property (weak, nonatomic) IBOutlet UITextField *cvvField;
@property (weak, nonatomic) IBOutlet UITextField *zipField;

@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) IBOutlet UILabel *cardHeadingLabel;
@property (weak, nonatomic) IBOutlet UILabel *previousCardLabel;

@end

@implementation PaymentMenuViewController


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(void)setUpRevealMenuButton
{  //set up the reveal button
    [self.revealButtonItem setTarget: self.revealViewController];
    [self.revealButtonItem setAction: @selector( revealToggle: )];
    [self.navigationController.navigationBar addGestureRecognizer: self.revealViewController.panGestureRecognizer];
}

- (IBAction)skipButtonTapped:(id)sender
{
    NSLog(@"%s........EDIT.................. parent %@", __func__, self.parentViewController);

   // [self dismissViewControllerAnimated:YES completion:nil];
   // [self.navigationController pushViewController:self.parentViewController animated:YES];
    
   // [self.navigationController popViewControllerAnimated:YES];
//    [self.presentingViewController dismissViewControllerAnimated:YES completion:^(void){}];
    
    [self makeCardEditable:YES];
    [self.cardNumberField becomeFirstResponder];
}

-(void)makeCardEditable:(BOOL)editable
{
    self.nameField.hidden = !editable;
    self.cardNumberField.hidden = !editable;
    self.expiryField.hidden = !editable;
    self.cvvField.hidden = !editable;
    self.zipField.hidden = !editable;
    self.doneButton.hidden = !editable;
    self.editButtonItem.enabled = !editable;

}
-(void)checkPreviousCard
{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString * cardType = [standardDefaults objectForKey:@"cardType"];
    NSString * lastFour = [standardDefaults objectForKey:@"lastFour"];
    
    if (cardType && lastFour)
    {
        self.previousCardLabel.text = [NSString stringWithFormat:@"%@ xxxx-xxxx-xxxx-%@", cardType, lastFour];
        self.cardHeadingLabel.text = @"Edit to change the currently used card.";
        self.saveButton.enabled = NO;
    }
    else
    {
        self.cardHeadingLabel.text = @"Enter a credit card to be charged";
        self.previousCardLabel.text = @"Only for your share of ride.";
        [self skipButtonTapped:nil];
    }
}

- (void)viewDidLoad
{
    super.nameField = self.nameField;
    super.cardNumberField = self.cardNumberField;
    super.expiryField = self.expiryField;
    super.cvvField = self.cvvField;
    super.zipField = self.zipField;
    super.doneButton = self.doneButton;
    super.saveButton = self.saveButton;
    super.rightBarButton = self.rightBarButton;
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.cardNumberField resignFirstResponder];
    self.doneButton.hidden = YES;
    super.isForMenu = YES;
    [self setUpRevealMenuButton];

    [self checkPreviousCard];
}

-(void) viewWillAppear: (BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void) viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"%s........go back to DOCK now......................%@ ", __func__, self.parentViewController);
//    [self.parentViewController performSegueWithIdentifier:@"sw_front" sender:self.parentViewController];
    self.saveButton.enabled = NO;
    [self checkPreviousCard];
    [self makeCardEditable:NO];
}
@end
