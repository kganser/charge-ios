#import "MapController.h"
#import "AFHTTPRequestOperationManager.h"

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
- (UIImage *)getIcon:(Status)status {
    return [UIImage imageNamed:status == ALL
        ? @"pin_green.png"
        : status == SOME
            ? @"pin_yellow.png"
            : @"pin_red.png"];
}
@end

@interface MapController ()
@property (weak, nonatomic) IBOutlet UIView *container;
@property (weak, nonatomic) IBOutlet UIScrollView *detail;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *settings;
@property (weak, nonatomic) IBOutlet UILabel *address;
@property (weak, nonatomic) IBOutlet UILabel *network;
@property (weak, nonatomic) IBOutlet UILabel *level1;
@property (weak, nonatomic) IBOutlet UILabel *level2;
@property (weak, nonatomic) IBOutlet UILabel *level3;
@property GMSMapView *map;
@property GMSMarker *selectedMarker;
@end

@implementation MapController {
    AFHTTPRequestOperationManager *manager;
    GMSCoordinateBounds *bounds;
    NSMutableDictionary *markers;
    NSMutableSet *favorites;
    NSDictionary *prefs;
}

- (void)viewDidLoad {
    markers = [[NSMutableDictionary alloc] init];
    favorites = [[NSMutableSet alloc] init];
    prefs = @{
        @"chargepoint": @YES,
        @"blink": @YES,
        @"level1": @YES,
        @"level2": @YES,
        @"level3": @NO,
        @"unavailable": @YES,
        @"favorites": @NO};
    
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:30.25 longitude:-97.75 zoom:12];
    self.map = [GMSMapView mapWithFrame:self.container.bounds camera:camera];
    self.map.myLocationEnabled = YES;
    self.map.settings.myLocationButton = YES;
    self.map.delegate = self;
    [self.container addSubview:self.map];
    
    self.detail.clipsToBounds = NO;
    self.detail.layer.shadowColor = [[UIColor grayColor] CGColor];
    self.detail.layer.shadowOffset = CGSizeMake(0, -3);
    self.detail.layer.shadowOpacity = .5;

    manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/json", nil];
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
            // TODO: this sometimes erases markers even when they are in bounds
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
                id level1 = [[levels objectForKey:@"level1"] objectForKey:@"paid"];
                id level2 = [[levels objectForKey:@"level2"] objectForKey:@"paid"];
                id level3 = [[levels objectForKey:@"level3"] objectForKey:@"paid"];
                [self addStation:[[Station alloc] initWithId:[NSString stringWithFormat:@"c%@", [station objectForKey:@"device_id"]]
                                                    position:CLLocationCoordinate2DMake([[station objectForKey:@"lat"] doubleValue], [[station objectForKey:@"lon"] doubleValue])
                                                     network:@"Chargepoint"
                                                     address:[[station objectForKey:@"address"] objectForKey:@"address1"]
                                                 level1Avail:[[level1 objectForKey:@"available"] integerValue]
                                                 level1Total:[[level1 objectForKey:@"total"] integerValue]
                                                 level2Avail:[[level2 objectForKey:@"available"] integerValue]
                                                 level2Total:[[level2 objectForKey:@"total"] integerValue]
                                                 level3Avail:[[level3 objectForKey:@"available"] integerValue]
                                                 level3Total:[[level3 objectForKey:@"total"] integerValue]]];
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
            marker.icon = [group getIcon:status];
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
        marker.icon = [group getIcon:status];
        if (self.selectedMarker == nil && status != HIDDEN)
            marker.map = self.map;
        
        marker.userData = group;
        [markers setObject:marker forKey:group.id];
    }
}

- (Status)getStationStatus:(StationGroup *)station {
    BOOL level1 = [[prefs valueForKey:@"level1"] boolValue],
        level2 = [[prefs valueForKey:@"level2"] boolValue],
        level3 = [[prefs valueForKey:@"level3"] boolValue];
    
    if ((level1 ? station.level1Total : 0) + (level2 ? station.level2Total : 0) + (level3 ? station.level3Total : 0) > 0
        && (([station.network isEqualToString:@"Chargepoint"] && [[prefs valueForKey:@"chargepoint"] boolValue])
            || ([station.network isEqualToString:@"Blink"] && [[prefs valueForKey:@"blink"] boolValue]))
        && (![[prefs valueForKey:@"favorites"] boolValue] || [station containsAny:favorites])) {
        
        BOOL level1Avail = level1 && station.level1Avail > 0,
            level2Avail = level2 && station.level2Avail > 0,
            level3Avail = level3 && station.level3Avail > 0;
        
        Status status = level1Avail || level2Avail || level3Avail
            ? (!level1 || level1Avail) && (!level2 || level2Avail) && (!level3Avail || level3Avail)
                ? ALL : SOME : NONE;
        return ![[prefs valueForKey:@"unavailable"] boolValue] && status == NONE ? HIDDEN : status;
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
    
    [mapView animateToLocation:marker.position];
    for (id key in markers) {
        GMSMarker *m = [markers objectForKey:key];
        if (![marker isEqual:m]) m.map = nil;
    }
    [UIView animateWithDuration:.5 animations:^{
        self.detail.center = CGPointMake(self.detail.center.x, self.view.frame.size.height * 3 / 4);
        mapView.padding = UIEdgeInsetsMake(0, 0, self.view.frame.size.height / 2 - 44, 0);
    }];
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    //TODO: make this work
    mapView.selectedMarker = self.selectedMarker;
    mapView.settings.myLocationButton = YES;
    self.selectedMarker = nil;
    
    for (id key in markers)
        [[markers objectForKey:key] setMap:mapView];
    [UIView animateWithDuration:.5 animations:^{
        self.detail.center = CGPointMake(self.detail.center.x, self.view.frame.size.height * 5 / 4);
        mapView.padding = UIEdgeInsetsMake(0, 0, 0, 0);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)unwindToMap:(UIStoryboardSegue *)segue {
    
}

@end
