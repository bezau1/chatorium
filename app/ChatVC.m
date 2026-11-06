#import "ChatVC.h"
#import "Hub.h"

@implementation ChatVC { NSString *_platform, *_chat; UITableView *_table; UITextField *_field; NSArray *_msgs; }
- (instancetype)initWithPlatform:(NSString *)p chat:(NSString *)c title:(NSString *)t {
    if ((self = [super init])) { _platform = p; _chat = c; self.title = t; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self; _table.allowsSelection = NO;
    _field = [UITextField new];
    _field.borderStyle = UITextBorderStyleRoundedRect; _field.placeholder = @"Message"; _field.delegate = self;
    _field.returnKeyType = UIReturnKeySend;
    for (UIView *v in @[_table, _field]) { v.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:v]; }
    UILayoutGuide *g = self.view.keyboardLayoutGuide ?: self.view.safeAreaLayoutGuide; // iOS 15+
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:_field.topAnchor constant:-8],
        [_field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_field.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [_field.bottomAnchor constraintEqualToAnchor:g.topAnchor constant:-8]]];
    // Call = hand off to the real app (no embedded calling).
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Call" style:UIBarButtonItemStylePlain target:self action:@selector(call)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:HubDidUpdate object:nil];
    [self reload];
}
- (void)reload {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"platform == %@ AND chat == %@", _platform, _chat];
    _msgs = [Hub.shared.messages filteredArrayUsingPredicate:p];
    [_table reloadData];
    if (_msgs.count) [_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_msgs.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return _msgs.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"m"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"m"];
    NSDictionary *m = _msgs[ip.row];
    c.textLabel.numberOfLines = 0;
    c.textLabel.text = m[@"text"];
    c.textLabel.textAlignment = [m[@"fromMe"] boolValue] ? NSTextAlignmentRight : NSTextAlignmentLeft;
    c.textLabel.textColor = [m[@"fromMe"] boolValue] ? UIColor.systemBlueColor : UIColor.labelColor;
    return c;
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (tf.text.length) { [Hub.shared sendText:tf.text toChat:_chat platform:_platform]; tf.text = @""; }
    return NO;
}
// Opens the real app so the call happens there. Chat id -> phone digits where possible.
- (void)call {
    NSString *digits = [[_chat componentsSeparatedByCharactersInSet:[NSCharacterSet.decimalDigitCharacterSet invertedSet]] componentsJoinedByString:@""];
    NSString *url;
    if ([_platform isEqual:@"imessage"])      url = [@"facetime://" stringByAppendingString:_chat];
    else if ([_platform isEqual:@"whatsapp"]) url = [@"whatsapp://send?phone=" stringByAppendingString:digits];
    else                                      url = @"tg://";
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}
@end
