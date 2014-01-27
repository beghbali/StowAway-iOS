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
    
    if (FBSession.activeSession.isOpen)
    {
        // move to next page
        [self performSegueWithIdentifier: @"FBLoginToReg" sender: self];
    } else {
        NSLog(@"not logged in");
    }

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

    NSString *url =@"http://ec2-54-214-145-124.us-west-2.compute.amazonaws.com/api/v1/users/";
    
    // Like the post request I showed you before, I'm going to send the deviceId again, because that is generally useful for establishing
    
    //UIDevice *device = [UIDevice currentDevice];
    NSString *id = user.id;
    NSString *first_name = user.first_name;
    NSString *last_name = user.last_name;
    
    NSString *post = [NSString stringWithFormat:@"uid=%@,provider=facebook", id];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    //[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody:postData];
    
    NSURLResponse *response;
    NSError *error;
    
    NSData *jsonData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSDictionary *results = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:&error] : nil;
    
    if (error) NSLog(@"[%@ %@] JSON error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error.localizedDescription);

    
    /*
    //Send Data to Endpoint to create user
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat:@"http://ec2-54-214-145-124.us-west-2.compute.amazonaws.com/api/v1/users/"]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSError *error;
    NSURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
 
curl -X POST -d '{ "provider":"facebook", "uid":123123, "user":{"first_name":"Joe", "last_name":"Bloggs", "image_url":"http://graph.facebook.com/12345678/picture?type=square", "token":"AF4234B3C", "expires_at":1321747205, "gender":"male", "location":"Palo Alto, California", "verified":true, "profile_url":"https://www.facebook.com/thebashir"}}' http://ec2-54-214-145-124.us-west-2.compute.amazonaws.com//api/v1/users -H "Content-Type:application/json"
     */
    
    
}
@end
