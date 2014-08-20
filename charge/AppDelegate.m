#import "AppDelegate.h"
#import "MMDrawerController.h"
#import "MMDrawerVisualState.h"
#import "MapController.h"

@implementation AppDelegate

+ (NSUserDefaults *)getPreferences {
    static NSUserDefaults *prefs = nil;
    if (prefs == nil) {
        prefs = [NSUserDefaults standardUserDefaults];
        [prefs registerDefaults:@{
            @"chargepoint": @YES,
            @"blink": @YES,
            @"level1": @YES,
            @"level2": @YES,
            @"level3": @NO,
            @"unavailable": @YES,
            @"optFavorites": @NO,
            @"latitude": @38,
            @"longitude": @-96,
            @"zoom": @3}];
    }
    return prefs;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GMSServices provideAPIKey:@"AIzaSyCuig7Cfq3ums6j8nOkHmTWthrvhM6ZaWc"];
    
    MMDrawerController *drawerController = (MMDrawerController *)self.window.rootViewController;
    [drawerController setMaximumRightDrawerWidth:200.0];
    [drawerController setShouldStretchDrawer:NO];
    [drawerController setOpenDrawerGestureModeMask:MMOpenDrawerGestureModeNone];
    [drawerController setCloseDrawerGestureModeMask:MMCloseDrawerGestureModeAll];
    [drawerController setDrawerVisualStateBlock:[MMDrawerVisualState parallaxVisualStateBlockWithParallaxFactor:2.0]];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application {
    [(MapController *)[((MMDrawerController *)self.window.rootViewController).centerViewController.childViewControllers objectAtIndex:0] saveState];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [(MapController *)[((MMDrawerController *)self.window.rootViewController).centerViewController.childViewControllers objectAtIndex:0] saveState];
}

@end
