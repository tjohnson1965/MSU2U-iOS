//
//  campusMapViewController.m
//  MSU2U-iOS
//
//  Created by Matthew Farmer on 1/27/13.
//  Copyright (c) 2013 Matthew Farmer. All rights reserved.
//

#import "campusMapViewController.h"
#import "EDAMTypes.h"

typedef void (^RWLocationCallback)(CLLocationCoordinate2D);

@interface campusMapViewController (){
    RWLocationCallback _foundLocationCallback;
}
@end

@implementation campusMapViewController

@synthesize campusMap = _campusMap;

- (NSArray *)executeDataFetch:(NSString *)query
{
    //Get all of the buildings loaded so that searches may be conducted
    NSString * textPath = [[NSBundle mainBundle]pathForResource:@"buildings" ofType:@"json"];
    NSError * error;
    NSData *jsonData = [[NSString stringWithContentsOfFile:textPath encoding:NSUTF8StringEncoding error:nil] dataUsingEncoding:NSUTF8StringEncoding];

    NSArray *results = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:&error] : nil;
    if (error) NSLog(@"[%@ %@] JSON error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error.localizedDescription);
    
    //If you want to see what the JSON file fetched looks like, uncomment the line below
    //NSLog(@"[%@ %@] received %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), results);
    
    return results;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    //Keys to search on
    self.keysToSearchOn = [[NSArray alloc] initWithObjects:@"buildingName",@"tag", nil];
    
    //Set map type
    self.campusMap.delegate = self;
    self.campusMap.mapType = MKMapTypeHybrid;
    
    //Get all of the buildings loaded into memory
    [self loadBuildingsFromJSON];
}

-(void)loadBuildingsFromJSON
{
    //Allocate arrays
    self.buildingName = [[NSMutableArray alloc]init];
    self.buildingImage = [[NSMutableArray alloc]init];
    self.buildingCoordinate = [[NSMutableArray alloc]init];
    self.buildingAddress = [[NSMutableArray alloc]init];
    self.tag = [[NSMutableArray alloc]init];
    self.buildingInfo = [[NSMutableArray alloc]init];
    
    //Download the JSON data
    buildings = [self executeDataFetch:@"buildings.json"];
    
    //NSLog(@"About to stuff buildings into datainfo...\n");
    for(NSDictionary * dataInfo in buildings)
    {
        [self.buildingName addObject:[dataInfo objectForKey:@"name"]];
        [self.buildingCoordinate addObject:[[NSArray alloc]initWithObjects:[dataInfo objectForKey:@"latitude"],[dataInfo objectForKey:@"longitude"], nil]];
        [self.buildingAddress addObject:[[NSArray alloc]initWithObjects:
                                         [dataInfo objectForKey:@"addressCountryCode"],
                                         [dataInfo objectForKey:@"addressStreetCode"],
                                         [dataInfo objectForKey:@"addressStateCode"],
                                         [dataInfo objectForKey:@"addressCityCode"],
                                         [dataInfo objectForKey:@"addressZIPCode"],
                                         nil]];
        [self.buildingInfo addObject:[dataInfo objectForKey:@"info"]];
        [self.buildingImage addObject:[dataInfo objectForKey:@"image"]];
        [self.tag addObject:[[dataInfo objectForKey:@"tag"] stringByAppendingString:[NSString stringWithFormat:@", %@",[dataInfo objectForKey:@"name"]]]];
    }
    //Place the organized JSON data into a dictionary format that can be more easily worked with later
    self.tagToBuildingNameLookup = [[NSDictionary alloc]initWithObjects:self.buildingName forKeys:self.tag];
    self.coordinateLookup = [[NSDictionary alloc]initWithObjects:self.buildingCoordinate forKeys:self.buildingName];
    self.addressLookup = [[NSDictionary alloc]initWithObjects:self.buildingAddress forKeys:self.buildingName];
    self.buildingNameToInfoLookup = [[NSDictionary alloc]initWithObjects:self.buildingInfo forKeys:self.buildingName];
    self.buildingNameToImageLookup = [[NSDictionary alloc]initWithObjects:self.buildingImage forKeys:self.buildingName];
}

- (MKAnnotationView*)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MSULocation class]]) {
        static NSString *const kPinIdentifier = @"MSULocation";
        MKPinAnnotationView *view = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:kPinIdentifier];
        if (!view) {
            view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kPinIdentifier];
            view.canShowCallout = YES;
            view.calloutOffset = CGPointMake(-5, 5);
            view.animatesDrop = NO;
            view.pinColor = MKPinAnnotationColorRed;
        }
        
        view.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        
        return view;
    }
    return nil;
}

-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
	if([overlay isKindOfClass:[MKPolygon class]])
    {
		MKPolygonView *view = [[MKPolygonView alloc] initWithOverlay:overlay];
		view.lineWidth=1;
		//view.strokeColor=[UIColor yellowColor];
		view.strokeColor = _parkingLotColor;
        //view.fillColor=[[UIColor yellowColor] colorWithAlphaComponent:0.5];
        view.fillColor = [_parkingLotColor colorWithAlphaComponent:0.5];
        return view;
	}
    else if([overlay isKindOfClass:[MKPolyline class]])
    {
        MKPolylineView * view = [[MKPolylineView alloc]initWithPolyline:overlay];
        view.lineWidth=5;
        view.strokeColor = _polylineColor;
        if(_polylineColor == [UIColor purpleColor])
        {
            //bus
            view.tag = 1;
        }
        else if(_polylineColor == [UIColor greenColor])
        {
            //campus border
            view.tag = 2;
        }
        return view;
    }
	return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    _selectedLocation = (MSULocation*)view.annotation;
    
    // 1
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@""
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Show Directions",@"More Info",@"Remove Pin", nil];
    
    // 3
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    // 4
    //[sheet showInView:self.view];
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (void)performAfterFindingLocation:(RWLocationCallback)callback
{
    if (self.campusMap.userLocation != nil) {
        if (callback) {
            callback(self.campusMap.userLocation.coordinate);
        }
    } else {
        _foundLocationCallback = [callback copy];
    }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if (_foundLocationCallback) {
        _foundLocationCallback(userLocation.coordinate);
    }
    _foundLocationCallback = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // 1
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        if (buttonIndex == 0) {
            // Convert the CLPlacemark to an MKPlacemark
            // Note: There's no error checking for a failed geocode
            NSDictionary *addressDict = @{
                                          (NSString *) kABPersonAddressStreetKey : _selectedLocation.addressStreetKey,
                                          (NSString *) kABPersonAddressCityKey : _selectedLocation.addressCityKey,
                                          (NSString *) kABPersonAddressStateKey : _selectedLocation.addressStateKey,
                                          (NSString *) kABPersonAddressZIPKey : _selectedLocation.addressZIPKey,
                                          (NSString *) kABPersonAddressCountryKey : _selectedLocation.countryKey
                                          };
            MKPlacemark *placemark = [[MKPlacemark alloc]
                                      initWithCoordinate:[_selectedLocation coordinate]
                                      addressDictionary:addressDict];
            
            // Create a map item for the geocoded address to pass to Maps app
            MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
            [mapItem setName:[_selectedLocation title]];
            
            // Set the directions mode to "Driving"
            // Can use MKLaunchOptionsDirectionsModeWalking instead
            NSDictionary *launchOptions = @{MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving};
            
            // Get the "Current User Location" MKMapItem
            MKMapItem *currentLocationMapItem = [MKMapItem mapItemForCurrentLocation];
            
            // Pass the current location and destination map items to the Maps app
            // Set the direction mode in the launchOptions dictionary
            [MKMapItem openMapsWithItems:@[currentLocationMapItem, mapItem] launchOptions:launchOptions];
            
        } else if (buttonIndex == 2) {
            // REMOVE PIN HERE
            id<MKAnnotation> ann = [[_campusMap selectedAnnotations] objectAtIndex:0];
            NSLog(@"ann.title = %@", ann.title);
            [_campusMap removeAnnotation:ann];
        } else if (buttonIndex == 1) {
            // SHOW MORE INFO CODE HERE
            //I want to segue to the building info screen
            buildingInfoPressed = YES;
            [self performSegueWithIdentifier:@"toBuildingInfo" sender:self];
        }
    }
    
    // 5
    _selectedLocation = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if(buildingInfoPressed)
    {
        [segue.destinationViewController sendBuildingName:[_selectedLocation title] andInfo:[self.buildingNameToInfoLookup objectForKey:[_selectedLocation title]] andImage:[self.buildingNameToImageLookup objectForKey:[_selectedLocation title]]];
        buildingInfoPressed = NO;
    }else{
        NSLog(@"Settings was pressed");
        [segue.destinationViewController sendMapview:self.campusMap];
    }
}


-(void)viewDidAppear:(BOOL)animated
{
    [self.campusMap removeOverlays:[_campusMap overlays]];
    //Define map view region
    MKCoordinateSpan span;
	span.latitudeDelta=.01;
	span.longitudeDelta=.01;
    
	MKCoordinateRegion region;
	region.span=span;
	region.center=CLLocationCoordinate2DMake(33.871841, -98.521914);
    
    [_campusMap setRegion:region animated:NO];
	[_campusMap regionThatFits:region];
    
    //#####
    //####
    //### Draw Overlays!
    //##
    //#
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    if([defaults boolForKey:@"campusMapSettingsParkingLot"])
    {
        overlay * pl = [[overlay alloc]init];
        _parkingLotColor = [UIColor yellowColor];
        [pl drawCommuterParkingLots:_campusMap];
        _parkingLotColor = [UIColor cyanColor];
        [pl drawReservedParkingLots:_campusMap];
        _parkingLotColor = [UIColor redColor];
        [pl drawResidentialParkingLots:_campusMap];
        _parkingLotColor = [UIColor orangeColor];
        [pl drawHybridParkingLots:_campusMap];
    }
    else
    {
        [_campusMap removeOverlays:[_campusMap overlays]];
    }
    
    if([defaults boolForKey:@"campusMapSettingsBusRoute"])
    {
        overlay * pk = [[overlay alloc]init];
        _polylineColor = [UIColor purpleColor];
        [pk busRoute:_campusMap];
    }
    else
    {
        //Remove only the bus route tag
        [[self.view.window viewWithTag:1] removeFromSuperview];
    }
    
    if([defaults boolForKey:@"campusMapSettingsCampusBorder"])
    {
        overlay * pc = [[overlay alloc]init];
        _polylineColor = [UIColor greenColor];
        [pc campusBorder:_campusMap];
    }
    else
    {
        //Remove only the campus border
        [[self.view.window viewWithTag:2] removeFromSuperview];
    }
    
    //#####
    //####
    //### Draw appropriate map type!
    //##
    //#
    NSLog(@"My map type should be %@\n",[defaults objectForKey:@"campusMapSettingsMapRowChecked"]);
    if([[defaults objectForKey:@"campusMapSettingsMapRowChecked"] isEqualToString:@"Hybrid"])
    {
        self.campusMap.mapType = MKMapTypeHybrid;
    }
    else if([[defaults objectForKey:@"campusMapSettingsMapRowChecked"]isEqualToString:@"Satellite Only"])
    {
        self.campusMap.mapType = MKMapTypeSatellite;
    }
    else if([[defaults objectForKey:@"campusMapSettingsMapRowChecked"]isEqualToString:@"Roads Only"])
    {
        self.campusMap.mapType = MKMapTypeStandard;
    }

    //#####
    //####
    //### Should I draw all building pins?
    //##
    //#
    if([defaults boolForKey:@"campusMapSettingsAddAllPins"])
    {
        [defaults setBool:NO forKey:@"campusMapSettingsAddAllPins"];
        
        //Drop all pins! But first, go ahead and clear it out of existing pins
        [self.campusMap removeAnnotations:[self.campusMap annotations]];

        for(int i=0; i<[self.buildingName count]; i++){
            [self addPinWithTitle:[self.buildingName objectAtIndex:i] atLocation:[self.coordinateLookup objectForKey:[self.buildingName objectAtIndex:i]] atAddress:[self.addressLookup objectForKey:[self.buildingName objectAtIndex:i]]];
        }
    }

    //Should I zoom the map in?
    if(zoomedCoordinate.latitude)
    {
        MKCoordinateRegion adjustedRegion = [self.campusMap regionThatFits:MKCoordinateRegionMakeWithDistance(zoomedCoordinate, 250, 250)];
        [self.campusMap setRegion:adjustedRegion animated:NO];
    }
    
    [super viewDidLoad];
}

-(void)addAllBuildingPins {
    //Remove all pins
    [self.campusMap removeAnnotations:[self.campusMap annotations]];
    //Place pins on campus map for all buildings in buildings.json
    for(int i=0; i<[self.buildingName count]; i++){
        [self addPinWithTitle:[self.buildingName objectAtIndex:i] atLocation:[self.coordinateLookup objectForKey:[self.buildingName objectAtIndex:i]] atAddress:[self.addressLookup objectForKey:[self.buildingName objectAtIndex:i]]];
    }
}

-(void)addPinWithTitle:(NSString*)title atLocation:(NSArray*)locationInfo atAddress:(NSArray*)addressInfo
{
    //locationInfo:
    //Index 0 is an array with two elements: latitude and longitude
    //Index 1 is an array with five elements: country code, street, state, city, ZIP
    //Therefore, to get the street for example, I need to go to index 1 of the object at index 1 of locationInfo
    MSULocation * testBuilding = [[MSULocation alloc] init];
    
    //Create information for this test site
    testBuilding.title = title;
    testBuilding.countryKey = [addressInfo objectAtIndex:0];
    testBuilding.addressStreetKey = [addressInfo objectAtIndex:1];
    testBuilding.addressStateKey = [addressInfo objectAtIndex:2];
    testBuilding.addressCityKey = [addressInfo objectAtIndex:3];
    testBuilding.addressZIPKey = [addressInfo objectAtIndex:4];
    
    CLLocationCoordinate2D myCoordinate = CLLocationCoordinate2DMake([[locationInfo objectAtIndex:0]floatValue], [[locationInfo objectAtIndex:1]floatValue]);
    
    testBuilding.coordinate = myCoordinate;
    
    //Add annotation to the map
    NSLog(@"I am about to add a building!");
    [self.campusMap addAnnotation:testBuilding];
}

- (void) sendLocationName:(NSString*)locationName andEmployeeName:(NSString*)employeeName
{
    //Do all of the necessary loading
    [self viewDidAppear:YES];
    
    NSLog(@"I am hoping to find %@ in my building list...\n",locationName);
    NSLog(@"Coordinates: %@\n",[self.coordinateLookup objectForKey:locationName]);
    NSLog(@"Address: %@\n",[self.addressLookup objectForKey:locationName]);
    
    if([self.coordinateLookup objectForKey:locationName])
    {
        //Now, go ahead and search for the building's location and place a pin if you can. If not, notify the user.
        CLLocationCoordinate2D coordinate;
        [self addPinWithTitle:locationName atLocation:[self.coordinateLookup objectForKey:locationName] atAddress:[self.addressLookup objectForKey:locationName]];
        
        //Get ready to zoom in on the employee's location
        float latitude = [[[self.coordinateLookup objectForKey:locationName] objectAtIndex:0] floatValue];
        float longitude = [[[self.coordinateLookup objectForKey:locationName]objectAtIndex:1] floatValue];
        
        coordinate = CLLocationCoordinate2DMake(latitude,longitude);
        zoomedCoordinate = coordinate;
        
        MKCoordinateRegion adjustedRegion = [self.campusMap regionThatFits:MKCoordinateRegionMakeWithDistance(coordinate, 250, 250)];
        //[self.searchDisplayController setActive:NO animated:YES];
        [self.campusMap setRegion:adjustedRegion animated:YES];
    }
    else
    {
        UIAlertView * av = [[UIAlertView alloc]initWithTitle:@"Oops" message:[NSString stringWithFormat:@"Could not locate %@. Try using the search bar.",locationName] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [av show];
    }
}

//SEARCH BAR TABLE VIEW STUFF
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [searchResults count];
        
    } else {
        return [self.buildingName count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"testing"];
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        cell.textLabel.text = [searchResults objectAtIndex:indexPath.row];
    } else {
        cell.textLabel.text = [self.buildingName objectAtIndex:indexPath.row];
    }
    return cell;
}

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    //ORIGINAL MAP SEARCH CODE
    searchResults = [[NSMutableArray alloc]init];
    
    
    NSArray *words = [searchText componentsSeparatedByString:@" "];
    NSMutableArray *predicateList = [NSMutableArray array];
    
    for (NSString *word in words) {
        if ([word length] > 0)
        {
            NSString * buildingMyPredicate = [[NSString alloc]init];

            NSString *escaped = [word stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];

            buildingMyPredicate = [buildingMyPredicate stringByAppendingString:[NSString stringWithFormat:@"SELF CONTAINS[c] '%@'",escaped]];

            NSPredicate *pred = [NSPredicate predicateWithFormat:buildingMyPredicate];
            [predicateList addObject:pred];
        }
    }
    NSPredicate *resultPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateList];
    
    tagResults = [self.tag filteredArrayUsingPredicate:resultPredicate];
    
    //OK, I have all the appropriate matching tags. Now, I just need the building name associated with each tag!
    for(int i=0; i<[tagResults count]; i++)
    {
        NSLog(@"%d: %@\n",i,[tagResults objectAtIndex:i]);
        [searchResults addObject:[self.tagToBuildingNameLookup objectForKey:[tagResults objectAtIndex:i]]];
    }
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller
shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar
                                                     selectedScopeButtonIndex]]];
    return YES;
}

//What happens when a search result is selected?
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CLLocationCoordinate2D coordinate;
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        [self addPinWithTitle:[searchResults objectAtIndex:indexPath.row] atLocation:[self.coordinateLookup objectForKey:[searchResults objectAtIndex:indexPath.row]] atAddress:[self.addressLookup objectForKey:[searchResults objectAtIndex:indexPath.row]]];
    }

    //Center the pin on the map
    float latitude = [[[self.coordinateLookup objectForKey:[searchResults objectAtIndex:indexPath.row]] objectAtIndex:0] floatValue];
    float longitude = [[[self.coordinateLookup objectForKey:[searchResults objectAtIndex:indexPath.row]]objectAtIndex:1] floatValue];
    
    coordinate = CLLocationCoordinate2DMake(latitude,longitude);
    
    MKCoordinateRegion adjustedRegion = [self.campusMap regionThatFits:MKCoordinateRegionMakeWithDistance(coordinate, 250, 250)];
    [self.searchDisplayController setActive:NO animated:YES];
    [self.campusMap setRegion:adjustedRegion animated:YES];
}

@end
