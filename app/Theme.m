#import "Theme.h"

#define HEX(h) [UIColor colorWithRed:((h >> 16) & 0xFF) / 255.0 green:((h >> 8) & 0xFF) / 255.0 blue:(h & 0xFF) / 255.0 alpha:1]

@implementation Theme
+ (UIColor *)base     { return HEX(0x1e1e2e); }
+ (UIColor *)mantle   { return HEX(0x181825); }
+ (UIColor *)crust    { return HEX(0x11111b); }
+ (UIColor *)surface0 { return HEX(0x313244); }
+ (UIColor *)surface1 { return HEX(0x45475a); }
+ (UIColor *)surface2 { return HEX(0x585b70); }
+ (UIColor *)overlay0 { return HEX(0x6c7086); }
+ (UIColor *)text     { return HEX(0xcdd6f4); }
+ (UIColor *)subtext0 { return HEX(0xa6adc8); }
+ (UIColor *)mauve    { return HEX(0xcba6f7); }
+ (UIColor *)blue     { return HEX(0x89b4fa); }
+ (UIColor *)green    { return HEX(0xa6e3a1); }
+ (UIColor *)peach    { return HEX(0xfab387); }
+ (UIColor *)pink     { return HEX(0xf5c2e7); }
+ (UIColor *)red      { return HEX(0xf38ba8); }
+ (UIColor *)lavender { return HEX(0xb4befe); }

+ (UIFont *)font:(CGFloat)size bold:(BOOL)bold {
    return [UIFont monospacedSystemFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular];
}

+ (void)box:(UIView *)v fill:(UIColor *)fill {
    v.backgroundColor = fill;
    v.layer.cornerRadius = 0;
    v.layer.borderWidth = 2;
    v.layer.borderColor = Theme.text.CGColor;
    v.layer.masksToBounds = NO;                 // let the shadow escape
    v.layer.shadowColor = Theme.crust.CGColor;
    v.layer.shadowOffset = CGSizeMake(4, 4);
    v.layer.shadowRadius = 0;                   // radius 0 => hard, square shadow
    v.layer.shadowOpacity = 1;
}

+ (UIColor *)colorForPlatform:(NSString *)p {
    if ([p isEqual:@"imessage"]) return Theme.blue;
    if ([p isEqual:@"whatsapp"]) return Theme.green;
    if ([p isEqual:@"telegram"]) return Theme.lavender;
    return Theme.peach;
}

+ (void)applyGlobalAppearance {
    UINavigationBarAppearance *a = [UINavigationBarAppearance new];
    [a configureWithOpaqueBackground];
    a.backgroundColor = Theme.mantle;
    a.shadowColor = Theme.text; // 1px bottom border
    a.titleTextAttributes = @{NSForegroundColorAttributeName: Theme.text, NSFontAttributeName: [Theme font:17 bold:YES]};
    a.largeTitleTextAttributes = a.titleTextAttributes;
    UINavigationBar.appearance.standardAppearance = a;
    UINavigationBar.appearance.scrollEdgeAppearance = a;
    UINavigationBar.appearance.tintColor = Theme.mauve;
    UITextField.appearance.tintColor = Theme.mauve;
}
@end

@implementation CardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:r])) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [UIView new];
        [Theme box:_card fill:Theme.surface0];
        _badgeLabel = [UILabel new];
        _badgeLabel.font = [Theme font:10 bold:YES];
        _badgeLabel.textColor = Theme.crust;
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.borderWidth = 2; _badgeLabel.layer.borderColor = Theme.crust.CGColor;
        _titleLabel = [UILabel new]; _titleLabel.font = [Theme font:14 bold:YES]; _titleLabel.textColor = Theme.text;
        _bodyLabel = [UILabel new];  _bodyLabel.font = [Theme font:13 bold:NO];  _bodyLabel.textColor = Theme.subtext0;
        _bodyLabel.numberOfLines = 0;
        UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:@[_badgeLabel, _titleLabel, _bodyLabel]];
        col.axis = UILayoutConstraintAxisVertical; col.spacing = 4; col.alignment = UIStackViewAlignmentLeading;
        for (UIView *v in @[_card, col]) v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];
        [_card addSubview:col];
        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10], // room for shadow
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [col.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
            [col.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-10],
            [col.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:10],
            [col.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-10]]];
    }
    return self;
}
@end
