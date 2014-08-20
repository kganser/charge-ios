#import <GoogleMaps/GoogleMaps.h>
#import <UIKit/UIKit.h>
#import <iAd/iAd.h>

@interface MapController : UIViewController<GMSMapViewDelegate, ADBannerViewDelegate>
- (void)updateMarkers;
- (void)saveState;
@end
