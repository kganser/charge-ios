#import <UIKit/UIKit.h>
#import <GoogleMaps/GoogleMaps.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
+ (NSUserDefaults *)getPreferences;
@end
