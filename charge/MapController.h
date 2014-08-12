#import <GoogleMaps/GoogleMaps.h>
#import <UIKit/UIKit.h>

@interface MapController : UIViewController<GMSMapViewDelegate>
    - (IBAction)unwindToMap:(UIStoryboardSegue *)segue;
@end
