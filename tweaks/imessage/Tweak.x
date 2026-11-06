// iMessage connector. Lives in SpringBoard (always running) so no Mac relay is needed.
//  incoming: polls /var/mobile/Library/SMS/sms.db for new rows (stable across iOS versions)
//  outgoing: sends through IMCore's IMChatRegistry (the same path Messages.app uses)
// Talks to chatoriumd over 127.0.0.1:47474 using newline-delimited JSON.
#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <dlfcn.h>
#import <unistd.h>

@interface IMChat : NSObject
- (void)sendMessage:(id)message;
@end
@interface IMChatRegistry : NSObject
+ (instancetype)sharedInstance;
- (IMChat *)existingChatWithChatIdentifier:(NSString *)ident;
- (IMChat *)chatForIMHandle:(id)handle;
@end
@interface IMAccountController : NSObject
+ (instancetype)sharedInstance;
- (id)__ck_defaultAccountForService:(id)service;
@end
@interface IMServiceImpl : NSObject
+ (id)iMessageService;
+ (id)smsService;
@end
@interface IMHandle : NSObject
- (instancetype)initWithAccount:(id)account ID:(NSString *)ident alreadyCanonical:(BOOL)c;
@end
@interface IMMessage : NSObject
+ (instancetype)instantMessageWithText:(NSAttributedString *)text flags:(unsigned long long)flags;
@end

static int g_fd = -1;
static NSString *const kDB = @"/var/mobile/Library/SMS/sms.db";

static void sendFrame(NSDictionary *f) {
    if (g_fd < 0) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:f options:0 error:nil];
    NSMutableData *line = [d mutableCopy];
    [line appendBytes:"\n" length:1];
    if (write(g_fd, line.bytes, line.length) < 0) { close(g_fd); g_fd = -1; }
}

static void doSend(NSString *chat, NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IMChat *c = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:chat];
        if (!c) { // no existing thread: open one to this address over iMessage
            id svc = [%c(IMServiceImpl) iMessageService];
            id acct = [[%c(IMAccountController) sharedInstance] __ck_defaultAccountForService:svc];
            id h = [[%c(IMHandle) alloc] initWithAccount:acct ID:chat alreadyCanonical:NO];
            c = [[%c(IMChatRegistry) sharedInstance] chatForIMHandle:h];
        }
        // flags 0x5 = finished + from me, as used by ChatKit when composing
        IMMessage *m = [%c(IMMessage) instantMessageWithText:[[NSAttributedString alloc] initWithString:text] flags:0x100005];
        [c sendMessage:m];
    });
}

static void readLoop(int fd) {
    NSMutableData *buf = [NSMutableData data];
    char tmp[4096]; ssize_t n;
    while ((n = read(fd, tmp, sizeof tmp)) > 0) {
        [buf appendBytes:tmp length:n];
        for (;;) {
            NSRange r = [buf rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, buf.length)];
            if (r.location == NSNotFound) break;
            NSData *line = [buf subdataWithRange:NSMakeRange(0, r.location)];
            [buf replaceBytesInRange:NSMakeRange(0, r.location + 1) withBytes:NULL length:0];
            NSDictionary *f = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
            if ([f[@"op"] isEqual:@"send"]) doSend(f[@"chat"], f[@"text"]);
        }
    }
}

static BOOL connectHub(void) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a = { .sin_len = sizeof a, .sin_family = AF_INET, .sin_port = htons(47474) };
    inet_pton(AF_INET, "127.0.0.1", &a.sin_addr);
    if (connect(fd, (void *)&a, sizeof a) != 0) { close(fd); return NO; }
    g_fd = fd;
    sendFrame(@{@"op": @"hello", @"role": @"connector", @"platform": @"imessage"});
    return YES;
}

static void pollMessages(sqlite3_int64 *last) {
    sqlite3 *db;
    if (sqlite3_open_v2(kDB.UTF8String, &db, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) return;
    const char *sql =
        "SELECT m.ROWID, m.guid, COALESCE(m.text,''), m.is_from_me, m.date, "
        "COALESCE(c.chat_identifier,''), COALESCE(c.display_name,''), COALESCE(h.id,'') "
        "FROM message m "
        "LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID "
        "LEFT JOIN chat c ON c.ROWID = cmj.chat_id "
        "LEFT JOIN handle h ON h.ROWID = m.handle_id "
        "WHERE m.ROWID > ? ORDER BY m.ROWID";
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, *last);
        while (sqlite3_step(st) == SQLITE_ROW) {
            *last = sqlite3_column_int64(st, 0);
            NSString *text = @((const char *)sqlite3_column_text(st, 2));
            if (!text.length) continue; // attachments / tapbacks not handled yet
            double date = sqlite3_column_double(st, 4); // ns since 2001 on modern iOS
            if (date > 1e12) date /= 1e9;
            NSString *chat = @((const char *)sqlite3_column_text(st, 5));
            NSString *name = @((const char *)sqlite3_column_text(st, 6));
            sendFrame(@{@"op": @"ingest", @"message": @{
                @"id": @((const char *)sqlite3_column_text(st, 1)), @"platform": @"imessage",
                @"chat": chat, @"chatName": name.length ? name : chat,
                @"sender": @((const char *)sqlite3_column_text(st, 7)),
                @"fromMe": @(sqlite3_column_int(st, 3) != 0), @"text": text,
                @"time": @((long long)(date + 978307200.0))}});
        }
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
}

static sqlite3_int64 currentMaxRowID(void) {
    sqlite3 *db; sqlite3_int64 v = 0;
    if (sqlite3_open_v2(kDB.UTF8String, &db, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        sqlite3_stmt *st;
        if (sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(ROWID),0) FROM message", -1, &st, NULL) == SQLITE_OK
            && sqlite3_step(st) == SQLITE_ROW) v = sqlite3_column_int64(st, 0);
        sqlite3_finalize(st);
    }
    sqlite3_close(db);
    return v;
}

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        dlopen("/System/Library/PrivateFrameworks/IMCore.framework/IMCore", RTLD_NOW);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            sqlite3_int64 last = currentMaxRowID(); // start from "now": history isn't back-filled
            for (;;) {
                if (g_fd < 0) {
                    if (connectHub()) {
                        int fd = g_fd;
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ readLoop(fd); close(fd); if (g_fd == fd) g_fd = -1; });
                    }
                }
                if (g_fd >= 0) pollMessages(&last);
                sleep(2);
            }
        });
    }
}
