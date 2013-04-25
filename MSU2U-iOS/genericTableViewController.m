//
//  genericTableViewController.m
//  MSU2U-iOS
//
//  Created by Matthew Farmer on 11/23/12.
//  Copyright (c) 2012 Matthew Farmer. All rights reserved.
//

#import "genericTableViewController.h"

@interface genericTableViewController ()

@end

@implementation genericTableViewController

//######################################################################################
//#                 PAUL HEGARTY CORE DATA STUFF
//######################################################################################

//for sure
- (NSArray *)executeDataFetch:(NSString *)query
{
    NSData *jsonData = [[NSString stringWithContentsOfURL:[NSURL URLWithString:query] encoding:NSUTF8StringEncoding error:nil] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSArray *results = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:&error] : nil;
    if (error)
    {
        NSLog(@"Error with json: %@",error);
        //do nothing
    }
    
    return results;
}

- (NSArray *)downloadCurrentData:(NSString*)jsonURL
{
    NSString *request = [NSString stringWithFormat:jsonURL];
    return [self executeDataFetch:request];
}

-(void)fetchDataFromOnline:(UIManagedDocument*)document
{
    dispatch_queue_t fetchQ = dispatch_queue_create("Data Fetcher", NULL);
    
    MBProgressHUD *hud;
    
    if([[[self.fetchedResultsController sections] objectAtIndex:0] numberOfObjects] == 0)
    {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }

    dispatch_async(fetchQ,^{
        
        [self.refreshControl beginRefreshing];
        hud.labelText = @"Downloading...";
        
        //### JSON Downloading begins and ends here
        if(self.childNumber == [NSNumber numberWithInt:7])
            [self getTweets:document];
        //News
        else if(self.childNumber == [NSNumber numberWithInt:3])
            [self getNews:document];
        //VIDEO
        else if(self.childNumber == [NSNumber numberWithInt:8])
            [self getVideos:document];
        else if(self.childNumber == [NSNumber numberWithInt:9])
            [self getPodcasts:document];
        else if(self.childNumber == [NSNumber numberWithInt:2])
            [self getEvents:document];
        else if(self.childNumber == [NSNumber numberWithInt:4])
            [self getDirectory:document];
        else
            NSLog(@"I did not recognize what view currently needs data to be loaded?\n");
            
        [self.refreshControl endRefreshing];
        notCurrentlyRefreshing = TRUE;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    });
}

-(void)getDirectory:(UIManagedDocument*)document
{
    NSArray * myData = [self downloadCurrentData:self.jsonURL];
    [document.managedObjectContext performBlock:^{
        for(NSDictionary * dataInfo in myData)
        {
            [Employee employeeWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
    }];
}

-(void)getEvents:(UIManagedDocument*)document
{
    NSArray * myData = [self downloadCurrentData:self.jsonURL];
    [document.managedObjectContext performBlock:^{
        for(NSDictionary * dataInfo in myData)
        {
            [Event eventWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
    }];
}

-(void)getPodcasts:(UIManagedDocument*)document
{
    NSArray * myPodcastData = [self downloadCurrentData:self.jsonURL];
    [document.managedObjectContext performBlock:^{
        for(NSDictionary * dataInfo in myPodcastData)
        {
            [Podcast podcastWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
    }];
}

-(void)getNews:(UIManagedDocument*)document
{
    NSArray * myWichitanData = [self downloadCurrentData:self.jsonURL];
    NSArray * mySportsNewsData = [self downloadCurrentData:self.jsonSportsNewsURL];
    NSArray * myMuseumNewsData = [self downloadCurrentData:self.jsonMuseumNewsURL];
    
    [document.managedObjectContext performBlock:^{
        for(NSDictionary * dataInfo in myWichitanData)
        {
            [News newsWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
        for(NSDictionary * dataInfo in mySportsNewsData)
        {
            [News newsWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
        for(NSDictionary * dataInfo in myMuseumNewsData)
        {
            [News newsWithInfo:dataInfo inManagedObjectContext:document.managedObjectContext];
        }
    }];
}

-(void)getVideos:(UIManagedDocument*)document
{
    //Get videos for all VIMEO channels
    for(int i=0; i<[self.vimeoChannel count]; i++)
    {
        NSArray * myVimeoData = [self downloadCurrentData:[NSString stringWithFormat:@"http://vimeo.com/api/v2/%@/videos.json",[self.vimeoChannel objectAtIndex:i]]];
        
        NSLog(@"myVimeoData = %@\n",myVimeoData);
        [document.managedObjectContext performBlock:^{
            for(NSDictionary * dataInfo in myVimeoData)
            {
                [Video videoWithInfo:dataInfo isVimeo:YES inManagedObjectContext:document.managedObjectContext];
            }
        }];
    }
    
    //Get videos for all YouTube channels
    for(int i=0; i<[self.youTubeChannel count]; i++)
    {
        NSArray * myYouTubeData = [self downloadCurrentData:[NSString stringWithFormat:@"http://gdata.youtube.com/feeds/api/users/%@/uploads?&v=2&max-results=50&alt=jsonc",[self.youTubeChannel objectAtIndex:i]]];
        
        NSDictionary * myInfo = myYouTubeData;
        NSArray * itemsAlone = [[myInfo objectForKey:@"data"] objectForKey:@"items"];
        
        [document.managedObjectContext performBlock:^{
            for(NSDictionary * dataInfo in itemsAlone)
            {
                [Video videoWithInfo:dataInfo isVimeo:NO inManagedObjectContext:document.managedObjectContext];
            }
        }];
    }
}

-(void)getTweets:(UIManagedDocument*)document
{
    //Get access to the user's Twitter Account
    // Request access to the Twitter accounts
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted)
         {
             NSArray *accounts = [accountStore accountsWithAccountType:accountType];
             
             // Check if the user has setup at least one Twitter account
             if (accounts.count > 0)
             {
                 ACAccount *twitterAccount = [accounts objectAtIndex:0];
                 
                 //Setup the request parameters
                 NSMutableDictionary * parameters = [[NSMutableDictionary alloc]init];
                 [parameters setObject:@"1" forKey:@"include_rts"];
                 
                 //For all twitter accounts in my list
                 //[parameters setObject:@"midwesternstate" forKey:@"screen_name"];
                 
                 // Creating a request to get the info about a user on Twitter
                 [parameters setObject:@"midwestern" forKey:@"slug"];
                 [parameters setObject:@"midwesternstate" forKey:@"owner_screen_name"];
                 [parameters setObject:@"100" forKey:@"per_page"];
                 [parameters setObject:@"true" forKey:@"include_entities"];
                 
                 SLRequest *twitterInfoRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1/lists/statuses.json"] parameters:parameters];
                 [twitterInfoRequest setAccount:twitterAccount];
                 
                 // Making the request
                 [twitterInfoRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     dispatch_async(dispatch_get_main_queue(), ^{
                         // Check if we reached the reate limit
                         if ([urlResponse statusCode] == 429)
                         {
                             NSLog(@"Rate limit reached");
                             return;
                         }
                         // Check if there was an error
                         if (error)
                         {
                             NSLog(@"Error: %@", error.localizedDescription);
                             return;
                         }
                         // Check if there is some response data
                         if (responseData)
                         {
                             NSError *error = nil;
                             NSArray *TWData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&error];
                             
                             // Filter the preferred data
                             [document.managedObjectContext performBlock:^{
                                 for(NSDictionary * dataInfo in TWData)
                                 {
                                     [Tweet tweetWithInfo:dataInfo isProfile:TRUE inManagedObjectContext:document.managedObjectContext];
                                 }
                             }];
                         }
                     });
                 }];
                 
                 //Make another request for @MidwesternState
                 
                 //Make Another Request for #SocialStampede
             }
         }
         else
         {
             NSLog(@"No access granted");
         }
     }];
}

-(void)setupFetchedResultsController
{
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    
    //### What should I show in my table?
    //News
    if(self.childNumber == [NSNumber numberWithInt:2])
    {
        NSPredicate * predicate;
        switch(self.showEventsForIndex)
        {
            case 0:
            {
                //ALL
                predicate =[NSPredicate predicateWithFormat:@"startdate >= %@",[NSDate date]];
                break;
            }
            case 1:
            {
                //HOME GAMES ONLY
                predicate = [NSPredicate predicateWithFormat:@"startdate >= %@ AND isHomeGame LIKE[c] 'yes'",[NSDate date]];
                break;
            }
            case 2:
            {
                //AWAY GAMES ONLY
                predicate =[NSPredicate predicateWithFormat:@"startdate >= %@ AND isHomeGame LIKE[c] 'no'",[NSDate date]];
                break;
            }
        }
        [request setPredicate:predicate];
    }
    //Directory
    else if(self.childNumber == [NSNumber numberWithInt:4])
    {
        NSPredicate * predicate;
        if(self.showDirectoryFavoritesOnly)
        {
            predicate = [NSPredicate predicateWithFormat:@"favorite LIKE[c] 'yes'"];
            [request setPredicate:predicate];
        }
        //else set not predicate for your request
    }
    //Twitter
    else if(self.childNumber == [NSNumber numberWithInt:7])
    {
        NSPredicate * predicate;
        
        switch(self.showTweetsForIndex)
        {
            case 0:
            {
                //do nothing because I want to show all Tweets
                break;
            }
            case 1:
            {
                /*
                NSCalendar *cal = [NSCalendar currentCalendar];
                NSDateComponents *components = [cal components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:[[NSDate alloc] init]];
                
                [components setHour:-[components hour]];
                [components setMinute:-[components minute]];
                [components setSecond:-[components second]];
                NSDate *today = [cal dateByAddingComponents:components toDate:[[NSDate alloc] init] options:0]; //This variable should now be pointing at a date object that is the start of today (midnight);
                
                [components setHour:-24];
                [components setMinute:0];
                [components setSecond:0];
                NSDate *yesterday = [cal dateByAddingComponents:components toDate: today options:0];
                
                predicate = [NSPredicate predicateWithFormat:@"created_at >= %@",yesterday];
                [request setPredicate:predicate];
                break;
                 */
                //show ONLY 'msu2u_devteam' tweets
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"screen_name LIKE[c] 'msu2u_devteam'"];
                [request setPredicate:predicate];
                break;
            }
        }
    }
    //NEWS
    else if(self.childNumber == [NSNumber numberWithInt:3])
    {
        switch(self.showNewsForIndex)
        {
            case 0:
            {
                break;
                //do nothing because I want to show ALL of the news
            }
            case 1:
            {
                //show ONLY 'The Wichitan' news
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"publication LIKE[c] 'The Wichitan'"];
                [request setPredicate:predicate];
                break;
            }
            case 2:
            {
                //show ONLY 'MSU Mustangs' sports related news
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"publication LIKE[c] 'MSU Mustangs'"];
                [request setPredicate:predicate];
                break;
            }
            case 3:
            {
                //show ONLY 'Museum' related news
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"publication LIKE[c] 'WF Museum of Art'"];
                [request setPredicate:predicate];
                break;
            }
        }
    }
    //Video
    else if(self.childNumber == [NSNumber numberWithInt:8])
    {
        //do nothing, therefore SHOW ALL because I have NO segmented filter at this time
        switch(self.showVideoForIndex)
        {
            case 0:
            {
                break;
            }
            case 1:
            {
                //show ONLY 'Vimeo' videos
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"source LIKE[c] 'Vimeo'"];
                [request setPredicate:predicate];
                break;
            }
            case 2:
            {
                //show ONLY 'YouTube' videos
                NSPredicate * predicate;
                predicate = [NSPredicate predicateWithFormat:@"source LIKE[c] 'YouTube'"];
                [request setPredicate:predicate];
                break;
            }
        }
    }
    //Podcast
    else if(self.childNumber == [NSNumber numberWithInt:9])
    {
        switch(self.showPodcastForIndex)
        {
            case 0:
            {
                break;
            }
            case 1:
            {
                //Show only podcasts within the last week
                 NSCalendar *cal = [NSCalendar currentCalendar];
                 NSDateComponents *components = [cal components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:[[NSDate alloc] init]];
                 
                 [components setHour:-[components hour]];
                 [components setMinute:-[components minute]];
                 [components setSecond:-[components second]];
                 NSDate *today = [cal dateByAddingComponents:components toDate:[[NSDate alloc] init] options:0]; //This variable should now be pointing at a date object that is the start of today (midnight);
                 
                 [components setHour:-168];
                 [components setMinute:0];
                 [components setSecond:0];
                 NSDate *lastWeek = [cal dateByAddingComponents:components toDate: today options:0];
                
                 NSPredicate * predicate;
                 predicate = [NSPredicate predicateWithFormat:@"pubDate >= %@",lastWeek];
                 [request setPredicate:predicate];
                 break;
            }
        }
    }
    
    //2. How should I sort the data in my table?
    //IF NOT TWITTER AND NOT EVENTS AND NOT NEWS, SORT TABLE BY SOMETHING THAT IS NOT A DATE
    if(self.childNumber != [NSNumber numberWithInt:7] && self.childNumber != [NSNumber numberWithInt:2] && self.childNumber != [NSNumber numberWithInt:3] && self.childNumber != [NSNumber numberWithInt:8] && self.childNumber != [NSNumber numberWithInt:9])
        request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:self.sortDescriptorKey ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
    //SORT TABLE BY DATES FROM NEWEST TO OLDEST
    else if(self.childNumber == [NSNumber numberWithInt:7] || self.childNumber == [NSNumber numberWithInt:3] || self.childNumber == [NSNumber numberWithInt:8] || self.childNumber == [NSNumber numberWithInt:9])
        request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:self.sortDescriptorKey ascending:NO]];
    //SORT TABLE BY DATES FROM OLDEST TO NEWEST
    else
        request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:self.sortDescriptorKey ascending:YES]];

    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:self.myDatabase.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    //3. What should I do if there's NOTHING to show in my table?
    if([[[self.fetchedResultsController sections] objectAtIndex:0] numberOfObjects] == 0)
    {
        if(self.childNumber == [NSNumber numberWithInt:4])
        {
            if(!self.showDirectoryFavoritesOnly)
                [self refresh];
        }
        else if(self.childNumber == [NSNumber numberWithInt:2])
        {
            if(self.showEventsForIndex == 0)
                [self refresh];
        }
        else if(self.childNumber == [NSNumber numberWithInt:3])
        {
            if(self.showNewsForIndex == 0)
                [self refresh];
        }
        else if(self.childNumber == [NSNumber numberWithInt:7])
        {
            if(self.showTweetsForIndex == 0)
                [self refresh];
        }
        else if(self.childNumber == [NSNumber numberWithInt:8])
        {
            if(self.showVideoForIndex == 0)
                [self refresh];
        }
        else if(self.childNumber == [NSNumber numberWithInt:9])
        {
            if(self.showPodcastForIndex == 0)
                [self refresh];
        }
        else
        {
            NSLog(@"!@#!@# WHAT AM I TRYING TO REFRESH???\n");
            //[self refresh];
        }
    }
}

-(void)useDocument
{
    //Does my file not exist yet?
    if(![[NSFileManager defaultManager]fileExistsAtPath:[self.myDatabase.fileURL path]])
    {
        [self.myDatabase saveToURL:self.myDatabase.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success)
         {
             [self setupFetchedResultsController];
         }];
    }
    //What if my document is closed?
    else if(self.myDatabase.documentState == UIDocumentStateClosed)
    {
        [self.myDatabase openWithCompletionHandler:^(BOOL success)
         {
             [self setupFetchedResultsController];
         }];
    }
    //What if my document is already open?
    else if(self.myDatabase.documentState == UIDocumentStateNormal)
    {
        [self setupFetchedResultsController];
    }
    else
    {
        NSLog(@"My document exists but it is neither opened nor closed? Strange error from which we can not recover.\n");
        //do nothing
    }
    
}

-(void)setMyDatabase:(UIManagedDocument *)myDatabase
{
    //If someone sets this document externally, I need to start using it.
    //In the setter, anytime someone sets this (as long as it has changed), then set it.
    if(_myDatabase != myDatabase)
    {
        _myDatabase = myDatabase;
        [self useDocument];
    }
    else
    {
        //do nothing
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"Hello?????\n");
    //Set debug to TRUE for the CoreDataTableViewController class
    self.debug = TRUE;
    
    //Refresh Control
    //Make sure the Directory Favorites and Directory History do NOT have the refresh control.
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor colorWithRed:(55.0/255.0) green:(7.0/255.0) blue:(16.0/255.0) alpha:1];
    
    //Retrieve the user defaults so that the last update for this table may be retrieved and shown to the user
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    NSLog(@"Setting refresh controls...\n");
    //Set the refresh control attributed string to the retrieved last update
    switch([self.childNumber integerValue])
    {
        case 2:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"eventsRefreshTime"]];break;
        case 3:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"newsRefreshTime"]];break;
        case 4:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"directoryRefreshTime"]];break;
        case 7:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"twitterRefreshTime"]];break;
        case 8:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"videoRefreshTime"]];break;
        case 9:refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:[defaults objectForKey:@"podcastRefreshTime"]];break;
        default:NSLog(@"My child number is %@\n",self.childNumber);
    }
    
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    self.refreshControl = refreshControl;
    
    NSLog(@"Setting up the fetched data arrays to be empty...\n");
    //Setup the arrays which will be used to hold the Core Data for the respective Table View Controller
    self.dataArray = [[NSMutableArray alloc]initWithObjects:nil];
    self.filteredDataArray = [[NSMutableArray alloc]initWithObjects:nil];
    
    //I did have the [super viewWillAppear:animated]; right here before.
    NSLog(@"Checking if I should fetch...\n");
    if(!self.myDatabase)
    {
        [[MYDocumentHandler sharedDocumentHandler] performWithDocument:^(UIManagedDocument *document) {
            self.myDatabase = document;
        }];
    }
    else
    {
        [self setupFetchedResultsController];
    }
}

-(void)purgeAllEntitiesOfType:(NSString*)entityName
{
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Do your long-running task here
    __block void (^block)(void) = ^{
        NSLog(@"About to purge...\n");
        NSFetchRequest * allCars = [[NSFetchRequest alloc] init];
        [allCars setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:self.myDatabase.managedObjectContext]];
        [allCars setIncludesPropertyValues:NO]; //only fetch the managedObjectID
        
        NSError * error = nil;
        NSArray * cars = [self.myDatabase.managedObjectContext executeFetchRequest:allCars error:&error];
        
        //error handling goes here
        for (NSManagedObject * car in cars) {
            [self.myDatabase.managedObjectContext deleteObject:car];
        }
        NSError *saveError = nil;
        [self.myDatabase.managedObjectContext save:&saveError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Do callbacks to any UI updates here, like for a status indicator
        });
    //});
    };
    
    [self.myDatabase.managedObjectContext performBlock:block];
}

-(void) downloadAllEntities
{
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //SECOND, GET THE NEW DATA
    [self fetchDataFromOnline:self.myDatabase];
    
    //Set the attributable string for the refresh control
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM d, h:mm a"];
    NSString *lastUpdated = [NSString stringWithFormat:@"Last updated on %@",[formatter stringFromDate:[NSDate date]]];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:lastUpdated];
    
    //Save this update string to the user defaults
    [self saveRefreshTime:lastUpdated];
    //});
}

-(void) refresh
{
    //FIRST, GET RID OF MY CURRENT DATA.
    /*
    if(self.childNumber != [NSNumber numberWithInt:4])
    {
        switch ([self.childNumber integerValue])
        {
            //Events
            case 2:
            {
                [self purgeAllEntitiesOfType:@"Event"];
                break;
            }
            //News
            case 3:
            {
                [self purgeAllEntitiesOfType:@"News"];
                break;
            }
            //Directory
            case 4:
            {
                [self purgeAllEntitiesOfType:@"Employee"];
                break;
            }
            //Twitter
            case 7:
            {
                [self purgeAllEntitiesOfType:@"Tweet"];
                break;
            }
            //Video
            case 8:
            {
                [self purgeAllEntitiesOfType:@"Video"];
                break;
            }
            default:
                break;
        }
    }*/
    [self downloadAllEntities];
    NSLog(@"I'm done purging!\n");
}

-(void)saveRefreshTime:(NSString*)refreshTime
{
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

    switch([self.childNumber integerValue])
    {
        case 2:[defaults setObject:refreshTime forKey:@"eventsRefreshTime"];break;
        case 3:[defaults setObject:refreshTime forKey:@"newsRefreshTime"];break;
        case 4:[defaults setObject:refreshTime forKey:@"directoryRefreshTime"];break;
        case 7:[defaults setObject:refreshTime forKey:@"twitterRefreshTime"];break;
        case 8:[defaults setObject:refreshTime forKey:@"videoRefreshTime"];break;
        case 9:[defaults setObject:refreshTime forKey:@"podcastRefreshTime"];break;
    }
    [defaults synchronize];
}

//######################################################################################
//#                 TABLE VIEW STUFF
//######################################################################################
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Check to see whether the normal table or search results table is being displayed and return the count from the appropriate array
    if (tableView == self.searchDisplayController.searchResultsTableView)
        return [self.filteredDataArray count];
	else
	{
        int count = 0;
        
        if(self.childNumber == [NSNumber numberWithInt:2])
            for (Event * currentEvents in [self.fetchedResultsController fetchedObjects])
                count++;
        else if(self.childNumber == [NSNumber numberWithInt:3])
            for (News * currentNews in [self.fetchedResultsController fetchedObjects])
                count++;
        else if(self.childNumber == [NSNumber numberWithInt:4])
            for(Employee * currentEmployees in [self.fetchedResultsController fetchedObjects])
                count++;
        else if(self.childNumber == [NSNumber numberWithInt:7])
            for(Tweet * currentTweets in [self.fetchedResultsController fetchedObjects])
                count++;
        else if(self.childNumber == [NSNumber numberWithInt:8])
            for(Video * currentVideos in [self.fetchedResultsController fetchedObjects])
                count++;
        else if(self.childNumber == [NSNumber numberWithInt:9])
            for(Podcast * currentPodcasts in [self.fetchedResultsController fetchedObjects])
                count++;
        return count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
    
    if(cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:self.cellIdentifier];
    }
    
    //A generic object, whether it's a news, sports, employee, etc., this will work for any situation
    self.dataObject = nil;
    
    // Check to see whether the normal table or search results table is being displayed and set the employee object from the appropriate array
    if (tableView == self.searchDisplayController.searchResultsTableView)
	{
        self.dataObject = [self.filteredDataArray objectAtIndex:[indexPath row]];
    }
	else
	{
        self.dataObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    
    if(self.childNumber == [NSNumber numberWithInt:2] || self.childNumber == [NSNumber numberWithInt:3])
    {
        //News and Events both have titles to show in their cell
        cell.textLabel.text = [self.dataObject title];
        if(self.childNumber == [NSNumber numberWithInt:2])
        {
            cell.detailTextLabel.text = [self.dataObject desc];
        }
        //News uses something called "short_description"
        else if(self.childNumber == [NSNumber numberWithInt:3])
        {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@",[self.dataObject last_changed],[self.dataObject short_description]];
        }
        
        //THIS IS A NEWS CELL, SO LET'S FIGURE OUT WHICH IMAGE TO SHOW IN THE CELL ROW
        if(self.childNumber == [NSNumber numberWithInt:3])
        {
            NSString * defaultImage;
            if([[self.dataObject publication] isEqualToString:@"The Wichitan"])
            {
                defaultImage = @"theWichitan.jpg";
            }
            else if([[self.dataObject publication] isEqualToString:@"MSU Mustangs"])
            {
                defaultImage = @"101-gameplan.png";
            }
            else if([[self.dataObject publication] isEqualToString:@"WF Museum of Art"])
            {
                defaultImage = @"wfma50x50.png";
            }
            
            //Download a 50x50 image
            [cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject image]] placeholderImage:[UIImage imageNamed:defaultImage] options:0 andResize:CGSizeMake(50, 50)];
            
            //Ensure that the table cell image is restricted to 50x50
            CGSize size = {50,50};
            cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
            
        }
        else if(self.childNumber == [NSNumber numberWithInt:2])
        {
            NSArray * sportCategories = [[NSArray alloc]initWithObjects:@"Men's Cross Country/Track",@"Women's Cross Country/Track",@"Men's Basketball",@"Women's Basketball",@"Football",@"Men's Golf",@"Women's Golf",@"Men's Soccer",@"Women's Soccer",@"Softball",@"Men's Tennis",@"Women's Tennis",@"Volleyball", nil];
            NSArray * sportImages = [[NSArray alloc]initWithObjects:@"crossCountry.jpeg",@"crossCountry.jpeg",@"basketball.jpeg",@"basketball.jpeg",@"football.jpeg",@"golf.jpeg",@"golf.jpeg",@"soccer.jpeg",@"soccer.jpeg",@"softball.jpeg",@"tennis.jpeg",@"tennis.jpeg",@"volleyball.jpeg", nil];
            
            for(int i=0; i<[sportCategories count]; i++)
            {
                //If I find my current sport category in the title string, then set my event category equal to the sport category that was found in the title string and break
                if([[self.dataObject category] rangeOfString:[sportCategories objectAtIndex:i]].location != NSNotFound)
                {
                    cell.imageView.image = [UIImage imageNamed:[sportImages objectAtIndex:i]];
                    break;
                }
            }
            
            //Resize image
            CGSize size = {50,50};
            cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
        }
    }
    else if(self.childNumber == [NSNumber numberWithInt:4])
    {        
        //Directory cells, Directory Favorites, and Directory History
        NSString * directoryName = [self concatenatePrefix:[self.dataObject name_prefix] firstName:[self.dataObject fname] middleName:[self.dataObject middle] lastName:[self.dataObject lname]];
        
        cell.textLabel.text = directoryName;
        cell.detailTextLabel.text = [self.dataObject position_title_1];
        
        [cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject picture]] placeholderImage:[UIImage imageNamed:@"Unknown.jpg"] options:0 andResize:CGSizeMake(40, 50)];
        //[cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject picture]] placeholderImage:[UIImage imageNamed:@"Unknown.jpg"]];
        CGSize size = {40,50};
        cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
    }
    else if(self.childNumber == [NSNumber numberWithInt:7])
    {
        cell.textLabel.text = [self.dataObject text];        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ by %@",[NSDateFormatter localizedStringFromDate:[self.dataObject created_at] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle],[self.dataObject screen_name]];
        
        [cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject profile_image_url]] placeholderImage:[UIImage imageNamed:@"twitter.png"] options:0 andResize:CGSizeMake(50, 50)];
        [cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject profile_image_url]] placeholderImage:[UIImage imageNamed:@"twitter.png"]];
        CGSize size = {50,50};
        cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
    }
    else if(self.childNumber == [NSNumber numberWithInt:8])
    {
        cell.textLabel.text = [self.dataObject title];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ by %@",[NSDateFormatter localizedStringFromDate:[self.dataObject upload_date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle],[self.dataObject user_name]];
        
        [cell.imageView setImageWithURL:[NSURL URLWithString:[self.dataObject thumbnail_small]] placeholderImage:[UIImage imageNamed:@"70-tv.png"] options:0 andResize:CGSizeMake(50, 50)];
        CGSize size = {50,50};
        cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
    }
    else if(self.childNumber == [NSNumber numberWithInt:9])
    {
        cell.textLabel.text = [self.dataObject title];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Posted on %@ by %@",[NSDateFormatter localizedStringFromDate:[self.dataObject pubDate] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle],[self.dataObject author]];
        
        if([[self.dataObject author] isEqualToString:@"MSUMustangs.com"])
        {
            [cell.imageView setImageWithURL:[NSURL URLWithString:@"http://www.msumustangs.com/images/logos/m6.png"] placeholderImage:[UIImage imageNamed:@"70-tv.png"] options:0 andResize:CGSizeMake(50, 50)];
        }
        else
        {
            cell.imageView.image = [UIImage imageNamed:@"RlujSF.png"];
        }
        
        //Resize image
        CGSize size = {50,50};
        cell.imageView.image = [self imageWithImage:cell.imageView.image scaledToSize:size];
    }
    return cell;
}

- (UIImage*)imageWithImage:(UIImage*)image
              scaledToSize:(CGSize)newSize;
{
    UIGraphicsBeginImageContext( newSize );
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

-(NSString*)concatenatePrefix:(NSString*)name_prefix firstName:(NSString*)firstName middleName:(NSString*)middleName lastName:(NSString*)lastName
{
    
    //If they are null, make them empty
    if([name_prefix length] == 0)
        name_prefix = @"";
    else
        name_prefix = [name_prefix stringByAppendingString:@" "];
    if([firstName length] == 0)
        firstName = @"";
    else
        firstName = [firstName stringByAppendingString:@" "];
    if([middleName length] == 0)
        middleName = @"";
    else
        middleName = [middleName stringByAppendingString:@" "];
    if([lastName length] == 0)
        lastName = @"";
    
    //Combine them now
    
    return [[NSString stringWithFormat:@"%@%@%@%@",name_prefix,firstName,middleName,lastName] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Perform segue to candy detail
    if(tableView == self.searchDisplayController.searchResultsTableView)
    {
        [self performSegueWithIdentifier:self.segueIdentifier sender:tableView];
    }
    
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    self.dataObject = nil;
    
    if(sender == self.searchDisplayController.searchResultsTableView)
    {
        NSIndexPath *indexPath = [self.searchDisplayController.searchResultsTableView indexPathForSelectedRow];
        self.dataObject = [self.filteredDataArray objectAtIndex:[indexPath row]];
    }
    else
    {
        NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
        self.dataObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    NSLog(@"My child number is %@\n",self.childNumber);

    if(self.childNumber == [NSNumber numberWithInt:2])
        [segue.destinationViewController sendEventInformation:self.dataObject];
    else if(self.childNumber == [NSNumber numberWithInt:3])
    {
        //[segue.destinationViewController sendNewsInformation:self.dataObject];
        [segue.destinationViewController sendURL:[self.dataObject link] andTitle:[self.dataObject publication]];
        
        //SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress:[self.dataObject link]];
        //[self.navigationController pushViewController:webViewController animated:YES];
    }
    else if(self.childNumber == [NSNumber numberWithInt:4])
    {
        NSLog(@"My dataObject person_id is %@\n",[self.dataObject person_id]);
        if([[self.dataObject person_id]length]==0)
        {
            NSLog(@"My god... I was going to send an empty data object???\n");
        }
        else
        {
            NSLog(@"Well I guess I got stuff after all, step aside for person_id=%@!\n",[self.dataObject person_id]);
            [segue.destinationViewController sendEmployeeInformation:self.dataObject];
        }
    }
    else if(self.childNumber == [NSNumber numberWithInt:7])
    {
        //[segue.destinationViewController sendTweetInformation:self.dataObject];
        NSLog(@"Going to http://www.twitter.com/%@/status/%@",[self.dataObject screen_name],[self.dataObject max_id]);
        [segue.destinationViewController sendURL:[NSString stringWithFormat:@"http://www.twitter.com/%@/status/%@",[self.dataObject screen_name],[self.dataObject max_id]] andTitle:[self.dataObject screen_name]];
        
    }
    else if(self.childNumber == [NSNumber numberWithInt:8])
    {
        NSLog(@"Going to video link...%@",[self.dataObject url]);
        [segue.destinationViewController sendURL:[self.dataObject url] andTitle:[self.dataObject user_name]];
    }
    else if(self.childNumber == [NSNumber numberWithInt:9])
    {
        [segue.destinationViewController sendURL:[self.dataObject link] andTitle:[self.dataObject title]];
    }
    else
    {
        NSLog(@"I'm screwed up badly!\n");
    }
}

//######################################################################################
//#                 Search Display Controller Delegate Methods
//######################################################################################
#pragma mark Content Filtering
- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    
	// Update the filtered array based on the search text and scope.
	
    // Remove all objects from the filtered search array
	[self.filteredDataArray removeAllObjects];
    [self.dataArray removeAllObjects];
    
    
    //Put all of the current relevant data (depending on the current tab) into a mutable array
    
    //DEPENDS ON THE CHILD I'M WORKING WITH
    //Events Tab
    if(self.childNumber == [NSNumber numberWithInt:2])
    {
        for (Event *currentEvents in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentEvents];
    }
    //News Tab
    else if(self.childNumber == [NSNumber numberWithInt:3])
    {
        for (News *currentNews in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentNews];
    }
    //Directory Search Tab
    else if(self.childNumber == [NSNumber numberWithInt:4])
    {
        for (Employee *currentEmployees in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentEmployees];
    }
    //Twitter Tab
    else if(self.childNumber == [NSNumber numberWithInt:7])
    {
        for (Tweet *currentTweets in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentTweets];
    }
    else if(self.childNumber == [NSNumber numberWithInt:8])
    {
        for (Video *currentVideos in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentVideos];
    }
    else if(self.childNumber == [NSNumber numberWithInt:9])
    {
        for (Podcast * currentPodcasts in [self.fetchedResultsController fetchedObjects])
            [self.dataArray addObject:currentPodcasts];
    }
    
    //###### Filter the array using NSPredicate
    NSArray * tempArray = [[NSArray alloc]init];
    NSArray *words = [searchText componentsSeparatedByString:@" "];
    NSMutableArray *predicateList = [NSMutableArray array];
    for (NSString *word in words) {
        if ([word length] > 0) {
            NSString * buildingMyPredicate = [[NSString alloc]init];
            for(int i=0; i<[self.keysToSearchOn count]; i++)
            {
                if((i+1) != [self.keysToSearchOn count])
                {
                    buildingMyPredicate = [buildingMyPredicate stringByAppendingString:[NSString stringWithFormat:@"SELF.%@ CONTAINS[c] '%@' OR ",[self.keysToSearchOn objectAtIndex:i],word]];
                }
                else
                {
                    buildingMyPredicate = [buildingMyPredicate stringByAppendingString:[NSString stringWithFormat:@"SELF.%@ CONTAINS[c] '%@'",[self.keysToSearchOn objectAtIndex:i],word]];
                }
            }
            NSPredicate *pred = [NSPredicate predicateWithFormat:buildingMyPredicate];
            [predicateList addObject:pred];
        }
    }
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateList];
    NSLog(@"%@", predicate);
    tempArray = [self.dataArray filteredArrayUsingPredicate:predicate];
    /*
    if([searchText componentsSeparatedByString:@" "].count == 1)
    {
        subPredicates = [[NSMutableArray alloc]init];
        for(int i=0; i<[self.keysToSearchOn count]; i++)
        {
            [subPredicates addObject:[NSPredicate predicateWithFormat:@"SELF.%@ contains[c] %@",[self.keysToSearchOn objectAtIndex:i],searchText]];
        }
        NSPredicate * predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subPredicates];
        
        tempArray = [self.dataArray filteredArrayUsingPredicate:predicate];
    }
    //THE USER HAS TYPED MULTIPLE WORDS SO I NEED TO CHANGE MY SEARCH STRATEGY
    else
    {
        subPredicates = [[NSMutableArray alloc]init];
        NSArray * searchTerms = [searchText componentsSeparatedByString:@" "];
        NSLog(@"I see that I have %d components!\n",[searchTerms count]);
        for(int i=0; i<[searchTerms count]; i++)
        {
            for(int j=0; j<[self.keysToSearchOn count]; j++)
            {
                [subPredicates addObject:[NSPredicate predicateWithFormat:@"SELF.%@ contains[c] %@",[self.keysToSearchOn objectAtIndex:j],[searchTerms objectAtIndex:i]]];
            }
            NSPredicate * predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subPredicates];
            NSLog(@"NSPredicate is %@\n",predicate);
            tempArray = [self.dataArray filteredArrayUsingPredicate:predicate];
        }
    }
    */
    self.filteredDataArray = [NSMutableArray arrayWithArray:tempArray];
    
}

#pragma mark - UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    
    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    // Return YES to cause the search result table view to be reloaded.
    
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    
    // Tells the table data source to reload when scope bar selection changes
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    
    // Return YES to cause the search result table view to be reloaded.
    
    return YES;
}

@end
