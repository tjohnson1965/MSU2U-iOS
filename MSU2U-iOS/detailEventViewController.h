//
//  detailEventViewController.h
//  MSU2U-iOS
//
//  Created by Matthew Farmer on 11/12/12.
//  Copyright (c) 2012 Matthew Farmer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Event+Create.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "campusMapViewController.h"
#import "addEventToCalendar.h"

//ShareKit
#import "SHK.h"

@interface detailEventViewController : addEventToCalendar{
    Event * receivedEvent;
}

-(void)sendEventInformation:(Event*)eventInfo;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundPhoto;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIImageView *homePhoto;
@property (strong, nonatomic) IBOutlet UIImageView *awayPhoto;
@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *startingDateLabel;
- (IBAction)addToCalendar:(UIButton *)sender;
- (IBAction)showInMap:(UIButton *)sender;
- (IBAction)sharePressed:(UIBarButtonItem *)sender;
- (IBAction)viewInBrowser:(UIButton *)sender;

@end
