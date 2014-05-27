//
//  PaymentViewController.m
//  StowAway
//
//  Created by Vin Pallen on 2/11/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "EnterPickupDropOffViewController.h"

#import "PaymentViewController.h"
#import "Stripe.h"
#import "StowawayServerCommunicator.h"
#import "SWRevealViewController.h"

#define STRIPE_TEST_PUBLIC_KEY @"pk_test_RKqdkvUwBndT8tf7t65ft2TV"

@interface PaymentViewController() <UITextFieldDelegate, StowawayServerCommunicatorDelegate>

@property (strong, nonatomic) STPCard* stripeCard;

@end

@implementation PaymentViewController

NSString * __previousCardNumberTextFieldContent;
UITextRange * __previousCardNumberSelection;
NSString * __previousExpiryTextFieldContent;
UITextRange * __previousExpirySelection;
NSError * error = Nil;

char isReadyToSavePayment = 0;
BOOL __isAmex = NO;

#pragma mark - view initialization

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.doneButton.hidden = YES;
    
    [self.cardNumberField addTarget: self action:@selector(reformatAsCardNumber:)
                   forControlEvents:UIControlEventEditingChanged];
    
    [self.expiryField addTarget: self action:@selector(reformatAsExpiryDate:)
               forControlEvents:UIControlEventEditingChanged];
    
    self.stripeCard = [[STPCard alloc] init];
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

    NSString * firstName = [standardDefaults objectForKey:kFirstName];
    NSString * lastName = [standardDefaults objectForKey:kLastName];

    //prefil fb name
    self.nameField.text = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    [self textFieldDidEndEditing:self.nameField];
    NSLog(@"%s..........................self.isForMenu %d", __func__,self.isForMenu);

    if (!self.isForMenu)
        [self.cardNumberField becomeFirstResponder];
}


-(void) viewWillAppear: (BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(keyboardWillShow:)
               name:UIKeyboardWillShowNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(keyboardWillHide:)
               name:UIKeyboardWillHideNotification
             object:nil];
}

- (void) viewWillDisappear: (BOOL)animated{
    
    [super viewWillDisappear:animated];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:UIKeyboardWillShowNotification
                object:nil];
    [nc removeObserver:self
                  name:UIKeyboardWillHideNotification
                object:nil];
}

#pragma mark - button actions

- (IBAction)skipButtonTapped:(id)sender
{
    UIViewController * presentingVC = self.presentingViewController;
    
    NSLog(@"presenting vc %@ ", presentingVC);
    
    while ( [presentingVC class] != [SWRevealViewController class] )
    {
        presentingVC = presentingVC.presentingViewController;
        NSLog(@"next presenting vc %@", presentingVC);
    }
    NSLog(@" ======= return home =====");
    [EnterPickupDropOffViewController setOnBoardingStatusChecked:YES];
    [presentingVC dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)doneButtonTapped:(UIButton *)sender
{
    NSLog(@"%s.......................isForMenu %d...", __func__, self.isForMenu);
    
    //hide keyboard
    [self.view endEditing:YES];
}


#pragma mark - textfield manipulation
/*
 Removes non-digits from the string, decrementing `cursorPosition` as
 appropriate so that, for instance, if we pass in `@"1111 1123 1111"`
 and a cursor position of `8`, the cursor position will be changed to
 `7` (keeping it between the '2' and the '3' after the spaces are removed).
 */
- (NSString *)removeNonDigits:(NSString *)string
    andPreserveCursorPosition:(NSUInteger *)cursorPosition
{
    NSUInteger originalCursorPosition = *cursorPosition;
    NSMutableString *digitsOnlyString = [NSMutableString new];
    
    for ( NSUInteger i = 0; i < string.length; i++ )
    {
        unichar characterToAdd = [string characterAtIndex:i];
        
        if ( isdigit(characterToAdd) )
        {
            NSString *stringToAdd = [NSString stringWithCharacters:&characterToAdd length:1];
            
            [digitsOnlyString appendString:stringToAdd];
        }
        else if ( i < originalCursorPosition )
                (*cursorPosition)--;
    }
    
    return digitsOnlyString;
}


/*
 Insert any string after periodic # of chars, and preserve the cursor position.
 
 can be used for credit card, example of how it works::
 Inserts spaces into the string to format it as a credit card number,
 incrementing `cursorPosition` as appropriate so that, for instance, if we
 pass in `@"111111231111"` and a cursor position of `7`, the cursor position
 will be changed to `8` (keeping it between the '2' and the '3' after the
 spaces are added).
 */
- (NSString *)insert: (NSString *)insertionString afterEvery: (NSUInteger)charCount
          intoString:(NSString *)string andPreserveCursorPosition:(NSUInteger *)cursorPosition
{
    NSMutableString *stringWithAddedInsertionString = [NSMutableString new];
    NSUInteger cursorPositionInUntouchedString = *cursorPosition;
    
    for ( NSUInteger i = 0; i < string.length; i++)
    {
        if ( (i > 0) && ( (i % charCount) == 0 ) )
        {
            [stringWithAddedInsertionString appendString: insertionString];
            
            if ( i < cursorPositionInUntouchedString )
                (*cursorPosition)++;
            
        }
        
        unichar characterToAdd = [string characterAtIndex:i];
        
        NSString *stringToAdd = [NSString stringWithCharacters:&characterToAdd length:1];
        
        [stringWithAddedInsertionString appendString:stringToAdd];
    }
    
    return stringWithAddedInsertionString;
}


-(void)reformatAsCardNumber:(UITextField *)textField
{
    // In order to make the cursor end up positioned correctly, we need to
    // explicitly reposition it after we inject spaces into the text.
    // targetCursorPosition keeps track of where the cursor needs to end up as
    // we modify the string, and at the end we set the cursor position to it.
    NSUInteger targetCursorPosition = [textField offsetFromPosition:textField.beginningOfDocument
                                                         toPosition:textField.selectedTextRange.start];
    
    NSString *cardNumberWithoutSpaces = [self removeNonDigits:textField.text
                                    andPreserveCursorPosition:&targetCursorPosition];
    
    __isAmex = [self isAmexCard:cardNumberWithoutSpaces];
    
    NSUInteger maxCardDigits = 16;
    NSUInteger spaceAfterDigitsCount = 4;

    if (__isAmex)
    {
        maxCardDigits = 15;
       // spaceAfterDigitsCount = cardNumberWithoutSpaces.length > 5 ? 5: 4;
    }
    
    
    if ( cardNumberWithoutSpaces.length > maxCardDigits )
    {
        // If the user is trying to enter more than 16 digits, we prevent
        // their change, leaving the text field in its previous state
        textField.text = __previousCardNumberTextFieldContent;
        textField.selectedTextRange = __previousCardNumberSelection;
       
        [self.expiryField becomeFirstResponder];
        
        return;
    }
    
    textField.text = [self insert:@" " afterEvery:spaceAfterDigitsCount intoString:cardNumberWithoutSpaces
                        andPreserveCursorPosition:&targetCursorPosition];
    
    UITextPosition *targetPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:targetCursorPosition];
    
    [textField setSelectedTextRange: [textField textRangeFromPosition:targetPosition toPosition:targetPosition]];
}

-(void)reformatAsExpiryDate:(UITextField *)textField
{
    // In order to make the cursor end up positioned correctly, we need to
    // explicitly reposition it after we inject spaces into the text.
    // targetCursorPosition keeps track of where the cursor needs to end up as
    // we modify the string, and at the end we set the cursor position to it.
    
    NSUInteger targetCursorPosition = [textField offsetFromPosition:textField.beginningOfDocument
                                                         toPosition:textField.selectedTextRange.start];
    
    NSString *expiryDateWithoutSlash = [self removeNonDigits:textField.text
                                    andPreserveCursorPosition:&targetCursorPosition];
    
    if ( expiryDateWithoutSlash.length > 4 )
    {
        textField.text = __previousExpiryTextFieldContent;
        
        textField.selectedTextRange = __previousExpirySelection;
        
        [self.cvvField becomeFirstResponder];
        
        return;
    }
    
    textField.text = [self insert:@"/" afterEvery:2 intoString:expiryDateWithoutSlash
        andPreserveCursorPosition:&targetCursorPosition];
    
    UITextPosition *targetPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:targetCursorPosition];
    
    [textField setSelectedTextRange: [textField textRangeFromPosition:targetPosition toPosition:targetPosition]
     ];
}

- (BOOL) isAmexCard:(NSString *) cardNumber
{
    if ([cardNumber hasPrefix:@"34"] || [cardNumber hasPrefix:@"37"])
        return YES;
    
    return NO;
}

- (BOOL) isExpiryDateFieldValid:(NSString *)expiryTextField andExtractMonth:(NSInteger *) month andYear:(NSInteger *) year
{
    NSArray *strings = [expiryTextField componentsSeparatedByString: @"/"];
    
    if (strings.count < 2)
        return NO;
    
    *month = [(NSString *)[strings objectAtIndex:0] integerValue];
    
    *year = 2000 + [(NSString *)[strings objectAtIndex:1] integerValue];

    
    if ( *month > 12 || *month < 1 ) {
        return NO;
    }
    
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit) fromDate:date];
    NSInteger curMonth = [components month];
    NSInteger curYear = [components year];
    
    NSLog(@"cur %ld %ld, %ld %ld", (long)curMonth, (long)curYear, (long)*month, (long)*year);
    
    if ( *year < curYear ) {
        return NO;
    }
    
    if ( (*year == curYear) && (*month < curMonth) ) {
        return NO;
    }
    
    return YES;
}

#pragma mark - textfield delegates
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger newLength = [textField.text length] + [string length] - range.length;

    switch (textField.tag) {
         
        //CARD NUMBER
        case 2:
            // Note textField's current state before performing the change, in case
            // reformatTextField wants to revert it
            __previousCardNumberTextFieldContent = textField.text;
            __previousCardNumberSelection = textField.selectedTextRange;

            break;
            
        //EXPIRY
        case 3:
            // Note textField's current state before performing the change, in case
            // reformatTextField wants to revert it
            __previousExpiryTextFieldContent = textField.text;
            __previousExpirySelection = textField.selectedTextRange;

            break;
        
        //CVC
        case 4:
            if ( ((newLength > 3) && ![self isAmexCard:self.stripeCard.number]) || (newLength > 4) )
            {
                NSLog(@"its cvc");

                [self.zipField becomeFirstResponder];
                return NO;
            }
            
            break;
            
        //ZIP
        case 5:
            if ( newLength > 5 )
            {
                NSLog(@"its zip");

                self.stripeCard.addressZip = textField.text;
                [self.zipField resignFirstResponder];
                return NO;
            }
            
            break;
            
        default:
            break;
    }

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    BOOL isTextFieldValueValid = YES;
    NSInteger month = 0;
    NSInteger year = 0;
    NSUInteger fakeCursor = 0;

    switch (textField.tag)
    {
            //NAME
        case 1:
            if ( textField.text.length )
            {
                isReadyToSavePayment = isReadyToSavePayment | (1 << 0);
                self.stripeCard.name = textField.text;
            }
            else
            {
                isTextFieldValueValid = NO;
                isReadyToSavePayment = isReadyToSavePayment & ~(1 << 0);
            }
            break;
            
            //CARD NUMBER
        case 2:
            if ( textField.text.length < (__isAmex? 18: 19) )
            {
                isReadyToSavePayment = isReadyToSavePayment & ~(1 << 1);
                isTextFieldValueValid = NO;
            }
            else
            {
                self.stripeCard.number = [self removeNonDigits:textField.text
                                            andPreserveCursorPosition:&fakeCursor];
                isReadyToSavePayment = isReadyToSavePayment | (1 << 1);
            }
            break;
            
            //EXPIRY
        case 3:
            if ( textField.text.length && [self isExpiryDateFieldValid:textField.text andExtractMonth:&month andYear:&year] )
            {
                isReadyToSavePayment = isReadyToSavePayment | (1 << 2);
                self.stripeCard.expMonth = month;
                self.stripeCard.expYear = year;
            }
            else
            {
                isReadyToSavePayment = isReadyToSavePayment & ~(1 << 2);
                isTextFieldValueValid = NO;
            }
            break;
            
            //CVC
        case 4:
            if ( ((textField.text.length < 4) && [self isAmexCard:self.stripeCard.number]) || (textField.text.length < 3) )
            {
                isTextFieldValueValid = NO;
                isReadyToSavePayment = isReadyToSavePayment & ~(1 << 3);
            }
            else
            {
                self.stripeCard.cvc = textField.text;
                isReadyToSavePayment = isReadyToSavePayment | (1 << 3);
            }
            break;
            
            //ZIP
        case 5:
            if ( textField.text.length < 5 )
            {
                isTextFieldValueValid = NO;
                isReadyToSavePayment = isReadyToSavePayment & ~(1 << 4);
            }
            else
            {
                self.stripeCard.addressZip = textField.text;
                isReadyToSavePayment = isReadyToSavePayment | (1 << 4);
            }
            break;
            
        default:
            break;
    }
    
    textField.layer.borderWidth = 1.0f;

    if ( isTextFieldValueValid )
    {
        textField.layer.borderColor = [[UIColor greenColor] CGColor];
        isTextFieldValueValid++;
    }
    else
    {
        textField.layer.borderColor = [[UIColor redColor] CGColor];
        isTextFieldValueValid ? isTextFieldValueValid-- : isTextFieldValueValid;
    }
    
    if ( isReadyToSavePayment == (1<<5)-1 )
        self.saveButton.enabled = YES;
    else
        self.saveButton.enabled = NO;
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ( textField.tag == 1 )
    {
        self.stripeCard.name = textField.text;
        [self.nameField resignFirstResponder];
        [self.cardNumberField becomeFirstResponder];
    }
    return YES;
}

#pragma mark - keyboard manipulation
-(void)keyboardWillShow:(NSNotification *)aNotification
{
    self.doneButton.hidden = NO;
}


-(void)keyboardWillHide:(NSNotification *)aNotification
{
    self.doneButton.hidden = YES;
    
}

#pragma mark - stripe
- (void)handleError:(NSError *)error
{
    self.saveButton.enabled = YES;

    NSLog(@"Received error %@", error);

    UIAlertView *message = [[UIAlertView alloc] initWithTitle: @"Oops.."
                                                      message:[error localizedDescription]
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                            otherButtonTitles:nil];
    [message show];
}

- (void)handleToken:(STPToken *)token
{
    NSLog(@"Received token %@", token.tokenId);
    
    self.saveButton.enabled = NO;
    
    NSNumber * publicUserId = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPublicId];
    
    NSString *url = [NSString stringWithFormat:@"%@%@", [[Environment ENV] lookup:@"kStowawayServerApiUrl_users"], publicUserId];
    
    NSString *userdata = [NSString stringWithFormat:@"{\"stripe_token\":\"%@\"}", token.tokenId];
    
    StowawayServerCommunicator * sscommunicator = [[StowawayServerCommunicator alloc]init];
    sscommunicator.sscDelegate = self;
    [sscommunicator sendServerRequest:userdata ForURL:url usingHTTPMethod:@"PUT"];
    
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey:kOnboardingStatusPaymentDone];
    [[NSUserDefaults standardUserDefaults] synchronize];

}

- (IBAction)saveButtonTapped:(UIButton *)sender
{
    self.saveButton.enabled = NO;
    
    NSString * cardType = [self.stripeCard type];
    NSString * lastFour = [self.stripeCard.number substringFromIndex:12];
    
    NSLog(@"CARD:: %@, %@, %lu %lu, %@, %@, %@, %@", self.stripeCard.name, self.stripeCard.number, (unsigned long)self.stripeCard.expMonth, (unsigned long)self.stripeCard.expYear, self.stripeCard.cvc, self.stripeCard.addressZip, cardType, lastFour);
 
    [Stripe createTokenWithCard:self.stripeCard
                 publishableKey: [[Environment ENV] lookup:@"kStripePublicKey"]
                     completion:^(STPToken *token, NSError *error) {
                         if (error) {
                             [self handleError:error];
                         } else {
                             [self handleToken:token]; // Hooray!
                         }
                     }];
    
    //write credit card data to userdefaults to be used during menu edit
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject: cardType forKey:@"cardType"];
    [standardDefaults setObject: lastFour forKey:@"lastFour"];
    [standardDefaults synchronize];
}



- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)sError;
{
    NSLog(@"\n-- %@ -- %@ -- \n", data, sError);
    
//TODO: if it failed send credit card info again
    [self performSegueWithIdentifier: @"go to terms" sender: self];

}



@end
