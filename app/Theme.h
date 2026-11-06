// Catppuccin Mocha + hard-edged "brutalist" look: square corners, borders, offset solid shadows.
#import <UIKit/UIKit.h>

@interface Theme : NSObject
@property (class, readonly) UIColor *base, *mantle, *crust, *surface0, *surface1, *surface2,
    *overlay0, *text, *subtext0, *mauve, *blue, *green, *peach, *pink, *red, *lavender;
+ (UIFont *)font:(CGFloat)size bold:(BOOL)bold;     // monospaced
+ (void)box:(UIView *)v fill:(UIColor *)fill;        // square, 2pt border, 4pt hard shadow
+ (UIColor *)colorForPlatform:(NSString *)platform;
+ (void)applyGlobalAppearance;
@end

// A bordered square card with a hard drop shadow, used for chat rows and message bubbles.
@interface CardCell : UITableViewCell
@property (readonly) UIView *card;
@property (readonly) UILabel *titleLabel, *bodyLabel, *badgeLabel;
@end
