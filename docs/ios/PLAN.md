# DOOM 3 for iOS: plan

Two apps from one codebase: **DOOM 3** (base) and **DOOM 3: Resurrection of Evil** (d3xp).
The reference for how they should feel is your Jedi Knight port (OpenJKDF2-iOS, "JK") and your
Serious Sam port ("Sam"). Sam copied most of its touch, camera and cheat code from JK, so where the
two agree, that's the standard. Where they differ, it's flagged below for you to choose.

## Your decisions (26 Oct 2026)

- CI on today's code first, then update onto current dhewm3 (+ SDL3 + ANGLE) before Phases 2–4.
- Jedi Knight's stick and layout: walk by default, push onto the ^^ marker to run, dead zone 0.30.
  **Gameplay stays vanilla DOOM 3:** running drains stamina exactly as on PC. Any Always Run option
  is off by default and drains stamina too.
  - **The run marker, as Jedi Knight does it** (`iosTouch.m`):
    - A "^^" marker sits 100 pt above wherever the move stick appeared.
    - Pushing the thumb up onto it holds forward plus run (a selection-haptic tick as you reach it).
    - Coming back off it walks again.
    - The marker is hidden while Always Run is on.
  - **In DOOM 3** that "run" is the `_speed` button (`BUTTON_RUN`), exactly what Shift does on PC.
    So stamina drains while on the marker, and running stops by itself when stamina runs out, as
    vanilla does, in base and RoE alike.
  - **Always Run** is a tray option, off by default. Vanilla ignores `in_alwaysRun` in single player,
    so it holds `_speed` the same way. Stamina drains exactly as if you held Shift.
- DOOM 3's own menus; tomkidd's native launcher screens go.
- Work goes on branch `ios`; CI keeps the IPAs as artifacts; no public release.
- Rendering: ANGLE (relayed from another session; no Vulkan or native Metal work).

## Where things stand today

- tomkidd's fork from 2019–2021: dhewm3 plus an OpenGL ES renderer, SDL 2.0.12, Xcode 13 projects.
  It has never been built in CI.
- Before the game starts it shows native screens built in Swift: main menu, difficulty, saved games, options.
- Touch controls: a fixed joystick plus buttons that send fake key presses. There is no gyro, no
  controller layer of its own, and no haptics.
- Game data: it reads `base/` and `d3xp/` from inside the app bundle.

## Phase 0: CI build and game data (first)

- **CI** (`.github/workflows/ios.yml`): same shape as your ports. A `macos-15` runner, the newest
  non-beta Xcode, and a matrix building both apps with `xcodebuild` (arm64, no signing). Then an
  ad-hoc signature, `Payload/` zipped into `DOOM3-iOS-unsigned.ipa` and `DOOM3RoE-iOS-unsigned.ipa`,
  and `upload-artifact`.
  - Later, the same `ios-latest` prerelease as your ports (only if you want it; see the questions).
  - **ios-pipeline:** TestFlight goes through its `testflight-ipa.yml`, which takes an unsigned IPA
    from a release. Because this repo isn't in Sithewok-apps, its caller file has to live in
    ios-pipeline itself, and I only have read access there. When you want TestFlight, I'll write the
    ten-line caller for you to add, or you can give me write access.
- **Modernize:** arm64 only, minimum iOS 15, current Swift, and drop armv7/i386/simulator leftovers.
  Bundle ids `com.sithewok.doom3` and `com.sithewok.doom3roe`. Set `CFBundleVersion` to
  `$(CURRENT_PROJECT_VERSION)` and add `ITSAppUsesNonExemptEncryption` = NO, as ios-pipeline requires.
  - Keep the prebuilt curl only if it still links. DOOM 3 single player doesn't need it, so it can
    be switched off.
  - The tvOS targets will be left unbuilt (not deleted).
- **Game data in Documents:** `Sys_GetPath(PATH_BASE)` (`DOOM3/sys/osx/DOOMController.mm`) returns
  the Documents folder. Add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, so the
  folder shows up as Files > On My iPhone > DOOM 3.
  - Saves and config stay in Library (backed up, not cluttering Files).
  - Folder names are matched case-insensitively (a Windows/Steam copy can have `Base` or `PAK000.PK4`).
  - **First launch without data:** a proper native screen, better than your ports' "copy the files and
    relaunch" alert. It says exactly which folder to copy and where, and has a **Check again** button,
    so no relaunch is needed. For RoE it checks for both `base/` and `d3xp/`.
  - **Doesn't translate cleanly:** each app has its own Documents folder, so RoE needs its own copy
    of `base/` (about 1.5 GB more). iOS has no shared folder that's visible in Files. The alternative
    is one app that can launch either game. You asked for two apps, so I'm keeping two.
  - Never committed or bundled. CI checks that the IPA contains no `.pk4`.

## Phase 1: base and renderer (Metal via ANGLE)

The relayed decision is **ANGLE** (OpenGL ES drawn through Metal). That's also what JK uses. Steps:

1. Swap SDL 2.0.12 for **SDL3**, as JK uses. SDL3 creates an ANGLE (EGL) context on iOS natively and
   has the gamepad API JK's controller code is written for. That means JK's controller and touch code
   can be reused nearly as is.
2. Build ANGLE in CI (cached, the same way JK's workflow does) and run the existing ES renderer on it.
3. ProMotion 60/120 Hz, a resolution scale (render below or above native), safe areas and full
   widescreen, an FOV slider (`g_fov`), and an fps/thermal readout (JK's FPS tray button, plus the
   thermal state).

**Updating onto current dhewm3** (asked for in the relayed requirements) is the expensive part.
Current dhewm3 brings many fixes and its own gamepad support, including controller menu navigation.
But as far as I can tell it renders with desktop OpenGL, not ES, so tomkidd's ES renderer changes
would have to be carried forward onto it. My suggestion: do Phase 0 on the current code (it proves
the pipeline cheaply), then do the dhewm3 update **before** Phases 2–4. That way the controls,
cheats and camera are written once, on the base they'll stay on. I'd keep the iOS changes on a
pinned upstream as a set of patches, the way rebelancap's openQ4-ios does. **Your call; see the
questions.**

## Phase 2: menus and controls

### Menus (match your ports)
- **Your ports have no native menus.** The game's own menus are used directly: touch acts as the
  mouse, the iOS keyboard opens for text boxes, and a controller steps through items (D-pad/stick,
  A picks, B goes back). DOOM 3's menus are GUI files the same way, so this carries straight over.
  - That means **removing tomkidd's native Swift launcher screens** and booting into DOOM 3's own
    main menu (see the questions).
  - One DOOM 3 detail: a tap has to move the GUI cursor first, then click. Sam needed the same fix
    for its menus (`MenuOnTouchDown`).
- **MENU button:** tap = game menu (Escape). Hold 0.45 s with a ring = the tray.
  - The tray holds GYRO (tap = last mode; hold opens MODE and SENS), FPS, CAMERA switch, CHEAT
    switch, LEVEL (only while cheating), CONTROLS (NORMAL/SWAPPED) and keyboard (the console, for
    typed cheats).
  - It has JK's slide-or-tap behaviour, stays clear of the FIRE cluster, and a touch elsewhere both
    closes it and acts.
- **Controller options panel** (JK's `iosPadPanel`): hold Start 0.45 s. It has LOOK X/Y, CURVE,
  INVERT, ACCEL, VIBRATION and FPS, and the game holds still while it's open.

### Touch controls (the shared standard; numbers from JK, with Sam's where they differ)
Reused from JK's `iosTouch.m` (the C-core-plus-thin-UIKit split, in the shape Sam has):

| What | Value carried over |
|---|---|
| Move stick | Floats where the left thumb lands, in the left 42% of the screen. Radius 60, knob 24 |
| Look | Drag anywhere else. Drags starting on FIRE/JUMP/CROUCH also look. JK speed (1.6 / 1.3 mouse counts per point; Sam's 2.56 / 1.56 was tuned to the same turn speed) |
| FIRE | Radius 42, at right−76, bottom−58, kept clear of the HUD's right gauges |
| Arc buttons | Radius 29–31, on a 115 pt arc around FIRE at 180°/135°/90° |
| Top row | Radius 22 |
| Look of buttons | 0.65 alpha idle, full when touched. 6 pt touch slop. 8 pt minimum margin past the safe area (notch, Dynamic Island, home bar) |
| QUICK SAVE / LOAD | 0.3 s hold with a ring. Sliding off cancels. SAVE wins a tie |
| Wheel (NEXT WPN) | Tap = next. A 10 pt slide opens it at once. A 0.3 s hold opens it to tap. Bottom gap cancels. Hysteresis and leash. A haptic tick per slice. Game holds still while open. Ammo count under each weapon; not owned = faint, out of ammo = grey |
| Gyro | CoreMotion at 100 Hz, measured about gravity. OFF (default) / TOUCH / ALWAYS. SENS 1.0/1.5/2.0/3.0, default 1.5. 1.0 = the view turns as far as the phone. JK's smoothing and dead band. Off while a wheel, tray or menu is open |
| Haptics | Selection tick for wheel slices and level counting. Light impact for the shutter and for cheat/fly/noclip toggles |
| Remembered | NSUserDefaults, with the same key names as your ports (`iosTouchGyroMode`, `iosTouchGyroSens`, …) |

DOOM 3's button set: FIRE, JUMP, CROUCH, RELOAD, FLASHLIGHT, PDA, NEXT WPN (wheel),
QUICK SAVE, QUICK LOAD, CAMERA, CHEAT, MENU.
- **No USE button:** DOOM 3 works doors and screens by aiming at them and pressing FIRE.
- RoE's grabber and Artifact are weapons, so they go in the wheel.

**Differences between your two ports (please choose):**
1. **Move stick:**
   - JK: digital, dead zone 0.30, walks, with a "^^" run marker 100 pt above (push onto it to run, with a tick).
   - Sam: analog, dead zone 0.15, full speed at 0.30 (Sam is played running).
   - DOOM 3 has a run key and analog movement, so either works. I lean towards **JK's**: DOOM 3 is a
     slower, darker game, and running costs stamina in the base game.
2. **SENS location:** Sam has SENS as its own tray button. JK puts it under a held GYRO. I'll
   follow JK, the newer one.
3. **Controllers:** only JK has them (SDL gamepad, options panel, rumble on damage, wheel ticks and
   saves, LB/RB plus the right stick for the wheel, touch controls hiding while a pad is in use). Sam
   has none, so JK's is the one to copy. On SDL3 that covers DualSense, Xbox and Backbone.
   DualSense trigger effects would be extra (GCController), so they're not in this plan.

**Customization:** neither port has a layout editor (no moving or resizing buttons). JK only has
CONTROLS = SWAPPED, which mirrors the stick and the FIRE cluster. The relayed requirements mention
"the customization UI". There isn't one to copy, so I'll carry over SWAPPED. A drag-to-move editor
would be new work; tell me if you want it.

## Phase 3: cheat (the `sithewok` cheat, same UX)

- The tray's CHEAT switch shows the CHEAT button (remembered). Holding CHEAT 0.5 s toggles the cheat
  (grey = off, gold = on); a tap does nothing. Typing `sithewok` in the console also toggles it. The
  cheat starts off on every launch.
- **While on**, mapped to DOOM 3 equivalents:
  - god mode, `give all`, ammo kept full, and armor topped up
  - JUMP held 0.5 s = **FLY** (DOOM 3's `noclip` is the fly mode; a double-tap of JUMP lands)
  - **NOTARGET** goes where JK has ACT (there's no USE in DOOM 3): an extra tray toggle while cheating
  - small red labels under the buttons
- **LEVEL picker:** hold, then it counts maps every 0.4 s with a tick ("Level n of N"); lift to go.
  - The map list is read from `maps/game/*.map` in the game's own paks: 27 maps in base, 12 in RoE.
  - Loading a map starts it with your current weapons from `give all`.
- Fly and notarget end at each new level, as in your ports.
- **Flashlight:** in DOOM 3 and Resurrection of Evil (and the Phobos port's code) the flashlight has no
  battery: it's already unlimited, as in vanilla. The battery is a BFG Edition feature. If a supported
  game ever has one, cheat mode keeps it full.
- **Doesn't translate:**
  - JK's 4-star Force powers and Sam's network cheat bits: DOOM 3 is single player here.
  - Sam's pit rescue: DOOM 3 barely has pits. God mode covers most of it.
  - The voice line when the cheat comes on: could be a DOOM 3 sound from the game's own files (for
    example a marine's line). Optional.

## Phase 4: camera (photos and selfies, same UX)

- **CAMERA button:** tap = photo; hold still 0.5 s = selfie (1/3/5); slide sideways = burst (every
  0.2 s, up to 10); slide down = Action Freeze; slide up = cinematic burst.
  - Options: PHOTO kinds CLEAN / HUD / HUD+BTNS, SELFIES 1/3/5, FREEZE on/off.
- **Capture:** `glReadPixels` on the render thread, after the 3D view for CLEAN (no HUD) and after the
  HUD for HUD. Same budget of 6 images as your ports. HUD+BTNS draws the touch overlay on top, as
  yours do.
- **Saving:** Photos with add-only access (`NSPhotoLibraryAddUsageDescription`). If access is denied,
  `Documents/Screenshots` in Files. White flash, shutter sound 1108, light haptic, all after the
  capture so they don't appear in the shot.
- **DOOM 3 makes several pieces easy:**
  - `pm_thirdPerson`, `pm_thirdPersonRange` and `pm_thirdPersonAngle` give the selfie and
    third-person camera, with the player model drawn.
  - `g_showHud 0` hides the HUD and `ui_showGun 0` hides the weapon.
  - `g_stopTime` freezes the world for Action Freeze, and a free camera overrides the render view.
- **Selfie:**
  - Up to 8 nearest enemies turned to face the camera, each posed on a held frame of one of its own
    animations (DOOM 3's models have skeletons like JK's).
  - The player faces the camera.
  - Everything put back exactly afterwards; quick save is blocked while posed.
  - **Partly doesn't translate:** DOOM 3's player model has no "holding a phone" animation, so the
    player gets an existing pose (gun raised or idle), not JK's arm-out phone pose.
- **Cinematic burst:** 5 shots sweeping round the most interesting target, as JK and Sam do.

## Possible later: Doom 3: Phobos
Phobos ships its own game code, so stock dhewm3 can't run it. An unofficial dhewm3 port of that code
exists under the GPL (TwelveEyes/dhewm3-sdk, branch `tfphobos`, built from the RoE code as `tfphobos`).
It could be linked into the app as a third game, next to base and d3xp, and picked under Mods.
- Needs: base/ + d3xp/ (RoE) + the free Phobos files from ModDB in a `tfphobos/` folder.
- The port's own list of what's missing: the biohelmet (so some toxin areas are removed), clickable
  item and text-message GUIs, camera blur, bloom.
- Not started; your call.

## Other modernization (from the relayed list), in priority order
1. Mods: any extra `.pk4` dropped into `base/` or `d3xp/` in Files is loaded, as on PC.
2. Save management: saves listed in the game's own Load menu. Delete is in the game's menu already.
3. fps/thermal readout: in Phase 1, behind the FPS tray button.
4. visionOS: later, optional, not planned now.

## Testing
- Every step: a green CI build of both apps, plus a check that the IPA contains no game data.
- I can't run the game on a device or a Mac here. You test on the phone.
- Where it helps, I'll build a Linux rig (the engine with your local data, plus the overlay on a mock
  UIKit) like your ports use. That can't run your game data here, though: I don't have it.
