//
//  DungeonsViewController.m
//  TbBLTBasicSample
//
//  Created by Ueda on 2016/03/02.
//  Copyright © 2016年 3bitter Inc. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "AppDelegate.h"
#import "DungeonsViewController.h"
#import "ContentManager.h"
#import "OurContent.h"
#import "ContentManager.h"
#import "DungeonsViewController.h"
#import "TbBTManager.h"

extern NSString *kBeaconUseKey;

extern NSString *kBeaconRangingFailed;
extern NSString *kBeaconDidNotDetectedInRegion;
extern NSString *kBeaconMappedContentsPrepared;


@interface DungeonsViewController ()

@property (strong, nonatomic) CLLocationManager *shallowCopyOfLocManager;
@property (strong, nonatomic) TbBTManager *shallowCopyOfBtManager;

@property (strong, nonatomic) UIActivityIndicatorView *indicator;
@property (strong, nonatomic) NSTimer *timeoutTimer;

@property (strong, nonatomic) NSMutableArray *fullContents;
@property (assign, nonatomic) BOOL bltUsed;
@property (assign, nonatomic) BOOL noMapped;

@end

@implementation DungeonsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _fullContents = [NSMutableArray arrayWithArray:[[ContentManager sharedManager] defaultContents]];
    _noMapped = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    _bltUsed = [[userDefaults valueForKey:kBeaconUseKey] boolValue];
    if (_bltUsed) {
        [self startSearch];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_bltUsed && _indicator) {
        [_indicator startAnimating];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _fullContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContentTitleCell" forIndexPath:indexPath];
    OurContent *content = [_fullContents objectAtIndex:indexPath.row];
    cell.textLabel.text = content.title;
    cell.detailTextLabel.text = content.contentDescription;
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)startSearch {
    // Add timer cancel notification (for not ranged case)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelTimeoutTimer)name:@"RangingStarted" object:nil];
    // Add timeout after ranging notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminateSearch) name:@"RangingTimeOver" object:nil];
    
    // Observers for failure cases
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminateSearch) name:kBeaconRangingFailed object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminateSearch) name:kBeaconDidNotDetectedInRegion object:nil];
    
    // Observers for success case
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshWithMappedContents) name:kBeaconMappedContentsPrepared object:nil];
    
    
    
    // Add timeout timer
    _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:20 target:self selector:@selector(terminateSearch) userInfo:nil repeats:NO];
    _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    _indicator.frame = CGRectMake(0.0, 0.0, 50.0, 50.0);
    _indicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _indicator.opaque = NO;
    _indicator.backgroundColor = [UIColor blackColor];
    _indicator.color = [UIColor whiteColor];
    _indicator.center = self.view.center;
    [self.view addSubview:_indicator];
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSArray *tbBeaconRegions = [appDelegate.btManager initialRegions];
    CLBeaconRegion *tbDefaultRegion = [tbBeaconRegions objectAtIndex:0];
    [appDelegate.locManager startRangingBeaconsInRegion:tbDefaultRegion]; // Wait for callback
}

- (void)terminateSearch {
    if (_indicator) {
        [_indicator stopAnimating];
        [_indicator removeFromSuperview];
        _indicator = nil;
    }
    _noMapped = YES;
    // Reset full contents
    _fullContents = [NSMutableArray arrayWithArray:[[ContentManager sharedManager] defaultContents]];
}

- (void)refreshWithMappedContents {
    // Reset full contents
    _fullContents = [NSMutableArray arrayWithArray:[[ContentManager sharedManager] defaultContents]];
    ContentManager *contentManager = [ContentManager sharedManager];
    _limitedContents = [contentManager mappedContentsForTbBeacons];
    if (_limitedContents > 0) {
        _noMapped = NO;
        [_fullContents addObjectsFromArray:_limitedContents];
    }
    if (_indicator) {
        [_indicator stopAnimating];
        [_indicator removeFromSuperview];
        _indicator = nil;
    }
    [self.tableView reloadData];
}

@end