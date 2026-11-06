#import <Foundation/Foundation.h>
extern NSString *const HubDidUpdate; // posted on main queue whenever messages/status change
@interface Hub : NSObject
@property (class, readonly) Hub *shared;
@property (readonly) NSArray<NSDictionary *> *messages;      // oldest first
@property (readonly) NSDictionary<NSString *, NSString *> *status; // platform -> status/qr
- (void)connect;
- (void)sendText:(NSString *)text toChat:(NSString *)chat platform:(NSString *)platform;
@end
