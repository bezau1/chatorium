#import "ChatListVC.h"
#import "ChatVC.h"
#import "Hub.h"
#import "Theme.h"
#import <CoreImage/CoreImage.h>

@implementation ChatListVC { NSArray<NSDictionary *> *_chats; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CHATORIUM";
    self.tableView.backgroundColor = Theme.base;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:CardCell.class forCellReuseIdentifier:@"c"];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:HubDidUpdate object:nil];
    [self reload];
}
// One row per (platform, chat), newest first.
- (void)reload {
    NSMutableDictionary *last = [NSMutableDictionary dictionary];
    for (NSDictionary *m in Hub.shared.messages) last[[NSString stringWithFormat:@"%@|%@", m[@"platform"], m[@"chat"]]] = m;
    _chats = [last.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"time"] compare:a[@"time"]];
    }];
    NSString *qr = Hub.shared.status[@"whatsapp"];
    self.navigationItem.rightBarButtonItem = [qr hasPrefix:@"qr:"]
        ? [[UIBarButtonItem alloc] initWithTitle:@"Link WhatsApp" style:UIBarButtonItemStylePlain target:self action:@selector(showQR)] : nil;
    [self.tableView reloadData];
}
- (void)showQR {
    NSString *code = [Hub.shared.status[@"whatsapp"] substringFromIndex:3];
    CIFilter *f = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [f setValue:[code dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    CIImage *img = [f.outputImage imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = Theme.base;
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageWithCIImage:img]];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.frame = CGRectInset(vc.view.bounds, 20, 80);
    iv.backgroundColor = UIColor.whiteColor; // QR needs light quiet zone to scan
    iv.layer.borderWidth = 2; iv.layer.borderColor = Theme.text.CGColor;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:iv];
    vc.title = @"WhatsApp → Linked devices → Link a device";
    [self.navigationController pushViewController:vc animated:YES];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return _chats.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    CardCell *c = [t dequeueReusableCellWithIdentifier:@"c" forIndexPath:ip];
    NSDictionary *m = _chats[ip.row];
    c.titleLabel.text = [m[@"chatName"] length] ? m[@"chatName"] : m[@"chat"];
    c.bodyLabel.text = m[@"text"];
    c.bodyLabel.numberOfLines = 2;
    c.badgeLabel.text = [NSString stringWithFormat:@" %@ ", [m[@"platform"] uppercaseString]];
    c.badgeLabel.backgroundColor = [Theme colorForPlatform:m[@"platform"]];
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *m = _chats[ip.row];
    [self.navigationController pushViewController:[[ChatVC alloc] initWithPlatform:m[@"platform"] chat:m[@"chat"]
        title:[m[@"chatName"] length] ? m[@"chatName"] : m[@"chat"]] animated:YES];
}
@end
