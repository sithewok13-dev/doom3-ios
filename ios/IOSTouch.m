/*
 * The touch controls: a UIView over SDL's, with the same controls and feel as
 * the owner's Jedi Knight and Serious Sam ports (their values are the ones
 * below), laid out for DOOM 3:
 *
 * - The move stick appears where the left thumb lands, in the left
 *   IOSTOUCH_STICK_ZONE of the screen. It walks, however far it's pushed;
 *   pushed up onto the "^^" run marker it runs (DOOM 3's run button, so
 *   stamina drains exactly as on PC). With Always Run on (MENU's tray) the
 *   marker hides and the stick runs. A drag anywhere else looks round.
 * - FIRE, with CROUCH, RELOAD and JUMP on an arc round it and LIGHT (the
 *   flashlight) beside JUMP; drags starting on those look round too.
 * - The top row: NEXT WPN and PDA on the left; QUICK SAVE, QUICK LOAD and
 *   MENU on the right. QUICK SAVE and QUICK LOAD only act after being held
 *   IOSTOUCH_QUICKSAVE_HOLD, a ring filling round them (sliding off cancels).
 * - MENU: a tap opens the game's menu; held IOSTOUCH_MENU_HOLD it opens its
 *   tray: GYRO (a tap switches it off or back on; held, its MODE and SENS),
 *   RUN (the run marker or Always Run), FPS and the keyboard (the console).
 * - Gyro aiming, OFF unless switched on: TOUCH aims while a thumb is down on
 *   the stick, the look area or a button that looks; ALWAYS aims always.
 * - Over a cinematic or the story intro: a tap anywhere skips it.
 * - Over the console: the on-screen keyboard (its own, typing straight into
 *   the console) and buttons to hide and show it and to close the console;
 *   elsewhere a finger is the mouse, as in the menus.
 *
 * What it holds goes into the usercmd as it's built (IOSTouch_TakeInput,
 * sys/ios/ios_input.cpp); taps are impulses, key presses or commands.
 * Everything here runs on the main thread, but the gyro's samples.
 *
 * Compiled with ARC.
 */

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>
#include <os/lock.h>
#include <SDL3/SDL_scancode.h>

#include "sys/ios/ios_touch.h"

#define IOSTOUCH_COUNT(a) ((int)(sizeof(a) / sizeof((a)[0])))

// Look speed: degrees the view turns per point of finger travel. In the
// ratio of the Jedi Knight port's look scale (1.6 across, 1.3 up and down);
// raised a fifth after the first try on the phone.
#define IOSTOUCH_LOOK_DEG_X 0.30f
#define IOSTOUCH_LOOK_DEG_Y 0.24f
// The move stick: radius in points (and its knob's), dead zone as a fraction
// of it; it appears wherever the left thumb lands in the left
// IOSTOUCH_STICK_ZONE of the screen, and only while that thumb is down
#define IOSTOUCH_STICK_ZONE 0.42f
#define IOSTOUCH_STICK_RADIUS 60.0
#define IOSTOUCH_STICK_KNOB 24.0
#define IOSTOUCH_STICK_DEADZONE 0.30
// The run marker (as in the Jedi Knight port, after Alien: Isolation): a
// small circle IOSTOUCH_RUN_DIST above the stick's centre (nearer where the
// top row or the screen's top is in the way, but no nearer than
// IOSTOUCH_RUN_MIN_DIST, else none). The thumb pushed past the ring to it --
// at least IOSTOUCH_RUN_ON from the centre, pointing within IOSTOUCH_RUN_CONE
// degrees of it -- runs straight ahead; back under IOSTOUCH_RUN_OFF, or more
// than IOSTOUCH_RUN_CONE_OFF degrees off, it walks again.
#define IOSTOUCH_RUN_R 15.0
#define IOSTOUCH_RUN_DIST 100.0
#define IOSTOUCH_RUN_MIN_DIST 76.0
#define IOSTOUCH_RUN_ON 70.0
#define IOSTOUCH_RUN_OFF 60.0
#define IOSTOUCH_RUN_CONE 30.0
#define IOSTOUCH_RUN_CONE_OFF 40.0
// Untouched buttons show at this opacity, so they hide less of the game
#define IOSTOUCH_IDLE_ALPHA 0.65
// A button takes touches up to this far outside its edge
#define IOSTOUCH_TOUCH_SLOP 6.0
// Kept at least this far inside the safe area (notch, Dynamic Island, home bar)
#define IOSTOUCH_MARGIN 8.0
// FIRE's radius and where it sits (its centre this far in from the right
// and up from the bottom of the safe area); the arc round it
#define IOSTOUCH_FIRE_R 42.0
#define IOSTOUCH_FIRE_X 76.0
#define IOSTOUCH_FIRE_Y 58.0
#define IOSTOUCH_ARC_R 115.0
#define IOSTOUCH_ARC_BUTTON_R 30.0
// The top row's buttons, IOSTOUCH_TRAY_STEP apart (as is MENU's tray)
#define IOSTOUCH_TOP_R 22.0
#define IOSTOUCH_TRAY_STEP 50.0
// QUICK SAVE and QUICK LOAD must be held this long, so a stray tap can't
// save over the quick save or throw away progress
#define IOSTOUCH_QUICKSAVE_HOLD 0.3
// MENU held this long opens its tray (and GYRO in it, its options)
#define IOSTOUCH_MENU_HOLD 0.45
// Gyro aiming (iosTouch_GyroSample): CoreMotion's device motion
// IOSTOUCH_GYRO_HZ times a second. Turning is measured about the way up, so
// it works however far back the phone is tipped; tilting is about the
// screen's own side-to-side axis. Under IOSTOUCH_GYRO_SMOOTH deg/s the motion
// is averaged over the last IOSTOUCH_GYRO_SMOOTH_N samples, under
// IOSTOUCH_GYRO_SOFT deg/s it's scaled down to nothing at rest, so a phone
// held still doesn't creep. A stall between two samples, a frame after a long
// gap, and the time just after the screen turned round are skipped. All as in
// the Jedi Knight port.
#define IOSTOUCH_GYRO_HZ 100.0
#define IOSTOUCH_GYRO_YAW_RELAX 1.41
#define IOSTOUCH_GYRO_SMOOTH 4.0
#define IOSTOUCH_GYRO_SMOOTH_N 12
#define IOSTOUCH_GYRO_SOFT 1.5
#define IOSTOUCH_GYRO_MAX_DT 0.05
#define IOSTOUCH_GYRO_MAX_FRAME 0.5
#define IOSTOUCH_GYRO_TURN_HOLD 0.35
// The settings, under the same keys as the owner's other ports
#define IOSTOUCH_GYRO_DEFAULTS_KEY @"iosTouchGyroMode"
#define IOSTOUCH_GYRO_SENS_DEFAULTS_KEY @"iosTouchGyroSens"
#define IOSTOUCH_GYRO_LAST_DEFAULTS_KEY @"iosTouchGyroLastMode"
#define IOSTOUCH_ALWAYSRUN_DEFAULTS_KEY @"iosTouchAlwaysRun"

enum {
	// the buttons in play
	BTN_FIRE = 0, BTN_JUMP, BTN_CROUCH, BTN_RELOAD, BTN_LIGHT,
	BTN_NEXTWPN, BTN_PDA, BTN_QSAVE, BTN_QLOAD, BTN_MENU,
	// MENU's tray, and GYRO's options in a second row under it
	BTN_TRAY_GYRO, BTN_TRAY_RUN, BTN_TRAY_FPS, BTN_TRAY_KEYS,
	BTN_OPT_MODE, BTN_OPT_SENS,
	NUM_BUTTONS
};
#define BTN_FIRST_TRAY BTN_TRAY_GYRO
#define BTN_FIRST_OPT BTN_OPT_MODE

typedef enum {
	KIND_HOLD,		// held down for as long as it's touched (FIRE, JUMP, CROUCH)
	KIND_TAP,		// acts as it's touched
	KIND_HOLDTAP,	// acts once held IOSTOUCH_QUICKSAVE_HOLD (QUICK SAVE, QUICK LOAD)
	KIND_MENU,		// a tap the menu, held the tray
	KIND_TRAY,		// in MENU's tray
} iosTouchKind_t;

typedef struct {
	const char*		label;
	iosTouchKind_t	kind;
	CGFloat			radius;
	int				bLookWhileHeld;	// a drag from it also looks round
} iosTouchButton_t;

static const iosTouchButton_t iosTouch_aButtons[NUM_BUTTONS] = {
	{ "FIRE",		KIND_HOLD,		IOSTOUCH_FIRE_R,		1 },
	{ "JUMP",		KIND_HOLD,		IOSTOUCH_ARC_BUTTON_R,	1 },
	{ "CROUCH",		KIND_HOLD,		IOSTOUCH_ARC_BUTTON_R,	1 },
	{ "RELOAD",		KIND_TAP,		IOSTOUCH_ARC_BUTTON_R,	1 },
	{ "LIGHT",		KIND_TAP,		28.0,					1 },
	{ "NEXT\nWPN",	KIND_TAP,		IOSTOUCH_TOP_R,			0 },
	{ "PDA",		KIND_TAP,		IOSTOUCH_TOP_R,			0 },
	{ "QUICK\nSAVE", KIND_HOLDTAP,	IOSTOUCH_TOP_R,			0 },
	{ "QUICK\nLOAD", KIND_HOLDTAP,	IOSTOUCH_TOP_R,			0 },
	{ "MENU",		KIND_MENU,		IOSTOUCH_TOP_R,			0 },
	{ "GYRO",		KIND_TRAY,		IOSTOUCH_TOP_R,			0 },
	{ "RUN",		KIND_TRAY,		IOSTOUCH_TOP_R,			0 },
	{ "FPS",		KIND_TRAY,		IOSTOUCH_TOP_R,			0 },
	{ "",			KIND_TRAY,		IOSTOUCH_TOP_R,			0 },	// (the keyboard symbol)
	{ "MODE",		KIND_TRAY,		IOSTOUCH_TOP_R,			0 },
	{ "SENS",		KIND_TRAY,		IOSTOUCH_TOP_R,			0 },
};

typedef enum { ROLE_NONE = 0, ROLE_STICK, ROLE_LOOK, ROLE_BUTTON, ROLE_IGNORED } iosTouchRole_t;

#define IOSTOUCH_MAX_TOUCHES 10
typedef struct {
	void*			touch;			// the UITouch it follows (only compared, never kept alive)
	iosTouchRole_t	role;
	int				button;
	CGPoint			start, last;
	CFTimeInterval	startTime;
	int				bInside;		// still on its button
	int				bDone;			// a hold already acted (QUICK SAVE), or MENU opened its tray
	int				bLooking;		// a button's touch dragged into looking
} iosTouchSlot_t;

static iosTouchSlot_t iosTouch_aSlots[IOSTOUCH_MAX_TOUCHES];

// The stick: its centre, the thumb's offset from it, whether it's on the run marker
static CGPoint iosTouch_stickCentre;
static CGPoint iosTouch_stickThumb;
static int iosTouch_bRunning;
static CGFloat iosTouch_runDist;	// how far above the centre the marker is now (0: none)

// Settings
static int iosTouch_bAlwaysRun;

// The look drags' and the gyro's turning since the last usercmd (degrees)
static float iosTouch_yaw, iosTouch_pitch;

static int iosTouch_mode = IOSTOUCH_MODE_HIDDEN;
static int iosTouch_bTrayOpen;
static int iosTouch_bOptsOpen;

// ---------------------------------------------------------------- gyro aiming

enum { IOSTOUCH_GYRO_OFF = 0, IOSTOUCH_GYRO_TOUCH, IOSTOUCH_GYRO_ALWAYS, IOSTOUCH_GYRO_NUM_MODES };
static const float iosTouch_aGyroSens[] = { 1.0f, 1.5f, 2.0f, 3.0f };
static int iosTouch_gyroMode = IOSTOUCH_GYRO_OFF;
static int iosTouch_gyroLastMode = IOSTOUCH_GYRO_TOUCH;
static int iosTouch_gyroSens = 1; // 1.5x
static CMMotionManager* iosTouch_pMotion = nil;
static NSOperationQueue* iosTouch_pMotionQueue = nil;
static int iosTouch_bGyroRunning;
static int iosTouch_bGyroRefused;
static int iosTouch_bGyroWasOk;
static CFTimeInterval iosTouch_gyroLastFrame;
static int iosTouch_gyroLastSide;
static CFTimeInterval iosTouch_gyroTurnedRound = -1.0e9;
// (under iosTouch_gyroLock, as the samples come in on their queue)
static os_unfair_lock iosTouch_gyroLock = OS_UNFAIR_LOCK_INIT;
static int iosTouch_gyroSide;
static double iosTouch_gyroYaw, iosTouch_gyroPitch;
static NSTimeInterval iosTouch_gyroLastT;
static double iosTouch_aGyroSmooth[IOSTOUCH_GYRO_SMOOTH_N][2];
static int iosTouch_gyroSmoothNext;
static int iosTouch_bGyroRefusedOnQueue;

// One sample of device motion, on the samples' queue: the rotation rate w
// (rad/s) and gravity g in the device's own axes (x right, y up, z out of the
// screen, as if held upright), taken at time t. Adds how far it turns (+ left)
// and tilts (+ up) the view.
static void iosTouch_GyroSample(double wx, double wy, double wz, double gx, double gy, double gz, NSTimeInterval t)
{
	os_unfair_lock_lock(&iosTouch_gyroLock);
	double dt = iosTouch_gyroLastT > 0.0 ? t - iosTouch_gyroLastT : 0.0;
	iosTouch_gyroLastT = t;
	double s = iosTouch_gyroSide;
	double gn = sqrt(gx * gx + gy * gy + gz * gz);
	if (s != 0.0 && dt > 0.0 && dt <= IOSTOUCH_GYRO_MAX_DT && gn > 0.1) {
		// the screen's axes as the player sees it (right, up, toward them):
		// how fast the phone turns about each, and how far each points up
		double rx = s * wy, ry = -s * wx, rz = wz;
		double ux = -s * gy / gn, uy = s * gx / gn, uz = -gz / gn;
		// not while held upside down for the way the screen is turned (on its
		// way round to the other landscape side)
		double tilt = sqrt(ux * ux + uy * uy);
		if (tilt < 0.5 || uy > -0.5 * tilt) {
			double yaw = ry, pitch = rx;
			if (uz >= 0.0 && (tilt < 0.5 || uy > 0.5 * tilt)) {
				// player space: turning about up, from the screen's up and
				// toward-the-player axes as far as each points up
				yaw = uy * ry + uz * rz;
				double mag = sqrt(ry * ry + rz * rz);
				yaw = copysign(fmin(fabs(yaw) * IOSTOUCH_GYRO_YAW_RELAX, mag), yaw);
			}
			yaw *= 180.0 / M_PI;
			pitch *= 180.0 / M_PI;

			// smoothed only where it's slow
			double m = sqrt(yaw * yaw + pitch * pitch);
			double direct = (m - IOSTOUCH_GYRO_SMOOTH * 0.5) / (IOSTOUCH_GYRO_SMOOTH * 0.5);
			direct = direct < 0.0 ? 0.0 : (direct > 1.0 ? 1.0 : direct);
			iosTouch_aGyroSmooth[iosTouch_gyroSmoothNext][0] = yaw * (1.0 - direct);
			iosTouch_aGyroSmooth[iosTouch_gyroSmoothNext][1] = pitch * (1.0 - direct);
			iosTouch_gyroSmoothNext = (iosTouch_gyroSmoothNext + 1) % IOSTOUCH_GYRO_SMOOTH_N;
			double sumYaw = 0.0, sumPitch = 0.0;
			for (int i = 0; i < IOSTOUCH_GYRO_SMOOTH_N; i++) {
				sumYaw += iosTouch_aGyroSmooth[i][0];
				sumPitch += iosTouch_aGyroSmooth[i][1];
			}
			yaw = yaw * direct + sumYaw / IOSTOUCH_GYRO_SMOOTH_N;
			pitch = pitch * direct + sumPitch / IOSTOUCH_GYRO_SMOOTH_N;

			// the soft dead zone
			m = sqrt(yaw * yaw + pitch * pitch);
			if (m < IOSTOUCH_GYRO_SOFT) {
				yaw *= m / IOSTOUCH_GYRO_SOFT;
				pitch *= m / IOSTOUCH_GYRO_SOFT;
			}
			iosTouch_gyroYaw += yaw * dt;
			iosTouch_gyroPitch += pitch * dt;
		}
	}
	os_unfair_lock_unlock(&iosTouch_gyroLock);
}

static int iosTouch_GyroIsRefusal(NSError* err)
{
	if (![err.domain isEqualToString:CMErrorDomain]) return 0;
	return err.code == CMErrorNotAuthorized || err.code == CMErrorNotEntitled
		|| err.code == CMErrorMotionActivityNotAuthorized || err.code == CMErrorMotionActivityNotEntitled;
}

static void iosTouch_GyroRun(int bRun)
{
	bRun = bRun != 0;
	if (bRun == iosTouch_bGyroRunning) return;
	iosTouch_bGyroRunning = bRun;
	if (!bRun) {
		[iosTouch_pMotion stopDeviceMotionUpdates];
		return;
	}
	// from scratch: nothing from before it stopped, the smoothing empty
	os_unfair_lock_lock(&iosTouch_gyroLock);
	iosTouch_gyroLastT = 0.0;
	iosTouch_gyroYaw = iosTouch_gyroPitch = 0.0;
	memset(iosTouch_aGyroSmooth, 0, sizeof(iosTouch_aGyroSmooth));
	os_unfair_lock_unlock(&iosTouch_gyroLock);
	iosTouch_pMotion.deviceMotionUpdateInterval = 1.0 / IOSTOUCH_GYRO_HZ;
	// (the reference frame that needs no compass: the attitude isn't used)
	[iosTouch_pMotion startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
														  toQueue:iosTouch_pMotionQueue
													  withHandler:^(CMDeviceMotion* dm, NSError* err) {
		if (err && iosTouch_GyroIsRefusal(err)) {
			os_unfair_lock_lock(&iosTouch_gyroLock);
			iosTouch_bGyroRefusedOnQueue = 1;
			os_unfair_lock_unlock(&iosTouch_gyroLock);
		}
		if (!dm || err) return;
		CMRotationRate w = dm.rotationRate;
		CMAcceleration g = dm.gravity;
		iosTouch_GyroSample(w.x, w.y, w.z, g.x, g.y, g.z, dm.timestamp);
	}];
}

// once: the motion manager and its queue (nothing runs yet), and the
// settings -- OFF and 1.5x unless set
static void iosTouch_GyroSetup(void)
{
	if (iosTouch_pMotion) return;
	iosTouch_pMotion = [[CMMotionManager alloc] init];
	iosTouch_pMotionQueue = [[NSOperationQueue alloc] init];
	iosTouch_pMotionQueue.maxConcurrentOperationCount = 1;
	iosTouch_pMotionQueue.qualityOfService = NSQualityOfServiceUserInteractive;

	NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
	if ([d objectForKey:IOSTOUCH_GYRO_DEFAULTS_KEY]) {
		NSInteger m = [d integerForKey:IOSTOUCH_GYRO_DEFAULTS_KEY];
		iosTouch_gyroMode = (m >= 0 && m < IOSTOUCH_GYRO_NUM_MODES) ? (int)m : IOSTOUCH_GYRO_OFF;
	}
	if ([d objectForKey:IOSTOUCH_GYRO_LAST_DEFAULTS_KEY]) {
		NSInteger m = [d integerForKey:IOSTOUCH_GYRO_LAST_DEFAULTS_KEY];
		iosTouch_gyroLastMode = (m == IOSTOUCH_GYRO_ALWAYS) ? IOSTOUCH_GYRO_ALWAYS : IOSTOUCH_GYRO_TOUCH;
	}
	if (iosTouch_gyroMode != IOSTOUCH_GYRO_OFF) iosTouch_gyroLastMode = iosTouch_gyroMode;
	if ([d objectForKey:IOSTOUCH_GYRO_SENS_DEFAULTS_KEY]) {
		float k = [d floatForKey:IOSTOUCH_GYRO_SENS_DEFAULTS_KEY];
		for (int i = 0; i < IOSTOUCH_COUNT(iosTouch_aGyroSens); i++) {
			if (fabsf(iosTouch_aGyroSens[i] - k) < fabsf(iosTouch_aGyroSens[iosTouch_gyroSens] - k)) iosTouch_gyroSens = i;
		}
	}
}

static int iosTouch_GyroAvailable(void)
{
	return iosTouch_pMotion && iosTouch_pMotion.deviceMotionAvailable && !iosTouch_bGyroRefused;
}

static void iosTouch_GyroSave(void)
{
	NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
	[d setInteger:iosTouch_gyroMode forKey:IOSTOUCH_GYRO_DEFAULTS_KEY];
	[d setInteger:iosTouch_gyroLastMode forKey:IOSTOUCH_GYRO_LAST_DEFAULTS_KEY];
}

// GYRO's tap: off, or back on in the mode it was last on in
static void iosTouch_GyroToggle(void)
{
	if (iosTouch_gyroMode != IOSTOUCH_GYRO_OFF) {
		iosTouch_gyroLastMode = iosTouch_gyroMode;
		iosTouch_gyroMode = IOSTOUCH_GYRO_OFF;
	} else {
		iosTouch_gyroMode = iosTouch_gyroLastMode;
	}
	iosTouch_GyroSave();
}

// MODE: the other of TOUCH and ALWAYS (and on in it, if it's on)
static void iosTouch_GyroNextMode(void)
{
	iosTouch_gyroLastMode = (iosTouch_gyroLastMode == IOSTOUCH_GYRO_TOUCH) ? IOSTOUCH_GYRO_ALWAYS : IOSTOUCH_GYRO_TOUCH;
	if (iosTouch_gyroMode != IOSTOUCH_GYRO_OFF) iosTouch_gyroMode = iosTouch_gyroLastMode;
	iosTouch_GyroSave();
}

static void iosTouch_GyroNextSens(void)
{
	iosTouch_gyroSens = (iosTouch_gyroSens + 1) % IOSTOUCH_COUNT(iosTouch_aGyroSens);
	[[NSUserDefaults standardUserDefaults] setFloat:iosTouch_aGyroSens[iosTouch_gyroSens] forKey:IOSTOUCH_GYRO_SENS_DEFAULTS_KEY];
}

// for TOUCH: a thumb down on the stick, the look area, or a button that looks
static int iosTouch_GyroThumbDown(void)
{
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		const iosTouchSlot_t* s = &iosTouch_aSlots[i];
		if (!s->touch) continue;
		if (s->role == ROLE_STICK || s->role == ROLE_LOOK
			|| (s->role == ROLE_BUTTON && iosTouch_aButtons[s->button].bLookWhileHeld)) return 1;
	}
	return 0;
}

// Once a frame, after the frame's touches. The motion updates run only while
// the controls are up, the app is active, the gyro is on and the screen is
// turned either landscape way. What the phone turned since the last frame
// adds to the view's turning -- if it could aim both then and now, so in
// TOUCH lifting the last thumb freezes the view where it is (nothing springs
// back). Never while the tray is open, just after the screen turned round,
// nor after a frame that took too long.
static void iosTouch_GyroUpdate(int bShown, UIView* v)
{
	UIWindowScene* scene = v.window.windowScene;
	UIInterfaceOrientation o = scene ? scene.interfaceOrientation : UIInterfaceOrientationUnknown;
	int side = (o == UIInterfaceOrientationLandscapeLeft) ? 1 : ((o == UIInterfaceOrientationLandscapeRight) ? -1 : 0);
	int bActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
	CFTimeInterval now = CACurrentMediaTime();
	if (side != 0 && iosTouch_gyroLastSide != 0 && side != iosTouch_gyroLastSide) iosTouch_gyroTurnedRound = now;
	if (side != 0) iosTouch_gyroLastSide = side;
	iosTouch_GyroRun(bShown && bActive && side != 0 && iosTouch_gyroMode != IOSTOUCH_GYRO_OFF && iosTouch_GyroAvailable());

	os_unfair_lock_lock(&iosTouch_gyroLock);
	iosTouch_gyroSide = side;
	double yaw = iosTouch_gyroYaw, pitch = iosTouch_gyroPitch;
	iosTouch_gyroYaw = iosTouch_gyroPitch = 0.0;
	iosTouch_bGyroRefused |= iosTouch_bGyroRefusedOnQueue;
	os_unfair_lock_unlock(&iosTouch_gyroLock);

	int bOk = iosTouch_bGyroRunning
			  && (iosTouch_gyroMode == IOSTOUCH_GYRO_ALWAYS || iosTouch_GyroThumbDown())
			  && !iosTouch_bTrayOpen
			  && now - iosTouch_gyroTurnedRound >= IOSTOUCH_GYRO_TURN_HOLD;
	int bUse = bOk && iosTouch_bGyroWasOk && now - iosTouch_gyroLastFrame <= IOSTOUCH_GYRO_MAX_FRAME;
	iosTouch_bGyroWasOk = bOk;
	iosTouch_gyroLastFrame = now;
	if (!bUse) return;

	// at 1.0x the view turns as far as the phone does
	float k = iosTouch_aGyroSens[iosTouch_gyroSens];
	iosTouch_yaw += (float)yaw * k;
	iosTouch_pitch -= (float)pitch * k;	// (the usercmd's pitch is + down)
}

// ---------------------------------------------------------------- the console's keyboard

// Takes the on-screen keyboard's typing for the console: plain keys, no
// corrections, capitals or curly quotes, which commands don't want
@interface IOSConsoleKeys : UIView <UIKeyInput>
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UITextSmartQuotesType smartQuotesType;
@property (nonatomic) UITextSmartDashesType smartDashesType;
@property (nonatomic) UITextSmartInsertDeleteType smartInsertDeleteType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIReturnKeyType returnKeyType;
@end

@implementation IOSConsoleKeys

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (!self) return nil;
	self.autocorrectionType = UITextAutocorrectionTypeNo;
	self.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.spellCheckingType = UITextSpellCheckingTypeNo;
	self.smartQuotesType = UITextSmartQuotesTypeNo;
	self.smartDashesType = UITextSmartDashesTypeNo;
	self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
	self.keyboardType = UIKeyboardTypeASCIICapable;
	self.returnKeyType = UIReturnKeyGo;
	return self;
}

- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return YES; }	// (so backspace always reaches the console)
- (void)insertText:(NSString*)text { IOS_ConsoleText(text.UTF8String); }
- (void)deleteBackward { IOS_ConsoleKey(IOSTOUCH_KEY_BACKSPACE); }

@end

// ---------------------------------------------------------------- the overlay

@interface IOSTouchOverlay : UIView
@end

@implementation IOSTouchOverlay {
	UILabel*			aButtonViews[NUM_BUTTONS];
	CAShapeLayer*		aHoldRings[NUM_BUTTONS];	// QUICK SAVE, QUICK LOAD, MENU, GYRO: filling while held
	CGPoint				aCentres[NUM_BUTTONS];
	CAShapeLayer*		stickRing;
	CAShapeLayer*		stickKnob;
	CAShapeLayer*		runMarker;	// the run marker, with its line to the stick's ring
	UILabel*			runLabel;
	UIView*				trayBacking;
	UILabel*			skipLabel;		// over a cinematic: "SKIP"
	UIButton*			consoleKeysButton;	// over the console: hide / show the keyboard
	UIButton*			consoleCloseButton;	// and close it
	IOSConsoleKeys*		consoleKeys;
	CFTimeInterval		lastSkip;
	UISelectionFeedbackGenerator* tick;
	UIImpactFeedbackGenerator* thump;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (!self) return nil;
	self.multipleTouchEnabled = YES;
	self.backgroundColor = UIColor.clearColor;
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	tick = [[UISelectionFeedbackGenerator alloc] init];
	thump = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

	trayBacking = [[UIView alloc] init];
	trayBacking.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
	trayBacking.layer.cornerRadius = IOSTOUCH_TOP_R + 6.0;
	trayBacking.hidden = YES;
	[self addSubview:trayBacking];

	for (int i = 0; i < NUM_BUTTONS; i++) {
		const iosTouchButton_t* b = &iosTouch_aButtons[i];
		UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 2 * b->radius, 2 * b->radius)];
		l.text = [NSString stringWithUTF8String:b->label];
		l.numberOfLines = 0;
		l.textAlignment = NSTextAlignmentCenter;
		l.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
		l.font = [UIFont systemFontOfSize:(b->radius >= 40.0 ? 15.0 : (b->radius >= 28.0 ? 11.0 : 8.5)) weight:UIFontWeightBold];
		l.adjustsFontSizeToFitWidth = YES;
		l.minimumScaleFactor = 0.6;
		l.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
		l.layer.cornerRadius = b->radius;
		l.layer.borderWidth = 1.5;
		l.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
		l.layer.masksToBounds = YES;
		l.alpha = IOSTOUCH_IDLE_ALPHA;
		l.hidden = (i >= BTN_FIRST_TRAY);
		[self addSubview:l];
		aButtonViews[i] = l;

		if (b->kind == KIND_HOLDTAP || b->kind == KIND_MENU || i == BTN_TRAY_GYRO) {
			CAShapeLayer* ring = [CAShapeLayer layer];
			ring.frame = CGRectMake(0, 0, 2 * b->radius, 2 * b->radius);
			ring.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(b->radius, b->radius) radius:b->radius - 2.0
											   startAngle:-M_PI_2 endAngle:1.5 * M_PI clockwise:YES].CGPath;
			ring.fillColor = UIColor.clearColor.CGColor;
			ring.strokeColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.3 alpha:0.95].CGColor;
			ring.lineWidth = 3.0;
			ring.strokeEnd = 0.0;
			[l.layer addSublayer:ring];
			aHoldRings[i] = ring;
		}
	}
	// the keyboard button shows the keyboard symbol
	UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
	UIImage* kb = [UIImage systemImageNamed:@"keyboard" withConfiguration:cfg];
	if (kb) {
		NSTextAttachment* att = [[NSTextAttachment alloc] init];
		att.image = [kb imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.85] renderingMode:UIImageRenderingModeAlwaysOriginal];
		aButtonViews[BTN_TRAY_KEYS].attributedText = [NSAttributedString attributedStringWithAttachment:att];
	} else {
		aButtonViews[BTN_TRAY_KEYS].text = @"TYPE";
	}

	stickRing = [CAShapeLayer layer];
	stickRing.fillColor = [UIColor colorWithWhite:0.0 alpha:0.2].CGColor;
	stickRing.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
	stickRing.lineWidth = 2.0;
	stickRing.hidden = YES;
	[self.layer addSublayer:stickRing];
	stickKnob = [CAShapeLayer layer];
	stickKnob.fillColor = [UIColor colorWithWhite:1.0 alpha:0.45].CGColor;
	stickKnob.hidden = YES;
	[self.layer addSublayer:stickKnob];
	runMarker = [CAShapeLayer layer];
	runMarker.fillColor = [UIColor colorWithWhite:0.0 alpha:0.2].CGColor;
	runMarker.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
	runMarker.lineWidth = 1.5;
	runMarker.hidden = YES;
	[self.layer addSublayer:runMarker];
	runLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 2 * IOSTOUCH_RUN_R, 2 * IOSTOUCH_RUN_R)];
	runLabel.text = @"^^";
	runLabel.textAlignment = NSTextAlignmentCenter;
	runLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightHeavy];
	runLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
	runLabel.hidden = YES;
	[self addSubview:runLabel];

	skipLabel = [[UILabel alloc] init];
	skipLabel.text = @"SKIP \u25B6\u25B6";
	skipLabel.textAlignment = NSTextAlignmentCenter;
	skipLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
	skipLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
	skipLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
	skipLabel.layer.cornerRadius = IOSTOUCH_TOP_R;
	skipLabel.layer.borderWidth = 1.5;
	skipLabel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
	skipLabel.layer.masksToBounds = YES;
	skipLabel.alpha = IOSTOUCH_IDLE_ALPHA;
	skipLabel.hidden = YES;
	[self addSubview:skipLabel];

	consoleKeys = [[IOSConsoleKeys alloc] initWithFrame:CGRectZero];
	[self addSubview:consoleKeys];
	consoleKeysButton = [self roundButton:@"keyboard" action:@selector(consoleKeysTapped)];
	consoleCloseButton = [self roundButton:@"xmark" action:@selector(consoleCloseTapped)];

	iosTouch_bAlwaysRun = [[NSUserDefaults standardUserDefaults] boolForKey:IOSTOUCH_ALWAYSRUN_DEFAULTS_KEY];
	iosTouch_GyroSetup();
	[self refreshLabels];
	return self;
}

// a round button in the controls' style, with an SF Symbol (the console's)
- (UIButton*)roundButton:(NSString*)symbol action:(SEL)action
{
	UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.frame = CGRectMake(0, 0, 2 * IOSTOUCH_TOP_R, 2 * IOSTOUCH_TOP_R);
	UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
	[b setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
	b.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
	b.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
	b.layer.cornerRadius = IOSTOUCH_TOP_R;
	b.layer.borderWidth = 1.5;
	b.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
	b.hidden = YES;
	[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:b];
	return b;
}

- (void)consoleKeysTapped
{
	if (consoleKeys.isFirstResponder) {
		[consoleKeys resignFirstResponder];
	} else {
		[consoleKeys becomeFirstResponder];
	}
	[tick selectionChanged];
}

- (void)consoleCloseTapped
{
	[consoleKeys resignFirstResponder];
	IOS_CloseConsole();
	[tick selectionChanged];
}

// Over the console only its own buttons take touches; the rest go on to
// SDL's view, where a finger is the mouse
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)event
{
	UIView* v = [super hitTest:p withEvent:event];
	if (iosTouch_mode == IOSTOUCH_MODE_CONSOLE && v != consoleKeysButton && v != consoleCloseButton) return nil;
	return v;
}

// ------------------------------------------------ layout

- (void)place:(int)i at:(CGPoint)c
{
	aCentres[i] = c;
	CGFloat r = iosTouch_aButtons[i].radius;
	aButtonViews[i].frame = CGRectMake(c.x - r, c.y - r, 2 * r, 2 * r);
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	UIEdgeInsets in = self.safeAreaInsets;
	CGFloat left = fmax(in.left, 0.0) + IOSTOUCH_MARGIN;
	CGFloat right = self.bounds.size.width - fmax(in.right, 0.0) - IOSTOUCH_MARGIN;
	CGFloat top = fmax(in.top, 0.0) + IOSTOUCH_MARGIN;
	CGFloat bottom = self.bounds.size.height - fmax(in.bottom, 0.0) - IOSTOUCH_MARGIN;

	// FIRE, and its arc: CROUCH to its left, RELOAD up-left, JUMP above
	CGPoint fire = CGPointMake(right - IOSTOUCH_FIRE_X + IOSTOUCH_MARGIN, bottom - IOSTOUCH_FIRE_Y + IOSTOUCH_MARGIN);
	[self place:BTN_FIRE at:fire];
	const int aArc[3] = { BTN_CROUCH, BTN_RELOAD, BTN_JUMP };
	const CGFloat aArcDeg[3] = { 180.0, 135.0, 90.0 };
	for (int k = 0; k < 3; k++) {
		CGFloat a = aArcDeg[k] * M_PI / 180.0;
		[self place:aArc[k] at:CGPointMake(fire.x + IOSTOUCH_ARC_R * cos(a), fire.y - IOSTOUCH_ARC_R * sin(a))];
	}
	// LIGHT beside JUMP, further out between it and RELOAD
	CGFloat la = 112.0 * M_PI / 180.0;
	[self place:BTN_LIGHT at:CGPointMake(fire.x + 180.0 * cos(la), fire.y - 180.0 * sin(la))];

	// the top row
	CGFloat rowY = top + IOSTOUCH_TOP_R;
	[self place:BTN_NEXTWPN at:CGPointMake(left + IOSTOUCH_TOP_R, rowY)];
	[self place:BTN_PDA at:CGPointMake(left + IOSTOUCH_TOP_R + IOSTOUCH_TRAY_STEP, rowY)];
	[self place:BTN_MENU at:CGPointMake(right - IOSTOUCH_TOP_R, rowY)];
	[self place:BTN_QLOAD at:CGPointMake(right - IOSTOUCH_TOP_R - IOSTOUCH_TRAY_STEP, rowY)];
	[self place:BTN_QSAVE at:CGPointMake(right - IOSTOUCH_TOP_R - 2 * IOSTOUCH_TRAY_STEP, rowY)];

	// MENU's tray: a row under the top row, ending under MENU; GYRO's
	// options a row under that, under GYRO
	CGFloat trayY = rowY + IOSTOUCH_TRAY_STEP;
	const int aTray[4] = { BTN_TRAY_GYRO, BTN_TRAY_RUN, BTN_TRAY_FPS, BTN_TRAY_KEYS };
	for (int k = 0; k < 4; k++) {
		[self place:aTray[k] at:CGPointMake(right - IOSTOUCH_TOP_R - (3 - k) * IOSTOUCH_TRAY_STEP, trayY)];
	}
	CGFloat optY = trayY + IOSTOUCH_TRAY_STEP;
	[self place:BTN_OPT_MODE at:CGPointMake(aCentres[BTN_TRAY_GYRO].x, optY)];
	[self place:BTN_OPT_SENS at:CGPointMake(aCentres[BTN_TRAY_GYRO].x + IOSTOUCH_TRAY_STEP, optY)];
	[self layoutTrayBacking];

	// SKIP where FIRE is; the console's buttons where MENU and QUICK LOAD are
	skipLabel.frame = CGRectMake(right - 96.0, bottom - 2 * IOSTOUCH_TOP_R, 96.0, 2 * IOSTOUCH_TOP_R);
	consoleCloseButton.center = aCentres[BTN_MENU];
	consoleKeysButton.center = aCentres[BTN_QLOAD];
}

- (void)layoutTrayBacking
{
	CGFloat r = IOSTOUCH_TOP_R + 6.0;
	CGRect row = CGRectMake(aCentres[BTN_TRAY_GYRO].x - r, aCentres[BTN_TRAY_GYRO].y - r,
							aCentres[BTN_TRAY_KEYS].x - aCentres[BTN_TRAY_GYRO].x + 2 * r, 2 * r);
	if (iosTouch_bOptsOpen) {
		row.size.height += IOSTOUCH_TRAY_STEP;
	}
	trayBacking.frame = row;
}

// ------------------------------------------------ what the buttons say

- (void)refreshLabels
{
	static const char* aGyroModes[] = { "OFF", "TOUCH", "ALWAYS" };
	aButtonViews[BTN_TRAY_GYRO].text = iosTouch_GyroAvailable() || !iosTouch_pMotion
		? [NSString stringWithFormat:@"GYRO\n%s", aGyroModes[iosTouch_gyroMode]] : @"NO\nGYRO";
	aButtonViews[BTN_TRAY_RUN].text = iosTouch_bAlwaysRun ? @"RUN\nALWAYS" : @"RUN\n^^";
	aButtonViews[BTN_TRAY_FPS].text = IOS_CVarInteger("com_showFPS") ? @"FPS\nON" : @"FPS\nOFF";
	aButtonViews[BTN_OPT_MODE].text = iosTouch_gyroLastMode == IOSTOUCH_GYRO_ALWAYS ? @"MODE\nALWAYS" : @"MODE\nTOUCH";
	aButtonViews[BTN_OPT_SENS].text = [NSString stringWithFormat:@"SENS\n%.1fx", iosTouch_aGyroSens[iosTouch_gyroSens]];
}

- (void)setTrayOpen:(int)bOpen
{
	iosTouch_bTrayOpen = bOpen;
	if (!bOpen) iosTouch_bOptsOpen = 0;
	for (int i = BTN_FIRST_TRAY; i < NUM_BUTTONS; i++) {
		aButtonViews[i].hidden = !bOpen || (i >= BTN_FIRST_OPT && !iosTouch_bOptsOpen);
	}
	trayBacking.hidden = !bOpen;
	[self layoutTrayBacking];
	[self refreshLabels];
}

- (void)setOptsOpen:(int)bOpen
{
	iosTouch_bOptsOpen = bOpen;
	[self setTrayOpen:1];
}

// ------------------------------------------------ touches

- (int)buttonAt:(CGPoint)p
{
	int best = -1;
	CGFloat bestD = 0.0;
	for (int i = 0; i < NUM_BUTTONS; i++) {
		if (aButtonViews[i].hidden) continue;
		CGFloat dx = p.x - aCentres[i].x, dy = p.y - aCentres[i].y;
		CGFloat d = sqrt(dx * dx + dy * dy);
		if (d <= iosTouch_aButtons[i].radius + IOSTOUCH_TOUCH_SLOP && (best < 0 || d < bestD)) {
			best = i;
			bestD = d;
		}
	}
	// a touch on the tray's backing counts as its nearest button
	if (best < 0 && iosTouch_bTrayOpen && CGRectContainsPoint(trayBacking.frame, p)) {
		for (int i = BTN_FIRST_TRAY; i < NUM_BUTTONS; i++) {
			if (aButtonViews[i].hidden) continue;
			CGFloat dx = p.x - aCentres[i].x, dy = p.y - aCentres[i].y;
			CGFloat d = sqrt(dx * dx + dy * dy);
			if (best < 0 || d < bestD) {
				best = i;
				bestD = d;
			}
		}
	}
	return best;
}

- (int)isPoint:(CGPoint)p onButton:(int)i
{
	CGFloat dx = p.x - aCentres[i].x, dy = p.y - aCentres[i].y;
	return sqrt(dx * dx + dy * dy) <= iosTouch_aButtons[i].radius + IOSTOUCH_TOUCH_SLOP;
}

static iosTouchSlot_t* iosTouch_SlotFor(UITouch* t, int bNew)
{
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		if (iosTouch_aSlots[i].touch == (__bridge void*)t) return &iosTouch_aSlots[i];
	}
	if (!bNew) return NULL;
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		if (!iosTouch_aSlots[i].touch) {
			memset(&iosTouch_aSlots[i], 0, sizeof(iosTouch_aSlots[i]));
			iosTouch_aSlots[i].touch = (__bridge void*)t;
			return &iosTouch_aSlots[i];
		}
	}
	return NULL;
}

static int iosTouch_StickHeld(void)
{
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		if (iosTouch_aSlots[i].touch && iosTouch_aSlots[i].role == ROLE_STICK) return 1;
	}
	return 0;
}

// a - b, in degrees, as -180..180
static CGFloat iosTouch_AngleDiff(CGFloat a, CGFloat b)
{
	CGFloat d = fmod(a - b, 360.0);
	if (d > 180.0) d -= 360.0;
	if (d < -180.0) d += 360.0;
	return d;
}

// whether the stick's thumb, this far from its centre, is on the run marker
// (once on, it stays on a little further back and further round)
static int iosTouch_OnRunMarker(CGPoint off, int bRunning)
{
	if (iosTouch_runDist <= 0.0 || iosTouch_bAlwaysRun) return 0;
	CGFloat dx = off.x, dy = -off.y;
	CGFloat d = sqrt(dx * dx + dy * dy);
	if (d < (bRunning ? IOSTOUCH_RUN_OFF : IOSTOUCH_RUN_ON)) return 0;
	CGFloat a = atan2(dy, dx) * 180.0 / M_PI;
	return fabs(iosTouch_AngleDiff(a, 90.0)) <= (bRunning ? IOSTOUCH_RUN_CONE_OFF : IOSTOUCH_RUN_CONE);
}

- (void)startStickAt:(CGPoint)p
{
	iosTouch_stickCentre = p;
	iosTouch_stickThumb = CGPointZero;
	iosTouch_bRunning = 0;
	// the run marker IOSTOUCH_RUN_DIST above, brought down to stay clear of the
	// top row and the screen's top; none if even IOSTOUCH_RUN_MIN_DIST won't fit
	CGFloat topLimit = aCentres[BTN_NEXTWPN].y + IOSTOUCH_TOP_R + IOSTOUCH_RUN_R + 4.0;
	CGFloat room = p.y - topLimit;
	iosTouch_runDist = room >= IOSTOUCH_RUN_DIST ? IOSTOUCH_RUN_DIST : (room >= IOSTOUCH_RUN_MIN_DIST ? room : 0.0);
	[self drawStick];
}

- (void)drawStick
{
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	int bShow = iosTouch_StickHeld();
	stickRing.hidden = stickKnob.hidden = !bShow;
	int bMarker = bShow && iosTouch_runDist > 0.0 && !iosTouch_bAlwaysRun;
	runMarker.hidden = runLabel.hidden = !bMarker;
	if (bShow) {
		CGPoint c = iosTouch_stickCentre;
		stickRing.path = [UIBezierPath bezierPathWithArcCenter:c radius:IOSTOUCH_STICK_RADIUS startAngle:0 endAngle:2 * M_PI clockwise:YES].CGPath;
		CGPoint k = CGPointMake(c.x + iosTouch_stickThumb.x, c.y + iosTouch_stickThumb.y);
		if (iosTouch_bRunning) k = CGPointMake(c.x, c.y - iosTouch_runDist);
		stickKnob.path = [UIBezierPath bezierPathWithArcCenter:k radius:IOSTOUCH_STICK_KNOB startAngle:0 endAngle:2 * M_PI clockwise:YES].CGPath;
		if (bMarker) {
			CGPoint m = CGPointMake(c.x, c.y - iosTouch_runDist);
			UIBezierPath* path = [UIBezierPath bezierPathWithArcCenter:m radius:IOSTOUCH_RUN_R startAngle:0 endAngle:2 * M_PI clockwise:YES];
			[path moveToPoint:CGPointMake(c.x, c.y - IOSTOUCH_STICK_RADIUS)];
			[path addLineToPoint:CGPointMake(c.x, m.y + IOSTOUCH_RUN_R)];
			runMarker.path = path.CGPath;
			runMarker.fillColor = iosTouch_bRunning ? [UIColor colorWithRed:1.0 green:0.8 blue:0.3 alpha:0.6].CGColor
													: [UIColor colorWithWhite:0.0 alpha:0.2].CGColor;
			runLabel.center = m;
		}
	}
	[CATransaction commit];
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
	if (iosTouch_mode == IOSTOUCH_MODE_SKIP) {
		// a tap anywhere skips (once, however many fingers)
		CFTimeInterval now = CACurrentMediaTime();
		if (now - lastSkip > 0.5) {
			lastSkip = now;
			IOS_Skip();
			[thump impactOccurred];
		}
		return;
	}
	for (UITouch* t in touches) {
		iosTouchSlot_t* s = iosTouch_SlotFor(t, 1);
		if (!s) continue;
		CGPoint p = [t locationInView:self];
		s->start = s->last = p;
		s->startTime = t.timestamp;
		int b = [self buttonAt:p];

		// an open tray closes on any touch off it, which still acts
		if (iosTouch_bTrayOpen && (b < BTN_FIRST_TRAY) && b != BTN_MENU) {
			[self setTrayOpen:0];
		}

		if (b >= 0) {
			s->role = ROLE_BUTTON;
			s->button = b;
			s->bInside = 1;
			[self pressButton:b slot:s];
		} else if (p.x < self.bounds.size.width * IOSTOUCH_STICK_ZONE && !iosTouch_StickHeld()) {
			s->role = ROLE_STICK;
			[self startStickAt:p];
		} else {
			s->role = ROLE_LOOK;
		}
	}
	[self refreshAlphas];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
	for (UITouch* t in touches) {
		iosTouchSlot_t* s = iosTouch_SlotFor(t, 0);
		if (!s) continue;
		CGPoint p = [t locationInView:self];
		CGFloat dx = p.x - s->last.x, dy = p.y - s->last.y;
		s->last = p;

		switch (s->role) {
		case ROLE_STICK: {
			CGPoint off = CGPointMake(p.x - iosTouch_stickCentre.x, p.y - iosTouch_stickCentre.y);
			int bRun = iosTouch_OnRunMarker(off, iosTouch_bRunning);
			if (bRun && !iosTouch_bRunning) [tick selectionChanged];
			iosTouch_bRunning = bRun;
			CGFloat d = sqrt(off.x * off.x + off.y * off.y);
			if (d > IOSTOUCH_STICK_RADIUS) {
				off.x *= IOSTOUCH_STICK_RADIUS / d;
				off.y *= IOSTOUCH_STICK_RADIUS / d;
			}
			iosTouch_stickThumb = off;
			[self drawStick];
			break;
		}
		case ROLE_LOOK:
			iosTouch_yaw -= (float)dx * IOSTOUCH_LOOK_DEG_X;
			iosTouch_pitch += (float)dy * IOSTOUCH_LOOK_DEG_Y;
			break;
		case ROLE_BUTTON: {
			const iosTouchButton_t* b = &iosTouch_aButtons[s->button];
			if (b->bLookWhileHeld) {
				// a button that looks: dragging turns the view, it stays pressed
				iosTouch_yaw -= (float)dx * IOSTOUCH_LOOK_DEG_X;
				iosTouch_pitch += (float)dy * IOSTOUCH_LOOK_DEG_Y;
				break;
			}
			s->bInside = [self isPoint:p onButton:s->button];
			// MENU held into its tray: the thumb can slide onto a tray button
			if (s->button == BTN_MENU && iosTouch_bTrayOpen) {
				int under = [self buttonAt:p];
				for (int i = BTN_FIRST_TRAY; i < NUM_BUTTONS; i++) {
					aButtonViews[i].alpha = (i == under) ? 1.0 : IOSTOUCH_IDLE_ALPHA;
				}
			}
			break;
		}
		default:
			break;
		}
	}
}

- (void)endTouches:(NSSet<UITouch*>*)touches cancelled:(int)bCancelled
{
	for (UITouch* t in touches) {
		iosTouchSlot_t* s = iosTouch_SlotFor(t, 0);
		if (!s) continue;
		if (s->role == ROLE_BUTTON && !bCancelled) {
			[self releaseButton:s->button slot:s at:s->last];
		}
		int bWasStick = s->role == ROLE_STICK;
		memset(s, 0, sizeof(*s));
		if (bWasStick) {
			iosTouch_stickThumb = CGPointZero;
			iosTouch_bRunning = 0;
			[self drawStick];
		}
	}
	[self refreshAlphas];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
	[self endTouches:touches cancelled:0];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
	[self endTouches:touches cancelled:1];
}

// ------------------------------------------------ the buttons' actions

- (void)pressButton:(int)b slot:(iosTouchSlot_t*)s
{
	switch (b) {
	case BTN_RELOAD:	IOS_Impulse(13); break;			// IMPULSE_13: reload
	case BTN_LIGHT:		IOS_Flashlight(); break;
	case BTN_NEXTWPN:	IOS_Impulse(14); break;			// IMPULSE_14: next weapon
	case BTN_PDA:		IOS_Impulse(19); break;			// IMPULSE_19: the PDA
	default:			break;
	}
}

- (void)releaseButton:(int)b slot:(iosTouchSlot_t*)s at:(CGPoint)p
{
	if (b == BTN_MENU) {
		if (iosTouch_bTrayOpen && s->bDone) {
			// held into the tray: lifted on one of its buttons, that one acts
			int under = [self buttonAt:p];
			if (under >= BTN_FIRST_TRAY) [self useTrayButton:under];
		} else if (iosTouch_bTrayOpen) {
			[self setTrayOpen:0];
		} else if (s->bInside) {
			IOS_PressKey(SDL_SCANCODE_ESCAPE);	// the game's menu
		}
		return;
	}
	if (iosTouch_aButtons[b].kind == KIND_TRAY) {
		if (b == BTN_TRAY_GYRO && s->bDone) return;	// (held: its options opened)
		if (s->bInside) [self useTrayButton:b];
	}
}

- (void)useTrayButton:(int)b
{
	switch (b) {
	case BTN_TRAY_GYRO:
		if (iosTouch_GyroAvailable()) iosTouch_GyroToggle();
		break;
	case BTN_TRAY_RUN:
		iosTouch_bAlwaysRun = !iosTouch_bAlwaysRun;
		[[NSUserDefaults standardUserDefaults] setBool:iosTouch_bAlwaysRun forKey:IOSTOUCH_ALWAYSRUN_DEFAULTS_KEY];
		break;
	case BTN_TRAY_FPS:
		IOS_Command(IOS_CVarInteger("com_showFPS") ? "com_showFPS 0" : "com_showFPS 1");
		[self setTrayOpen:0];
		return;
	case BTN_TRAY_KEYS:
		IOS_PressKey(SDL_SCANCODE_GRAVE);	// the console, with the keyboard
		[self setTrayOpen:0];
		return;
	case BTN_OPT_MODE:
		iosTouch_GyroNextMode();
		break;
	case BTN_OPT_SENS:
		iosTouch_GyroNextSens();
		break;
	}
	[tick selectionChanged];
	[self refreshLabels];
}

// held buttons that act after a time: QUICK SAVE, QUICK LOAD, MENU, GYRO
- (void)updateHolds
{
	CFTimeInterval now = [NSProcessInfo processInfo].systemUptime; // (the UITouch clock)
	CGFloat aFill[NUM_BUTTONS] = { 0 };
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		iosTouchSlot_t* s = &iosTouch_aSlots[i];
		if (!s->touch || s->role != ROLE_BUTTON || s->bDone) continue;
		int b = s->button;
		double hold = (iosTouch_aButtons[b].kind == KIND_HOLDTAP) ? IOSTOUCH_QUICKSAVE_HOLD
					: (b == BTN_MENU || b == BTN_TRAY_GYRO) ? IOSTOUCH_MENU_HOLD : 0.0;
		if (hold <= 0.0) continue;
		if (!s->bInside) continue;	// slid off: cancelled
		double f = (now - s->startTime) / hold;
		if (f < 1.0) {
			aFill[b] = fmax(aFill[b], f);
			continue;
		}
		s->bDone = 1;
		switch (b) {
		case BTN_QSAVE:	IOS_Command("savegame quick"); [thump impactOccurred]; break;
		case BTN_QLOAD:	IOS_Command("loadgame quick"); [thump impactOccurred]; break;
		case BTN_MENU:	[self setTrayOpen:1]; [tick selectionChanged]; break;
		case BTN_TRAY_GYRO: [self setOptsOpen:!iosTouch_bOptsOpen]; [tick selectionChanged]; break;
		}
	}
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	for (int b = 0; b < NUM_BUTTONS; b++) {
		if (aHoldRings[b]) aHoldRings[b].strokeEnd = aFill[b];
	}
	[CATransaction commit];
}

- (void)refreshAlphas
{
	int aHeld[NUM_BUTTONS] = { 0 };
	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		if (iosTouch_aSlots[i].touch && iosTouch_aSlots[i].role == ROLE_BUTTON) aHeld[iosTouch_aSlots[i].button] = 1;
	}
	for (int b = 0; b < NUM_BUTTONS; b++) {
		aButtonViews[b].alpha = aHeld[b] ? 1.0 : IOSTOUCH_IDLE_ALPHA;
	}
}

// every touch let go of, the stick and the tray put away
- (void)releaseAll
{
	memset(iosTouch_aSlots, 0, sizeof(iosTouch_aSlots));
	iosTouch_stickThumb = CGPointZero;
	iosTouch_bRunning = 0;
	iosTouch_yaw = iosTouch_pitch = 0.0f;
	[self setTrayOpen:0];
	[self drawStick];
	[self refreshAlphas];
}

// ------------------------------------------------ once a frame

- (void)frame:(int)mode
{
	if (mode != iosTouch_mode) {
		int wasConsole = iosTouch_mode == IOSTOUCH_MODE_CONSOLE;
		iosTouch_mode = mode;
		[self releaseAll];
		self.hidden = (mode == IOSTOUCH_MODE_HIDDEN);
		self.userInteractionEnabled = !self.hidden;	// hidden: a finger is SDL's mouse
		for (int i = 0; i < BTN_FIRST_TRAY; i++) {
			aButtonViews[i].hidden = (mode != IOSTOUCH_MODE_GAMEPLAY);
		}
		skipLabel.hidden = (mode != IOSTOUCH_MODE_SKIP);
		consoleKeysButton.hidden = consoleCloseButton.hidden = (mode != IOSTOUCH_MODE_CONSOLE);
		// the keyboard comes up with the console, and goes with it
		if (mode == IOSTOUCH_MODE_CONSOLE) {
			[consoleKeys becomeFirstResponder];
		} else if (wasConsole) {
			[consoleKeys resignFirstResponder];
		}
	}
	if (mode == IOSTOUCH_MODE_GAMEPLAY) {
		[self updateHolds];
	}
	iosTouch_GyroUpdate(mode == IOSTOUCH_MODE_GAMEPLAY, self);
}

@end

// ---------------------------------------------------------------- the C side

static IOSTouchOverlay* iosTouch_pOverlay = nil;

// SDL's view: the root view of its window
static UIView* iosTouch_GameView(void)
{
	for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) continue;
		for (UIWindow* w in ((UIWindowScene*)scene).windows) {
			if (w.isKeyWindow && w.rootViewController.view) return w.rootViewController.view;
		}
	}
	return nil;
}

void IOSTouch_Frame(int mode)
{
	UIView* game = iosTouch_GameView();
	if (!game) return;
	if (!iosTouch_pOverlay) {
		iosTouch_pOverlay = [[IOSTouchOverlay alloc] initWithFrame:game.bounds];
		iosTouch_pOverlay.hidden = YES;
		iosTouch_pOverlay.userInteractionEnabled = NO;
	}
	// (SDL can make its window again: follow its view)
	if (iosTouch_pOverlay.superview != game) {
		[iosTouch_pOverlay removeFromSuperview];
		iosTouch_pOverlay.frame = game.bounds;
		[game addSubview:iosTouch_pOverlay];
	}
	[game bringSubviewToFront:iosTouch_pOverlay];
	[iosTouch_pOverlay frame:mode];
}

void IOSTouch_TakeInput(iosTouchInput_t* input)
{
	memset(input, 0, sizeof(*input));
	if (iosTouch_mode != IOSTOUCH_MODE_GAMEPLAY) {
		iosTouch_yaw = iosTouch_pitch = 0.0f;
		return;
	}

	// the stick: eight ways, at walking speed (the keys' full move), or
	// straight ahead on the run marker
	if (iosTouch_StickHeld()) {
		CGFloat dx = iosTouch_stickThumb.x / IOSTOUCH_STICK_RADIUS;
		CGFloat dy = -iosTouch_stickThumb.y / IOSTOUCH_STICK_RADIUS;
		CGFloat d = sqrt(dx * dx + dy * dy);
		if (iosTouch_bRunning) {
			input->forward = 127;
			input->buttons |= IOSTOUCH_CMD_RUN;
		} else if (d >= IOSTOUCH_STICK_DEADZONE) {
			// within 22.5 degrees of an axis, that axis alone
			const CGFloat k = 0.3827; // sin(22.5)
			if (dy > k * d) input->forward = 127;
			else if (dy < -k * d) input->forward = -127;
			if (dx > k * d) input->right = 127;
			else if (dx < -k * d) input->right = -127;
		}
		// Always Run: the run button with any movement (stamina as vanilla)
		if (iosTouch_bAlwaysRun && (input->forward || input->right)) {
			input->buttons |= IOSTOUCH_CMD_RUN;
		}
	}

	for (int i = 0; i < IOSTOUCH_MAX_TOUCHES; i++) {
		const iosTouchSlot_t* s = &iosTouch_aSlots[i];
		if (!s->touch || s->role != ROLE_BUTTON) continue;
		switch (s->button) {
		case BTN_FIRE:		input->buttons |= IOSTOUCH_CMD_ATTACK; break;
		case BTN_JUMP:		input->up = 127; break;
		case BTN_CROUCH:	if (input->up == 0) input->up = -127; break;
		}
	}

	input->yaw = iosTouch_yaw;
	input->pitch = iosTouch_pitch;
	iosTouch_yaw = iosTouch_pitch = 0.0f;
}
