#import "Hub.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

NSString *const HubDidUpdate = @"HubDidUpdate";

@implementation Hub { int _fd; NSMutableArray *_messages; NSMutableDictionary *_status; }
+ (Hub *)shared { static Hub *h; static dispatch_once_t t; dispatch_once(&t, ^{ h = [Hub new]; }); return h; }
- (instancetype)init { if ((self = [super init])) { _fd = -1; _messages = [NSMutableArray array]; _status = [NSMutableDictionary dictionary]; } return self; }
- (NSArray *)messages { return [_messages copy]; }
- (NSDictionary *)status { return [_status copy]; }

- (void)writeFrame:(NSDictionary *)f {
    NSMutableData *d = [[NSJSONSerialization dataWithJSONObject:f options:0 error:nil] mutableCopy];
    [d appendBytes:"\n" length:1];
    if (_fd >= 0) write(_fd, d.bytes, d.length);
}

- (void)connect {
    if (_fd >= 0) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in a = { .sin_len = sizeof a, .sin_family = AF_INET, .sin_port = htons(47474) };
        inet_pton(AF_INET, "127.0.0.1", &a.sin_addr);
        if (connect(fd, (void *)&a, sizeof a) != 0) { close(fd); return; }
        self->_fd = fd;
        [self writeFrame:@{@"op": @"hello", @"role": @"ui"}];
        [self writeFrame:@{@"op": @"history"}];
        [self readLoop:fd];
    });
}

- (void)readLoop:(int)fd {
    NSMutableData *buf = [NSMutableData data]; char tmp[8192]; ssize_t n;
    while ((n = read(fd, tmp, sizeof tmp)) > 0) {
        [buf appendBytes:tmp length:n];
        for (;;) {
            NSRange r = [buf rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, buf.length)];
            if (r.location == NSNotFound) break;
            NSData *line = [buf subdataWithRange:NSMakeRange(0, r.location)];
            [buf replaceBytesInRange:NSMakeRange(0, r.location + 1) withBytes:NULL length:0];
            NSDictionary *f = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
            if (f) dispatch_async(dispatch_get_main_queue(), ^{ [self handle:f]; });
        }
    }
    close(fd);
    dispatch_async(dispatch_get_main_queue(), ^{ if (self->_fd == fd) self->_fd = -1; });
}

- (void)handle:(NSDictionary *)f {
    NSString *op = f[@"op"];
    if ([op isEqual:@"history"]) { [_messages setArray:f[@"messages"] ?: @[]]; }
    else if ([op isEqual:@"message"]) { [_messages addObject:f[@"message"]]; }
    else if ([op isEqual:@"status"]) { _status[f[@"platform"]] = f[@"data"] ?: @""; }
    [NSNotificationCenter.defaultCenter postNotificationName:HubDidUpdate object:nil];
}

- (void)sendText:(NSString *)text toChat:(NSString *)chat platform:(NSString *)platform {
    [self writeFrame:@{@"op": @"send", @"platform": platform, @"chat": chat, @"text": text}];
    // optimistic local echo; the platform's own echo is deduped by the hub when it has an id
    [_messages addObject:@{@"id": @"", @"platform": platform, @"chat": chat, @"fromMe": @YES,
                           @"text": text, @"time": @((long long)NSDate.date.timeIntervalSince1970)}];
    [NSNotificationCenter.defaultCenter postNotificationName:HubDidUpdate object:nil];
}
@end
