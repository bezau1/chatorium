#import <UIKit/UIKit.h>
@interface ChatVC : UIViewController <UITableViewDataSource, UITextFieldDelegate>
- (instancetype)initWithPlatform:(NSString *)platform chat:(NSString *)chat title:(NSString *)title;
@end
