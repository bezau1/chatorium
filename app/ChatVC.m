#import "ChatVC.h"
#import "Hub.h"
#import "Theme.h"

@implementation ChatVC { NSString *_platform, *_chat; UITableView *_table; UITextField *_field; NSArray *_msgs; }
- (instancetype)initWithPlatform:(NSString *)p chat:(NSString *)c title:(NSString *)t {
    if ((self = [super init])) { _platform = p; _chat = c; self.title = t; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Theme.base;
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self; _table.allowsSelection = NO;
    _table.backgroundColor = Theme.base; _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_table registerClass:CardCell.class forCellReuseIdentifier:@"m"];
    _field = [UITextField new];
    _field.borderStyle = UITextBorderStyleNone; _field.delegate = self;
    [Theme box:_field fill:Theme.mantle];
    _field.font = [Theme font:14 bold:NO]; _field.textColor = Theme.text;
    _field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"MESSAGE" attributes:@{NSForegroundColorAttributeName: Theme.overlay0, NSFontAttributeName: [Theme font:14 bold:YES]}];
    _field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)]; _field.leftViewMode = UITextFieldViewModeAlways;
    _field.keyboardAppearance = UIKeyboardAppearanceDark;
    _field.returnKeyType = UIReturnKeySend;
    for (UIView *v in @[_table, _field]) { v.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:v]; }
    UILayoutGuide *g = self.view.keyboardLayoutGuide ?: self.view.safeAreaLayoutGuide; // iOS 15+
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:_field.topAnchor constant:-8],
        [_field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_field.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_field.heightAnchor constraintEqualToConstant:44],
        [_field.bottomAnchor constraintEqualToAnchor:g.topAnchor constant:-12]]];
    // Call = hand off to the real app (no embedded calling).
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"CALL" style:UIBarButtonItemStylePlain target:self action:@selector(call)];
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
    CardCell *c = [t dequeueReusableCellWithIdentifier:@"m" forIndexPath:ip];
    NSDictionary *m = _msgs[ip.row];
    BOOL me = [m[@"fromMe"] boolValue];
    c.badgeLabel.hidden = YES;
    c.titleLabel.hidden = YES;
    c.bodyLabel.text = m[@"text"];
    c.bodyLabel.textColor = me ? Theme.crust : Theme.text;
    c.card.backgroundColor = me ? Theme.mauve : Theme.surface0; // mine = mauve, theirs = surface
    c.card.layer.borderColor = (me ? Theme.crust : Theme.text).CGColor;
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
