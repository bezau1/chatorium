#import "AppDelegate.h"
#import "ChatListVC.h"
#import "Hub.h"
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)o {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[ChatListVC new]];
    [self.window makeKeyAndVisible];
    [Hub.shared connect];
    return YES;
}
- (void)applicationWillEnterForeground:(UIApplication *)a { [Hub.shared connect]; }
@end
