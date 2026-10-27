/*
 * The app's own main menu, over DOOM 3's, laid out for the phone: the whole
 * screen, big buttons. On the left the game's name and CONTINUE (the newest
 * saved game, its screenshot); on the right its buttons, and the page each
 * opens in their place -- NEW GAME's difficulties, LOAD GAME's saves, GAMES
 * (DOOM 3, Resurrection of Evil, co-op), SETTINGS. Over a game in play:
 * RESUME, SAVE GAME, LOAD GAME, SETTINGS, MAIN MENU.
 *
 * DOOM 3's own menu stays under it: MULTIPLAYER and SETTINGS' "DOOM 3
 * settings" press its buttons and show it, a button in its corner comes
 * back; and SETTINGS can have it instead, for good (the same button turns
 * this one back on). What it asks of the engine: sys/ios/ios_menu.h.
 *
 * It's a view under the touch controls' (ios/IOSTouch.m), which lets its
 * touches through over the menus.
 *
 * Compiled with ARC.
 */

#import <UIKit/UIKit.h>
#include <math.h>

#include "sys/ios/ios_menu.h"
#include "sys/ios/ios_touch.h"

// The settings, as the app keeps them
#define IOSMENU_CLASSIC_DEFAULTS_KEY @"iosMenuClassic"	// DOOM 3's own menu instead
#define IOSMENU_INTRO_DEFAULTS_KEY @"iosMenuPlayIntro"	// the intro videos as the game starts
#define IOSMENU_FOV_DEFAULTS_KEY @"iosMenuFov"			// g_fov (the game doesn't keep it)
// The buttons: this tall, this far apart, this wide; the column's top
#define IOSMENU_BUTTON_H 46.0
#define IOSMENU_BUTTON_GAP 8.0
#define IOSMENU_COLUMN_W 290.0
#define IOSMENU_MARGIN 24.0

static UIColor* IOSMenu_Orange(CGFloat a) { return [UIColor colorWithRed:1.0 green:0.55 blue:0.2 alpha:a]; }
static UIColor* IOSMenu_Red(CGFloat a) { return [UIColor colorWithRed:0.62 green:0.1 blue:0.06 alpha:a]; }

int IOS_PlayIntro(void)
{
	NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
	return [d objectForKey:IOSMENU_INTRO_DEFAULTS_KEY] ? [d boolForKey:IOSMENU_INTRO_DEFAULTS_KEY] : 1;
}

// ---------------------------------------------------------------- a saved game's screenshot

// The TGA the game writes beside a saved game (uncompressed or RLE, 24 or 32
// bits), as an image
static UIImage* IOSMenu_LoadTGA(NSString* path)
{
	NSData* data = [NSData dataWithContentsOfFile:path];
	const unsigned char* p = data.bytes;
	if (data.length < 18) return nil;
	int idLen = p[0], type = p[2], w = p[12] | (p[13] << 8), h = p[14] | (p[15] << 8), bpp = p[16], desc = p[17];
	if ((type != 2 && type != 10) || (bpp != 24 && bpp != 32) || w <= 0 || h <= 0 || w > 4096 || h > 4096) return nil;
	int bytes = bpp / 8;
	const unsigned char* src = p + 18 + idLen;
	const unsigned char* end = p + data.length;
	NSMutableData* rgba = [NSMutableData dataWithLength:(NSUInteger)w * h * 4];
	unsigned char* out = rgba.mutableBytes;
	int topDown = (desc & 0x20) != 0;
	int n = 0, total = w * h;
	unsigned char px[4] = { 0, 0, 0, 255 };
	while (n < total) {
		int count = 1, raw = 1;
		if (type == 10) {
			if (src >= end) return nil;
			count = (*src & 0x7f) + 1;
			raw = !(*src & 0x80);
			src++;
		}
		for (int i = 0; i < count && n < total; i++, n++) {
			if (raw || i == 0) {
				if (src + bytes > end) return nil;
				px[2] = src[0]; px[1] = src[1]; px[0] = src[2]; px[3] = bytes == 4 ? src[3] : 255;
				src += bytes;
			}
			int x = n % w, y = n / w;
			int row = topDown ? y : h - 1 - y;
			unsigned char* o = out + ((size_t)row * w + x) * 4;
			o[0] = px[0]; o[1] = px[1]; o[2] = px[2]; o[3] = 255;
		}
	}
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef dp = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgba);
	CGImageRef img = CGImageCreate(w, h, 8, 32, w * 4, cs, kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast, dp, NULL, NO, kCGRenderingIntentDefault);
	UIImage* image = img ? [UIImage imageWithCGImage:img] : nil;
	CGImageRelease(img);
	CGDataProviderRelease(dp);
	CGColorSpaceRelease(cs);
	return image;
}

static NSString* IOSMenu_When(long long t)
{
	NSDate* date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)t];
	NSDateFormatter* f = [[NSDateFormatter alloc] init];
	f.doesRelativeDateFormatting = YES;
	f.dateStyle = NSDateFormatterMediumStyle;
	f.timeStyle = NSDateFormatterShortStyle;
	return [f stringFromDate:date];
}

// ---------------------------------------------------------------- a button

@interface IOSMenuButton : UIButton
@property (nonatomic, copy) void (^action)(void);
@end

@implementation IOSMenuButton

+ (instancetype)buttonTitled:(NSString*)title detail:(NSString*)detail action:(void (^)(void))action
{
	IOSMenuButton* b = [IOSMenuButton buttonWithType:UIButtonTypeCustom];
	b.action = action;
	b.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.1 alpha:0.92];
	b.layer.cornerRadius = 10.0;
	b.layer.borderWidth = 1.0;
	b.layer.borderColor = IOSMenu_Orange(0.35).CGColor;
	b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
	b.titleLabel.numberOfLines = 2;
	NSMutableAttributedString* t = [[NSMutableAttributedString alloc] initWithString:title attributes:@{
		NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy],
		NSForegroundColorAttributeName: UIColor.whiteColor,
		NSKernAttributeName: @2.0 }];
	if (detail.length) {
		[t appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:detail] attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.55] }]];
	}
	[b setAttributedTitle:t forState:UIControlStateNormal];
	b.contentEdgeInsets = UIEdgeInsetsMake(0, 22, 0, 12);
	// the accent down its left edge
	UIView* bar = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 3, 26)];
	bar.backgroundColor = IOSMenu_Orange(0.9);
	bar.layer.cornerRadius = 1.5;
	bar.userInteractionEnabled = NO;
	bar.tag = 7;
	[b addSubview:bar];
	[b addTarget:b action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
	[b addTarget:b action:@selector(down) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
	[b addTarget:b action:@selector(up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside
		| UIControlEventTouchDragExit | UIControlEventTouchCancel];
	return b;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	[self viewWithTag:7].frame = CGRectMake(0, 10, 3, self.bounds.size.height - 20);
}

- (void)down
{
	self.backgroundColor = IOSMenu_Red(0.95);
	self.layer.borderColor = IOSMenu_Orange(0.9).CGColor;
}

- (void)up
{
	self.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.1 alpha:0.92];
	self.layer.borderColor = IOSMenu_Orange(0.35).CGColor;
}

- (void)tapped
{
	[[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
	if (self.action) self.action();
}

@end

// ---------------------------------------------------------------- the menu

typedef enum { PAGE_MAIN = 0, PAGE_NEWGAME, PAGE_LOAD, PAGE_GAMES, PAGE_SETTINGS } iosMenuPage_t;

@interface IOSMenuView : UIView
@property (nonatomic) BOOL classicNow;	// DOOM 3's own menu showing for now (its multiplayer, its settings)
- (void)frame:(int)bOverMenus;
@end

@implementation IOSMenuView {
	CAGradientLayer*	background;
	UILabel*			title;
	UILabel*			subtitle;
	UIView*				continueCard;
	UIImageView*		continueShot;
	UILabel*			continueText;
	UIScrollView*		page;			// the right side: the buttons, or a page in their place
	UIStackView*		stack;
	iosMenuPage_t		pageShown;
	int					bInGame;
	int					gameKind;
	UIButton*			backToMenu;		// over DOOM 3's own menu: back to this one
	iosMenuSave_t		aSaves[IOS_MENU_MAX_SAVES];
	int					numSaves;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (!self) return nil;
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.backgroundColor = UIColor.blackColor;

	background = [CAGradientLayer layer];
	background.colors = @[ (id)[UIColor colorWithRed:0.10 green:0.04 blue:0.03 alpha:1.0].CGColor,
						   (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.02 alpha:1.0].CGColor ];
	background.startPoint = CGPointMake(0.0, 0.0);
	background.endPoint = CGPointMake(0.8, 1.0);
	[self.layer addSublayer:background];

	title = [[UILabel alloc] init];
	title.font = [UIFont systemFontOfSize:64 weight:UIFontWeightBlack width:UIFontWidthCompressed];
	title.adjustsFontSizeToFitWidth = YES;
	title.minimumScaleFactor = 0.5;
	title.text = @"DOOM 3";
	title.layer.shadowColor = IOSMenu_Red(1.0).CGColor;
	title.layer.shadowRadius = 14.0;
	title.layer.shadowOpacity = 0.8;
	title.layer.shadowOffset = CGSizeZero;
	[self addSubview:title];
	subtitle = [[UILabel alloc] init];
	subtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
	subtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
	[self addSubview:subtitle];

	// CONTINUE: the newest saved game
	continueCard = [[UIView alloc] init];
	continueCard.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.1 alpha:0.92];
	continueCard.layer.cornerRadius = 12.0;
	continueCard.layer.borderWidth = 1.0;
	continueCard.layer.borderColor = IOSMenu_Orange(0.35).CGColor;
	continueCard.clipsToBounds = YES;
	[continueCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(continueTapped)]];
	continueShot = [[UIImageView alloc] init];
	continueShot.contentMode = UIViewContentModeScaleAspectFill;
	continueShot.clipsToBounds = YES;
	continueShot.backgroundColor = UIColor.blackColor;
	[continueCard addSubview:continueShot];
	continueText = [[UILabel alloc] init];
	continueText.numberOfLines = 3;
	[continueCard addSubview:continueText];
	[self addSubview:continueCard];

	page = [[UIScrollView alloc] init];
	page.showsVerticalScrollIndicator = NO;
	page.alwaysBounceVertical = NO;
	[self addSubview:page];
	stack = [[UIStackView alloc] init];
	stack.axis = UILayoutConstraintAxisVertical;
	stack.spacing = IOSMENU_BUTTON_GAP;
	[page addSubview:stack];

	// the game keeps no field of view: the menu's, again as the game starts
	NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
	if ([d objectForKey:IOSMENU_FOV_DEFAULTS_KEY]) {
		IOS_SetCVar("g_fov", [NSString stringWithFormat:@"%d", (int)[d integerForKey:IOSMENU_FOV_DEFAULTS_KEY]].UTF8String);
	}
	return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect b = self.bounds;
	UIEdgeInsets in = self.safeAreaInsets;
	CGFloat left = fmax(in.left, IOSMENU_MARGIN), right = b.size.width - fmax(in.right, IOSMENU_MARGIN);
	CGFloat top = fmax(in.top, 16.0), bottom = b.size.height - fmax(in.bottom, 12.0);
	background.frame = b;

	// the right: the column, as wide as it can be up to IOSMENU_COLUMN_W (a
	// page's list wider)
	CGFloat colW = fmin(pageShown == PAGE_LOAD || pageShown == PAGE_GAMES || pageShown == PAGE_SETTINGS ? 380.0 : IOSMENU_COLUMN_W,
						(right - left) * 0.55);
	page.frame = CGRectMake(right - colW, top, colW, bottom - top);
	[self layoutStack];

	// the left: the name, CONTINUE under it
	CGFloat leftW = right - colW - left - IOSMENU_MARGIN;
	title.frame = CGRectMake(left, top, leftW, 70);
	subtitle.frame = CGRectMake(left + 2, top + 68, leftW, 16);
	CGFloat cardY = top + 100;
	CGFloat cardH = fmin(bottom - cardY, leftW * 0.75 * 0.62 + 64.0);
	continueCard.frame = CGRectMake(left, cardY, fmin(leftW, 330.0), cardH);
	CGFloat shotH = cardH - 64.0;
	continueShot.frame = CGRectMake(0, 0, continueCard.bounds.size.width, shotH);
	continueText.frame = CGRectMake(14, shotH + 6, continueCard.bounds.size.width - 28, 52);
}

// the column's buttons, from its top (centred while they fit)
- (void)layoutStack
{
	CGFloat w = page.bounds.size.width;
	CGSize fit = [stack systemLayoutSizeFittingSize:CGSizeMake(w, UILayoutFittingCompressedSize.height)
					   withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
	CGFloat h = fit.height;
	CGFloat y = fmax(0.0, (page.bounds.size.height - h) * 0.5);
	stack.frame = CGRectMake(0, y, w, h);
	page.contentSize = CGSizeMake(w, fmax(h, page.bounds.size.height));
}

// ------------------------------------------------ what it shows

- (void)titleFor:(int)kind
{
	// the name in DOOM 3's orange, fading to its red
	CGFloat h = 70.0;
	UIGraphicsImageRenderer* r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(4, h)];
	UIImage* grad = [r imageWithActions:^(UIGraphicsImageRendererContext* ctx) {
		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
		NSArray* colours = @[ (id)[UIColor colorWithRed:1.0 green:0.78 blue:0.35 alpha:1].CGColor,
							  (id)[UIColor colorWithRed:0.85 green:0.25 blue:0.08 alpha:1].CGColor ];
		CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colours, NULL);
		CGContextDrawLinearGradient(ctx.CGContext, g, CGPointMake(0, 12), CGPointMake(0, h - 10), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
		CGGradientRelease(g);
		CGColorSpaceRelease(cs);
	}];
	title.textColor = [UIColor colorWithPatternImage:grad];
	static NSString* const aSub[] = { @"", @"RESURRECTION OF EVIL", @"CO-OP" };
	NSString* sub = aSub[kind < 0 || kind > 2 ? 0 : kind];
	subtitle.attributedText = [[NSAttributedString alloc] initWithString:sub attributes:@{ NSKernAttributeName: @4.0 }];
}

- (void)refresh
{
	bInGame = IOS_MenuInGame();
	gameKind = IOS_MenuGameKind();
	[self titleFor:gameKind];
	numSaves = gameKind == 2 ? 0 : IOS_MenuSaves(aSaves, IOS_MENU_MAX_SAVES);
	continueCard.hidden = bInGame || numSaves == 0;
	if (!continueCard.hidden) {
		const iosMenuSave_t* s = &aSaves[0];
		continueShot.image = IOSMenu_LoadTGA([NSString stringWithUTF8String:s->shot]);
		NSMutableAttributedString* t = [[NSMutableAttributedString alloc] initWithString:@"CONTINUE\n" attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightHeavy],
			NSForegroundColorAttributeName: IOSMenu_Orange(1.0), NSKernAttributeName: @2.0 }];
		NSString* line = [NSString stringWithFormat:@"%s\n%@", s->level[0] ? s->level : s->title, IOSMenu_When(s->time)];
		[t appendAttributedString:[[NSAttributedString alloc] initWithString:line attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightMedium],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.75] }]];
		continueText.attributedText = t;
	}
	[self showPage:PAGE_MAIN];
}

- (void)clearPage
{
	for (UIView* v in stack.arrangedSubviews) {
		[stack removeArrangedSubview:v];
		[v removeFromSuperview];
	}
}

- (void)addButton:(NSString*)t detail:(NSString*)detail action:(void (^)(void))action
{
	IOSMenuButton* b = [IOSMenuButton buttonTitled:t detail:detail action:action];
	[b.heightAnchor constraintEqualToConstant:(detail.length ? IOSMENU_BUTTON_H + 10.0 : IOSMENU_BUTTON_H)].active = YES;
	[stack addArrangedSubview:b];
}

- (void)addHeading:(NSString*)t
{
	UILabel* l = [[UILabel alloc] init];
	l.attributedText = [[NSAttributedString alloc] initWithString:t attributes:@{
		NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy],
		NSForegroundColorAttributeName: IOSMenu_Orange(0.9), NSKernAttributeName: @3.0 }];
	[l.heightAnchor constraintEqualToConstant:24.0].active = YES;
	[stack addArrangedSubview:l];
}

- (void)addBack
{
	__weak IOSMenuView* weak = self;
	[self addButton:@"‹  BACK" detail:nil action:^{ [weak showPage:PAGE_MAIN]; }];
}

- (void)showPage:(iosMenuPage_t)p
{
	pageShown = p;
	[self clearPage];
	__weak IOSMenuView* weak = self;
	switch (p) {
	case PAGE_MAIN: {
		if (bInGame) {
			[self addButton:@"RESUME" detail:nil action:^{ IOS_ResumeGame(); }];
			[self addButton:@"SAVE GAME" detail:nil action:^{ [weak saveGame]; }];
		}
		if (gameKind != 2) {
			if (!bInGame) [self addButton:@"NEW GAME" detail:nil action:^{ [weak showPage:PAGE_NEWGAME]; }];
			[self addButton:@"LOAD GAME" detail:nil action:^{ [weak showPage:PAGE_LOAD]; }];
		}
		if (!bInGame) {
			[self addButton:@"MULTIPLAYER" detail:(gameKind == 2 ? @"Co-op and Survival" : nil) action:^{ [weak classic:@"MULTIPLAYER"]; }];
			[self addButton:@"GAMES" detail:nil action:^{ [weak showPage:PAGE_GAMES]; }];
		}
		[self addButton:@"SETTINGS" detail:nil action:^{ [weak showPage:PAGE_SETTINGS]; }];
		if (bInGame) [self addButton:@"MAIN MENU" detail:nil action:^{ IOS_MenuQuitToMain(); }];
		break;
	}

	case PAGE_NEWGAME: {
		[self addHeading:@"NEW GAME"];
		static NSString* const aName[] = { @"RECRUIT", @"MARINE", @"VETERAN", @"NIGHTMARE" };
		static NSString* const aDetail[] = { @"New to shooters", @"The standard challenge", @"For seasoned players",
											 @"Health drains away. For the brave" };
		int num = IOS_MenuNightmare() ? 4 : 3;
		for (int i = 0; i < num; i++) {
			int skill = i;
			[self addButton:aName[i] detail:aDetail[i] action:^{ IOS_MenuNewGame(skill); }];
		}
		[self addBack];
		break;
	}

	case PAGE_LOAD: {
		[self addHeading:@"LOAD GAME"];
		if (numSaves == 0) [self addHeading:@"NO SAVED GAMES YET"];
		for (int i = 0; i < numSaves; i++) {
			const iosMenuSave_t* s = &aSaves[i];
			NSString* file = [NSString stringWithUTF8String:s->file];
			NSString* t = [[NSString stringWithUTF8String:(s->level[0] ? s->level : s->title)] uppercaseString];
			[self addButton:t detail:IOSMenu_When(s->time) action:^{ IOS_MenuLoadGame(file.UTF8String); }];
		}
		[self addBack];
		break;
	}

	case PAGE_GAMES: {
		[self addHeading:@"GAMES"];
		iosMenuMod_t aMods[IOS_MENU_MAX_MODS];
		int current = 0;
		int num = IOS_MenuMods(aMods, IOS_MENU_MAX_MODS, &current);
		for (int i = 0; i < num; i++) {
			NSString* dir = [NSString stringWithUTF8String:aMods[i].dir];
			NSString* t = [[NSString stringWithUTF8String:aMods[i].title] uppercaseString];
			[self addButton:t detail:(i == current ? @"Playing now" : nil) action:^{
				if (i != current) IOS_MenuSwitchGame(dir.UTF8String);
			}];
		}
		[self addBack];
		break;
	}

	case PAGE_SETTINGS: {
		[self addHeading:@"SETTINGS"];
		[self addSlider:@"BRIGHTNESS" min:0.5 max:2.0 value:IOS_CVarFloat("r_brightness") format:@"%.2f" change:^(float v) {
			IOS_SetCVar("r_brightness", [NSString stringWithFormat:@"%.2f", v].UTF8String);
		}];
		[self addSlider:@"FIELD OF VIEW" min:80 max:110 value:IOS_CVarFloat("g_fov") format:@"%.0f°" change:^(float v) {
			IOS_SetCVar("g_fov", [NSString stringWithFormat:@"%d", (int)lroundf(v)].UTF8String);
			[[NSUserDefaults standardUserDefaults] setInteger:lroundf(v) forKey:IOSMENU_FOV_DEFAULTS_KEY];
		}];
		[self addSlider:@"VOLUME" min:0 max:100 value:powf(10.0f, IOS_CVarFloat("s_volume_dB") / 20.0f) * 100.0f format:@"%.0f%%" change:^(float v) {
			float dB = v <= 0.5f ? -40.0f : fmaxf(-40.0f, 20.0f * log10f(v / 100.0f));
			IOS_SetCVar("s_volume_dB", [NSString stringWithFormat:@"%.1f", dB].UTF8String);
		}];
		[self addSlider:@"LOOK SPEED" min:0.5 max:2.0 value:IOSTouch_LookScale() format:@"%.2fx" change:^(float v) {
			IOSTouch_SetLookScale(v);
		}];
		[self addSwitch:@"PLAY INTRO AT START" on:IOS_PlayIntro() change:^(BOOL on) {
			[[NSUserDefaults standardUserDefaults] setBool:on forKey:IOSMENU_INTRO_DEFAULTS_KEY];
		}];
		[self addSwitch:@"USE DOOM 3'S OWN MENU" on:NO change:^(BOOL on) {
			if (!on) return;
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:IOSMENU_CLASSIC_DEFAULTS_KEY];
			[weak showPage:PAGE_MAIN];
		}];
		[self addButton:@"MORE DOOM 3 SETTINGS" detail:@"Its own menu: controls, sound, video" action:^{ [weak classic:@"OPTIONS"]; }];
		[self addBack];
		break;
	}
	}
	[self setNeedsLayout];
	[self layoutIfNeeded];
	[page setContentOffset:CGPointZero animated:NO];
}

// ------------------------------------------------ a page's controls

- (UIView*)rowTitled:(NSString*)t height:(CGFloat)h
{
	UIView* row = [[UIView alloc] init];
	row.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.1 alpha:0.92];
	row.layer.cornerRadius = 10.0;
	row.layer.borderWidth = 1.0;
	row.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
	[row.heightAnchor constraintEqualToConstant:h].active = YES;
	UILabel* l = [[UILabel alloc] init];
	l.translatesAutoresizingMaskIntoConstraints = NO;
	l.attributedText = [[NSAttributedString alloc] initWithString:t attributes:@{
		NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy],
		NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.85], NSKernAttributeName: @1.5 }];
	[row addSubview:l];
	[l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16].active = YES;
	[l.topAnchor constraintEqualToAnchor:row.topAnchor constant:9].active = YES;
	[stack addArrangedSubview:row];
	return row;
}

- (void)addSlider:(NSString*)t min:(float)lo max:(float)hi value:(float)v format:(NSString*)fmt change:(void (^)(float))change
{
	UIView* row = [self rowTitled:t height:64.0];
	UILabel* value = [[UILabel alloc] init];
	value.translatesAutoresizingMaskIntoConstraints = NO;
	value.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
	value.textColor = IOSMenu_Orange(1.0);
	value.text = [NSString stringWithFormat:fmt, v];
	[row addSubview:value];
	[value.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16].active = YES;
	[value.topAnchor constraintEqualToAnchor:row.topAnchor constant:9].active = YES;
	UISlider* s = [[UISlider alloc] init];
	s.translatesAutoresizingMaskIntoConstraints = NO;
	s.minimumValue = lo;
	s.maximumValue = hi;
	s.value = fminf(hi, fmaxf(lo, v));
	s.minimumTrackTintColor = IOSMenu_Orange(1.0);
	[row addSubview:s];
	[s.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16].active = YES;
	[s.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16].active = YES;
	[s.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6].active = YES;
	__weak UISlider* weakSlider = s;
	__weak UILabel* weakValue = value;
	[s addAction:[UIAction actionWithHandler:^(UIAction* a) {
		weakValue.text = [NSString stringWithFormat:fmt, weakSlider.value];
		change(weakSlider.value);
	}] forControlEvents:UIControlEventValueChanged];
}

- (void)addSwitch:(NSString*)t on:(BOOL)on change:(void (^)(BOOL))change
{
	UIView* row = [self rowTitled:t height:44.0];
	UISwitch* sw = [[UISwitch alloc] init];
	sw.translatesAutoresizingMaskIntoConstraints = NO;
	sw.on = on;
	sw.onTintColor = IOSMenu_Red(1.0);
	[row addSubview:sw];
	[sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12].active = YES;
	[sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor].active = YES;
	__weak UISwitch* weakSwitch = sw;
	[sw addAction:[UIAction actionWithHandler:^(UIAction* a) { change(weakSwitch.on); }] forControlEvents:UIControlEventValueChanged];
}

// ------------------------------------------------ actions

- (void)continueTapped
{
	if (numSaves > 0) IOS_MenuLoadGame(aSaves[0].file);
}

- (void)saveGame
{
	IOS_MenuSaveGame();
	IOS_ResumeGame();
}

// DOOM 3's own menu, its button showing label pressed; a button in its
// corner comes back
- (void)classic:(NSString*)label
{
	IOS_MenuPressClassic(label.UTF8String);
	self.classicNow = YES;
}

// ------------------------------------------------ once a frame

- (void)frame:(int)bOverMenus
{
	int bClassic = [[NSUserDefaults standardUserDefaults] boolForKey:IOSMENU_CLASSIC_DEFAULTS_KEY];
	int bMain = bOverMenus && IOS_MenuIsMain();
	if (!bOverMenus) self.classicNow = NO;	// (left the menus: this one next time)
	int bShow = bMain && !bClassic && !self.classicNow;
	if (bShow && self.hidden) [self refresh];
	if (bShow && (IOS_MenuInGame() != bInGame || IOS_MenuGameKind() != gameKind)) [self refresh];
	self.hidden = !bShow;
	// over DOOM 3's own main menu: back to this one (for good, if it was
	// switched off)
	backToMenu.hidden = !(bMain && !bShow);
}

- (void)backTapped
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:IOSMENU_CLASSIC_DEFAULTS_KEY];
	self.classicNow = NO;
}

- (void)setBackButton:(UIButton*)b
{
	backToMenu = b;
	[b addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
}

@end

// ---------------------------------------------------------------- the C side

static IOSMenuView* iosMenu_pView = nil;
static UIButton* iosMenu_pBack = nil;	// over DOOM 3's own menu: back to this one

// Once a frame (the touch controls': IOSTouch_Frame), under their overlay in
// the game's view; bOverMenus: the menus are up
void IOSMenu_Frame(UIView* game, UIView* overlay, int bOverMenus)
{
	if (!iosMenu_pView) {
		iosMenu_pView = [[IOSMenuView alloc] initWithFrame:game.bounds];
		iosMenu_pView.hidden = YES;
		UIButton* back = [UIButton buttonWithType:UIButtonTypeCustom];
		back.frame = CGRectMake(0, 0, 112, 34);
		NSAttributedString* t = [[NSAttributedString alloc] initWithString:@"‹ NEW MENU" attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy],
			NSForegroundColorAttributeName: UIColor.whiteColor, NSKernAttributeName: @1.5 }];
		[back setAttributedTitle:t forState:UIControlStateNormal];
		back.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
		back.layer.cornerRadius = 17.0;
		back.layer.borderWidth = 1.0;
		back.layer.borderColor = IOSMenu_Orange(0.6).CGColor;
		back.hidden = YES;
		[iosMenu_pView setBackButton:back];
		iosMenu_pBack = back;
	}
	UIButton* back = iosMenu_pBack;
	if (iosMenu_pView.superview != game) {
		[iosMenu_pView removeFromSuperview];
		[back removeFromSuperview];
		iosMenu_pView.frame = game.bounds;
		[game addSubview:iosMenu_pView];
		[game addSubview:back];
	}
	// (under the overlay, which lets the menus' touches through)
	[game insertSubview:iosMenu_pView belowSubview:overlay];
	[game insertSubview:back belowSubview:overlay];
	UIEdgeInsets in = game.safeAreaInsets;
	back.center = CGPointMake(fmax(in.left, 8.0) + 8.0 + back.bounds.size.width * 0.5, fmax(in.top, 8.0) + 8.0 + back.bounds.size.height * 0.5);
	[iosMenu_pView frame:bOverMenus];
}

int IOSMenu_Showing(void)
{
	return iosMenu_pView && !iosMenu_pView.hidden;
}
