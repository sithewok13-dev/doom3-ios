/*
 * The first screen, shown until the player's own game files are in the
 * app's Documents folder (Files > On My iPhone > DOOM 3). DOOM 3 needs base/;
 * Resurrection of Evil (d3xp/) is optional and is then picked under Mods in
 * the game's main menu. Nothing of the game's is ever bundled.
 *
 * Compiled with ARC.
 */

#import <UIKit/UIKit.h>

static NSString *DocumentsPath(void) {
	return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
}

// A copy from Windows may say "Base" or "PAK000.PK4": rename to the lower
// case the game looks for (iOS file names are case-sensitive).
static void RenameToLowercase(NSString *dir, NSString *name) {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[];
	if ([entries containsObject:name]) {
		return;
	}
	for (NSString *entry in entries) {
		if ([entry.lowercaseString isEqualToString:name]) {
			[fm moveItemAtPath:[dir stringByAppendingPathComponent:entry]
						toPath:[dir stringByAppendingPathComponent:name] error:nil];
			return;
		}
	}
}

// true once Documents/<folder>/pak000.pk4 is there
bool IOS_HasGameFolder(const char *folder) {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docs = DocumentsPath();
	NSString *name = [NSString stringWithUTF8String:folder].lowercaseString;
	RenameToLowercase(docs, name);
	NSString *dir = [docs stringByAppendingPathComponent:name];
	for (NSString *file in [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[]) {
		if ([file.lowercaseString hasSuffix:@".pk4"] && ![file isEqualToString:file.lowercaseString]) {
			RenameToLowercase(dir, file.lowercaseString);
		}
	}
	return [fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"pak000.pk4"]];
}

/*
 * LibreCoop (co-op and survival; its game code is linked in): its mod
 * folders, which come in the app (Mods/, its pak as a .zip), put in
 * Documents beside the game's own, so the game's Mods menu has them --
 * librecoop for DOOM 3, librecoopd3xp for Resurrection of Evil if its files
 * are there. Again whenever the app's build changes, so they stay as the
 * linked game code expects.
 */
void IOS_InstallMods(void) {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docs = DocumentsPath();
	NSString *mods = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"Mods"];
	NSString *build = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"] ?: @"";
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	static const char * const aMods[][2] = { { "librecoop", "base" }, { "librecoopd3xp", "d3xp" } };
	for (int i = 0; i < 2; i++) {
		NSString *mod = [NSString stringWithUTF8String:aMods[i][0]];
		NSString *from = [mods stringByAppendingPathComponent:mod];
		NSString *to = [docs stringByAppendingPathComponent:mod];
		NSString *key = [@"iosInstalledMod." stringByAppendingString:mod];
		if (![fm fileExistsAtPath:from] || !IOS_HasGameFolder(aMods[i][1])) continue;
		if ([[defaults stringForKey:key] isEqualToString:build] && [fm fileExistsAtPath:[to stringByAppendingPathComponent:@"pak000.pk4"]]) continue;
		[fm createDirectoryAtPath:to withIntermediateDirectories:YES attributes:nil error:nil];
		for (NSString *file in @[ @"pak000", @"description.txt" ]) {
			NSString *src = [from stringByAppendingPathComponent:[file isEqualToString:@"pak000"] ? @"pak000.zip" : file];
			NSString *dst = [to stringByAppendingPathComponent:[file isEqualToString:@"pak000"] ? @"pak000.pk4" : file];
			[fm removeItemAtPath:dst error:nil];
			[fm copyItemAtPath:src toPath:dst error:nil];
		}
		[defaults setObject:build forKey:key];
	}
}

@interface IOSGameDataViewController : UIViewController
@property (nonatomic) BOOL ready;
@property (nonatomic, strong) UILabel *missingLabel;
@end

@implementation IOSGameDataViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.blackColor;

	UILabel *title = [UILabel new];
	title.text = @"Game files needed";
	title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
	title.textColor = UIColor.whiteColor;

	NSString *device = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
	UILabel *body = [UILabel new];
	body.text = [NSString stringWithFormat:
		@"DOOM 3 plays the files from your own copy of the game (for example from Steam).\n\n"
		@"Copy everything inside DOOM 3's base folder into this app's base folder. "
		@"For Resurrection of Evil, also copy everything inside its d3xp folder into the d3xp folder, "
		@"then choose it under Mods in the game's main menu.\n\n"
		@"The folders are in the Files app: On My %@ > DOOM 3. "
		@"From a computer, Finder (Mac) or iTunes (Windows) can copy them in too, under Files for this app.\n\n"
		@"This is the original 2004 DOOM 3, not the BFG Edition, whose files don't work here.", device];
	body.font = [UIFont systemFontOfSize:17];
	body.textColor = [UIColor colorWithWhite:0.85 alpha:1];
	body.numberOfLines = 0;

	self.missingLabel = [UILabel new];
	self.missingLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
	self.missingLabel.textColor = [UIColor colorWithRed:1 green:0.35 blue:0.3 alpha:1];
	self.missingLabel.numberOfLines = 0;

	UIButton *check = [UIButton buttonWithType:UIButtonTypeSystem];
	[check setTitle:@"Check Again" forState:UIControlStateNormal];
	check.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
	[check setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
	check.backgroundColor = [UIColor colorWithRed:0.85 green:0.15 blue:0.1 alpha:1];
	check.layer.cornerRadius = 10;
	[check addTarget:self action:@selector(checkAgain) forControlEvents:UIControlEventTouchUpInside];
	[check.widthAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;
	[check.heightAnchor constraintEqualToConstant:48].active = YES;

	UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, body, self.missingLabel, check]];
	stack.axis = UILayoutConstraintAxisVertical;
	stack.alignment = UIStackViewAlignmentLeading;
	stack.spacing = 16;
	stack.translatesAutoresizingMaskIntoConstraints = NO;

	UIScrollView *scroll = [UIScrollView new];
	scroll.translatesAutoresizingMaskIntoConstraints = NO;
	[scroll addSubview:stack];
	[self.view addSubview:scroll];

	UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
		[scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
		[scroll.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
		[scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
		[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
		[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
		[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
	]];

	// coming back from the Files app checks again by itself
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkAgain)
												 name:UIApplicationDidBecomeActiveNotification object:nil];
	[self checkAgain];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskLandscape;
}

- (void)checkAgain {
	if (IOS_HasGameFolder("base")) {
		self.ready = YES;
		return;
	}
	self.missingLabel.text = @"Not found yet: base/pak000.pk4";
}

@end

/*
 * Called from main() before the engine starts. Returns at once when base/ is
 * there; otherwise shows the screen above and runs the main run loop until
 * the files turn up.
 */
void IOS_WaitForGameData(void) {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docs = DocumentsPath();
	// empty folders to copy into, so the app shows up in Files right away
	for (NSString *folder in @[@"base", @"d3xp"]) {
		RenameToLowercase(docs, folder);
		[fm createDirectoryAtPath:[docs stringByAppendingPathComponent:folder]
	  withIntermediateDirectories:YES attributes:nil error:nil];
	}

	if (IOS_HasGameFolder("base")) {
		return;
	}

	UIWindowScene *scene = nil;
	for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
		if ([s isKindOfClass:UIWindowScene.class]) {
			scene = (UIWindowScene *)s;
			break;
		}
	}
	UIWindow *window = scene ? [[UIWindow alloc] initWithWindowScene:scene]
							 : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	IOSGameDataViewController *vc = [IOSGameDataViewController new];
	window.rootViewController = vc;
	window.windowLevel = UIWindowLevelNormal + 1;
	[window makeKeyAndVisible];

	while (!vc.ready) {
		@autoreleasepool {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
		}
	}

	window.hidden = YES;
	window.rootViewController = nil;
}
