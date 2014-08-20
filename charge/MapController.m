#import "MapController.h"
#import "AFHTTPRequestOperationManager.h"
#import "MMDrawerBarButtonItem.h"
#import "MMDrawerController.h"
#import "AppDelegate.h"
#import <MapKit/MapKit.h>

typedef enum {
    ALL,
    SOME,
    NONE,
    HIDDEN
} Status;

@interface Station : NSObject
    @property NSString *id, *network, *address;
    @property CLLocationCoordinate2D position;
    @property int level1Avail, level1Total, level2Avail, level2Total, level3Avail, level3Total;
@end
@implementation Station
- (id)initWithId:(NSString *)id position:(CLLocationCoordinate2D)position network:(NSString *)network address:(NSString *)address level1Avail:(int)level1Avail level1Total:(int)level1Total level2Avail:(int)level2Avail level2Total:(int)level2Total level3Avail:(int)level3Avail level3Total:(int)level3Total {
    if (self = [super init]) {
        self.id = id;
        self.network = network;
        self.address = address;
        self.position = position;
        self.level1Avail = level1Avail;
        self.level1Total = level1Total;
        self.level2Avail = level2Avail;
        self.level2Total = level2Total;
        self.level3Avail = level3Avail;
        self.level3Total = level3Total;
    }
    return self;
}
@end

@interface StationGroup : Station
    @property NSMutableDictionary *stations;
@end
@implementation StationGroup
+ (UIImage *)getIcon:(Status)status {
    return [UIImage imageNamed:status == ALL
        ? @"pin_green.png"
        : status == SOME
            ? @"pin_yellow.png"
            : @"pin_red.png"];
}
- (id)initWithStation:(Station *)station {
    if (self = [super initWithId:station.id position:station.position network:station.network address:station.address level1Avail:station.level1Avail level1Total:station.level1Total level2Avail:station.level2Avail level2Total:station.level2Total level3Avail:station.level3Avail level3Total:station.level3Total]) {
        self.stations = [[NSMutableDictionary alloc] initWithObjectsAndKeys:station, station.id, nil];
    }
    return self;
}
- (BOOL)add:(Station *)station {
    if ([station.network isEqualToString:self.network]) {
        if ([self.stations objectForKey:station.id] != nil)
            return YES;
        for (id key in self.stations) {
            Station *s = [self.stations objectForKey:key];
            double distance = GMSGeometryDistance(station.position, s.position);
            if (distance < 100 || (distance < 200 && [s.address isEqualToString:station.address])) {
                [self.stations setObject:station forKey:station.id];
                self.level1Avail += station.level1Avail;
                self.level1Total += station.level1Total;
                self.level2Avail += station.level2Avail;
                self.level2Total += station.level2Total;
                self.level3Avail += station.level3Avail;
                self.level3Total += station.level3Total;
                return YES;
            }
        }
    }
    return NO;
}
- (BOOL)containsAny:(NSMutableSet *)ids {
    for (id key in ids)
        if ([self.stations valueForKey:key] != nil)
            return YES;
    return NO;
}
@end

@interface MapController ()
@property (weak, nonatomic) IBOutlet UIView *container;
@property (weak, nonatomic) IBOutlet UIView *streetView;
@property (weak, nonatomic) IBOutlet UIScrollView *detail;
@property (weak, nonatomic) IBOutlet UILabel *address;
@property (weak, nonatomic) IBOutlet UILabel *network;
@property (weak, nonatomic) IBOutlet UILabel *level1;
@property (weak, nonatomic) IBOutlet UILabel *level2;
@property (weak, nonatomic) IBOutlet UILabel *level3;
@property (weak, nonatomic) IBOutlet UIButton *directions;
@property (weak, nonatomic) IBOutlet UIButton *fav;
@property GMSMapView *map;
@property GMSPanoramaView *street;
@property GMSMarker *selectedMarker;
@property ADBannerView *ad;
@end

@implementation MapController {
    AFHTTPRequestOperationManager *manager;
    GMSCoordinateBounds *bounds;
    GMSPanoramaService *panorama;
    NSMutableDictionary *markers;
    NSUserDefaults *prefs;
    NSMutableSet *favorites;
}

- (void)viewDidLoad {
    markers = [[NSMutableDictionary alloc] init];
    prefs = [AppDelegate getPreferences];
    favorites = [[NSMutableSet alloc] initWithArray:[prefs stringArrayForKey:@"favorites"]];
    panorama = [[GMSPanoramaService alloc] init];
    self.ad = [[ADBannerView alloc] initWithAdType:ADAdTypeBanner];
    self.ad.delegate = self;
    
    MMDrawerBarButtonItem *drawerButton = [[MMDrawerBarButtonItem alloc] initWithTarget:self action:@selector(toggleSettings:)];
    drawerButton.tintColor = [UIColor whiteColor];
    [self.navigationItem setLeftBarButtonItem:drawerButton animated:YES];

    manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/json", nil];
}

- (void)viewWillLayoutSubviews {
    float height = self.container.bounds.size.height / 3,
        width = self.container.bounds.size.width;
    self.detail.bounds = CGRectMake(0, 0, width, height * 2);
    self.detail.center = CGPointMake(self.detail.center.x, height * 4 + 10);
    self.detail.clipsToBounds = NO;
    self.detail.layer.shadowColor = [[UIColor grayColor] CGColor];
    self.detail.layer.shadowOffset = CGSizeMake(0, -3);
    self.detail.layer.shadowOpacity = .5;
    [self.directions addTarget:self action:@selector(getDirections:) forControlEvents:UIControlEventTouchUpInside];
    [self.fav addTarget:self action:@selector(setFavorite:) forControlEvents:UIControlEventTouchUpInside];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.detail.bounds;
    gradient.colors = @[(id)[UIColor colorWithWhite:1. alpha:.7].CGColor, (id)[UIColor colorWithWhite:1. alpha:1.].CGColor];
    gradient.locations = @[@0, @0.25];
    [self.detail.layer insertSublayer:gradient atIndex:0];
    
    self.map = [GMSMapView mapWithFrame:self.container.bounds camera:[GMSCameraPosition cameraWithLatitude:[prefs floatForKey:@"latitude"] longitude:[prefs floatForKey:@"longitude"] zoom:[prefs floatForKey:@"zoom"]]];
    self.map.myLocationEnabled = YES;
    self.map.settings.myLocationButton = YES;
    self.map.delegate = self;
    [self.container addSubview:self.map];
    
    self.streetView.bounds = CGRectMake(0, 0, width, height);
    self.streetView.center = CGPointMake(self.streetView.center.x, height * 1.5);
    self.street = [[GMSPanoramaView alloc] initWithFrame:self.streetView.bounds];
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
    [self.ad removeFromSuperview];
}

- (void)toggleSettings:(id)sender {
    [(MMDrawerController *)self.parentViewController.parentViewController toggleDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
}

- (void)getDirections:(id)sender {
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:@"comgooglemaps-x-callback://"]]) {
        [app openURL:[NSURL URLWithString:[NSString stringWithFormat:@"comgooglemaps://?daddr=%f,%f&directionsmode=driving&x-source=Charge&x-success=comkgansercharge://", self.selectedMarker.position.latitude, self.selectedMarker.position.longitude]]];
    } else {
        MKMapItem *dest = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:self.selectedMarker.position addressDictionary:nil]];
        dest.name = ((StationGroup *)self.selectedMarker.userData).address;
        [MKMapItem openMapsWithItems:@[dest] launchOptions:@{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving}];
    }
}

- (void)setFavorite:(id)sender {
    NSString *img = @"favorite.png";
    StationGroup *group = self.selectedMarker.userData;
    if ([group containsAny:favorites]) {
        img = @"not_favorite.png";
        for (NSString *station in group.stations)
            [favorites removeObject:station];
    } else {
        for (NSString *station in group.stations)
            [favorites addObject:station];
    }
    [(UIButton *)sender setImage:[UIImage imageNamed:img] forState:UIControlStateNormal];
}

- (void)updateMarkers {
    for (id key in markers) {
        GMSMarker *marker = [markers objectForKey:key];
        Status status = [self getStationStatus:marker.userData];
        marker.icon = [StationGroup getIcon:status];
        marker.map = (self.selectedMarker == nil && status != HIDDEN) || [self.selectedMarker isEqual:marker] ? self.map : nil;
    }
}

- (void)saveState {
    [prefs setValue:[favorites allObjects] forKey:@"favorites"];
    [prefs setFloat:self.map.camera.target.latitude forKey:@"latitude"];
    [prefs setFloat:self.map.camera.target.longitude forKey:@"longitude"];
    [prefs setFloat:self.map.camera.zoom forKey:@"zoom"];
    [prefs synchronize];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    self.map.frame = self.container.bounds;
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)cameraPosition {
    bounds = [[GMSCoordinateBounds alloc] initWithRegion:mapView.projection.visibleRegion];
    
    if (cameraPosition.zoom > 7 && self.selectedMarker == nil) {
        [[manager operationQueue] cancelAllOperations];
        
        for (id key in markers.allKeys) {
            GMSMarker *marker = [markers objectForKey:key];
            if (![bounds containsCoordinate:marker.position]) {
                marker.map = nil;
                [markers removeObjectForKey:key];
            }
        }
        
        [manager GET:[NSString stringWithFormat:@"https://na.chargepoint.com/dashboard/getChargeSpots?ne_lat=%f&ne_lng=%f&sw_lat=%f&sw_lng=%f", bounds.northEast.latitude, bounds.northEast.longitude, bounds.southWest.latitude, bounds.southWest.longitude] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            for (id station in [[[responseObject objectAtIndex:0] objectForKey:@"station_list"] objectForKey:@"summaries"]) {
                if ([[station objectForKey:@"station_status"] isEqualToString:@"out_of_network"])
                    continue;
                id levels = [station objectForKey:@"map_data"];
                id level1 = [levels objectForKey:@"level1"];
                id level2 = [levels objectForKey:@"level2"];
                id level3 = [levels objectForKey:@"level3"];
                id level1Paid = [level1 objectForKey:@"paid"];
                id level2Paid = [level2 objectForKey:@"paid"];
                id level3Paid = [level3 objectForKey:@"paid"];
                id level1Free = [level1 objectForKey:@"free"];
                id level2Free = [level2 objectForKey:@"free"];
                id level3Free = [level3 objectForKey:@"free"];
                [self addStation:[[Station alloc] initWithId:[NSString stringWithFormat:@"c%@", [station objectForKey:@"device_id"]]
                                                    position:CLLocationCoordinate2DMake([[station objectForKey:@"lat"] doubleValue], [[station objectForKey:@"lon"] doubleValue])
                                                     network:@"Chargepoint"
                                                     address:[[station objectForKey:@"address"] objectForKey:@"address1"]
                                                 level1Avail:[[level1Free objectForKey:@"available"] intValue] + [[level1Paid objectForKey:@"available"] intValue]
                                                 level1Total:[[level1Free objectForKey:@"total"] intValue] + [[level1Paid objectForKey:@"total"] intValue]
                                                 level2Avail:[[level2Free objectForKey:@"available"] intValue] + [[level2Paid objectForKey:@"available"] intValue]
                                                 level2Total:[[level2Free objectForKey:@"total"] intValue] + [[level2Paid objectForKey:@"total"] intValue]
                                                 level3Avail:[[level3Free objectForKey:@"available"] intValue] + [[level3Paid objectForKey:@"available"] intValue]
                                                 level3Total:[[level3Free objectForKey:@"total"] intValue] + [[level3Paid objectForKey:@"total"] intValue]]];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"%@", error);
        }];
        
        [manager GET:[NSString stringWithFormat:@"http://www.blinknetwork.com/locator/locations?lat=%f&lng=%f&latd=%f&lngd=%f&mode=avail", cameraPosition.target.latitude, cameraPosition.target.longitude, fabs(bounds.northEast.latitude - bounds.southWest.latitude), fabs(bounds.northEast.longitude - bounds.southWest.longitude)] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            for (id station in responseObject) {
                int level1Avail = 0, level1Total = 0, level2Avail = 0, level2Total = 0, level3Avail = 0, level3Total = 0;
                id chargers, units = [station objectForKey:@"units"];
                for (id key in chargers = [units objectForKey:@"1"]) {
                    if ([[[chargers objectForKey:key] objectForKey:@"state"] isEqualToString:@"AVAIL"])
                        level1Avail++;
                    level1Total++;
                }
                for (id key in chargers = [units objectForKey:@"2"]) {
                    if ([[[chargers objectForKey:key] objectForKey:@"state"] isEqualToString:@"AVAIL"])
                        level2Avail++;
                    level2Total++;
                }
                for (id key in chargers = [units objectForKey:@"DCFAST"]) {
                    if ([[[chargers objectForKey:key] objectForKey:@"state"] isEqualToString:@"AVAIL"])
                        level3Avail++;
                    level3Total++;
                }
                [self addStation:[[Station alloc] initWithId:[NSString stringWithFormat:@"b%@", [station objectForKey:@"id"]]
                                                    position:CLLocationCoordinate2DMake([[station objectForKey:@"latitude"] doubleValue], [[station objectForKey:@"longitude"] doubleValue])
                                                     network:@"Blink"
                                                     address:[station objectForKey:@"address1"]
                                                 level1Avail:level1Avail
                                                 level1Total:level1Total
                                                 level2Avail:level2Avail
                                                 level2Total:level2Total
                                                 level3Avail:level3Avail
                                                 level3Total:level3Total]];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"%@", error);
        }];
    }
}

- (void)addStation:(Station *)station {
    for (id key in markers) {
        StationGroup *group = [[markers objectForKey:key] userData];
        if ([group add:station]) {
            GMSMarker *marker = [markers objectForKey:group.id];
            Status status = [self getStationStatus:group];
            marker.icon = [StationGroup getIcon:status];
            marker.map = (self.selectedMarker == nil && status != HIDDEN) || [self.selectedMarker isEqual:marker] ? self.map : nil;
            return;
        }
    }
    if ([bounds containsCoordinate:station.position]) {
        StationGroup *group = [[StationGroup alloc] initWithStation:station];
        Status status = [self getStationStatus:group];
        GMSMarker *marker = [[GMSMarker alloc] init];
        marker.position = group.position;
        marker.title = group.address;
        marker.snippet = group.network;
        marker.icon = [StationGroup getIcon:status];
        marker.map = self.selectedMarker == nil && status != HIDDEN ? self.map : nil;
        
        marker.userData = group;
        [markers setObject:marker forKey:group.id];
    }
}

- (Status)getStationStatus:(StationGroup *)station {
    BOOL level1 = [prefs boolForKey:@"level1"],
        level2 = [prefs boolForKey:@"level2"],
        level3 = [prefs boolForKey:@"level3"];
    
    if ((level1 ? station.level1Total : 0) + (level2 ? station.level2Total : 0) + (level3 ? station.level3Total : 0) > 0
        && (([station.network isEqualToString:@"Chargepoint"] && [prefs boolForKey:@"chargepoint"])
            || ([station.network isEqualToString:@"Blink"] && [prefs boolForKey:@"blink"]))
        && (![prefs boolForKey:@"optFavorites"] || [station containsAny:favorites])) {
        
        BOOL level1Avail = level1 && station.level1Avail > 0,
            level2Avail = level2 && station.level2Avail > 0,
            level3Avail = level3 && station.level3Avail > 0;
        
        Status status = level1Avail || level2Avail || level3Avail
            ? (!level1 || level1Avail) && (!level2 || level2Avail) && (!level3Avail || level3Avail)
                ? ALL : SOME : NONE;
        return ![prefs boolForKey:@"unavailable"] && status == NONE ? HIDDEN : status;
    }
    return HIDDEN;
}

- (void)mapView:(GMSMapView *)mapView didTapInfoWindowOfMarker:(GMSMarker *)marker {
    self.selectedMarker = marker;
    mapView.selectedMarker = nil;
    mapView.settings.myLocationButton = NO;
    
    StationGroup *group = marker.userData;
    self.address.text = group.address;
    self.network.text = group.network;
    self.level1.text = group.level1Total ? [NSString stringWithFormat:@"%i/%i available", group.level1Avail, group.level1Total] : @"none";
    self.level2.text = group.level2Total ? [NSString stringWithFormat:@"%i/%i available", group.level2Avail, group.level2Total] : @"none";
    self.level3.text = group.level3Total ? [NSString stringWithFormat:@"%i/%i available", group.level3Avail, group.level3Total] : @"none";
    [self.fav setImage:[UIImage imageNamed:[group containsAny:favorites] ? @"favorite.png": @"not_favorite.png"] forState:UIControlStateNormal];
    [panorama requestPanoramaNearCoordinate:group.position callback:^(GMSPanorama *p, NSError *error) {
        if (p != nil) {
            [self.streetView addSubview:self.street];
            [self.street moveToPanoramaID:p.panoramaID];
        } else {
            [self.streetView addSubview:self.ad];
        }
    }];
    
    for (id key in markers) {
        GMSMarker *m = [markers objectForKey:key];
        if (![marker isEqual:m]) m.map = nil;
    }
    [self.map animateToLocation:marker.position];
    [UIView animateWithDuration:.5 animations:^{
        mapView.padding = UIEdgeInsetsMake(0, 0, self.detail.frame.size.height, 0);
        self.detail.center = CGPointMake(self.detail.center.x, self.view.frame.size.height - self.detail.frame.size.height / 2);
    }];
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    // TODO: make this work
    mapView.selectedMarker = self.selectedMarker;
    mapView.settings.myLocationButton = YES;
    self.selectedMarker = nil;
    [self.street removeFromSuperview];
    [self.ad removeFromSuperview];
    
    for (id key in markers) {
        GMSMarker *marker = [markers objectForKey:key];
        if ([self getStationStatus:marker.userData] != HIDDEN)
            marker.map = mapView;
    }
    [UIView animateWithDuration:.5 animations:^{
        mapView.padding = UIEdgeInsetsMake(0, 0, 0, 0);
        self.detail.center = CGPointMake(self.detail.center.x, self.view.frame.size.height + self.detail.frame.size.height / 2 + 10);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
