<!--
  The GitHub release text for a release run of .github/workflows/ios.yml: a
  manual run of branch ios with "release" set to a tag such as ios-v0.1
  (gh workflow run ios.yml --ref ios -f release=ios-v0.1). The workflow
  publishes this file, as it is in the commit the run builds, as the release
  body (body_path). Update it before each release: the run stops before
  building unless this file has a "### What's in <tag>" heading line for that
  tag (for example "### What's in ios-v0.1"), written exactly like that and on
  a line of its own. A '-' in the version after "ios-" (ios-v0.2-beta1) makes
  a prerelease; without one (ios-v0.1) the release is marked as the latest
  release. Only the .ipa files named in RELEASE_IPAS in ios.yml are attached
  (DOOM3-iOS-unsigned.ipa: one app, both games). Links must be absolute:
  relative links don't resolve on a release page. Keep each paragraph and
  list item on one line: a release page turns every line break into a
  visible one.
-->

**DOOM 3 for iOS v0.1**: an unofficial iPhone build of the original 2004 *DOOM 3* and its expansion *Resurrection of Evil*, in one app, running on [dhewm3](https://dhewm3.org) (the open-source DOOM 3 engine), with on-screen touch controls made for it.

**You need your own copy of DOOM 3; no game files are included.** Buy it on [Steam](https://store.steampowered.com/app/208200/DOOM_3/) or [GOG](https://www.gog.com/game/doom_3), then copy the game's files from your computer onto your iPhone (see *Install*). Both come with the original 2004 DOOM 3 and Resurrection of Evil alongside the *BFG Edition*; only the original's files work here, not the BFG Edition's. A disc copy patched to 1.3.1 works too.

**One app for both games:** the app is called **DOOM 3** on your home screen (`DOOM3-iOS-unsigned.ipa`). It plays DOOM 3, and Resurrection of Evil too if you copy its files in as well.

**New here?** *Known limitations*, *Requirements* and *Install* are near the bottom of this page, just above the download.

### What's in ios-v0.1

The first release. What makes it fun:

- **Both games in one app:** DOOM 3 and, with its files, Resurrection of Evil, switched in the main menu (see *Switching games*). The app starts the game you played last.
- **Touch controls:** a move stick wherever your left thumb lands, with a **run marker** above it (push onto it to run; running uses stamina, as on PC), drag anywhere else to look, FIRE with JUMP, CROUCH, RELOAD and LIGHT (the flashlight) round it, and a top row with NEXT WPN, PDA, CAMERA, SAVE, LOAD and MENU.
- **Weapon wheel:** slide or hold NEXT WPN to see every weapon with its ammo and pick one.
- **MENU's hidden tray:** hold MENU for tilt aiming (GYRO), Always Run, look speed, an FPS counter, the cheat switch and the console with a keyboard.
- **Tilt aiming (gyro):** OFF, TOUCH or ALWAYS, with four sensitivities.
- **CAMERA:** photos of the game without the HUD, selfies, bursts, **Action Freeze** (stop the world and fly a camera round it) and a **cinematic burst**. Photos go to your Photos app.
- **The PDA by touch:** tap to click, drag to scroll, and a close button.
- **A main menu laid out for the phone:** DOOM 3's own menu filling the screen with a row of big buttons along the bottom, or the app's own **Modern** menu, or DOOM 3's menu exactly as it was. The settings have brightness, field of view, volume, look speed and whether the intro plays.
- **Cheat mode** (single player): god mode, every weapon and endless ammo (never a reload), a cheat menu with **Noclip**, **Notarget** and **Slow motion**, and a list of the game's levels to jump to.
- **Multiplayer (not tested yet):** DOOM 3's own multiplayer, with games on the same Wi-Fi found automatically, joining a game by its address, and **co-op and survival** for both games through [LibreCoop](https://github.com/Stradex/librecoop). It has never been tried between two phones, so it may well not work yet (see *Known limitations*).
- **Sound plays with the phone on silent,** as a game should.

---

### How to play: every control explained

The touch controls appear while you're playing and hide in the menus, the PDA, cinematics and while a level loads (there you tap, as you'd click with a mouse). The game runs in landscape, either way round.

Where everything is (on a phone, turn it sideways to see the whole picture):

```
 NEXT  PDA       CAMERA   CHEAT   SAVE  LOAD  MENU
 WPN
   [GYRO] [RUN] [LOOK] [OPACITY] [FPS] [CHEAT] [LEVEL] [kbd]
                   (MENU's tray, while it's open)

                                        LIGHT
                                             JUMP
                                     RELOAD
   ( o )  move stick: appears
          where your left thumb lands   CROUCH    FIRE
```

Exact positions shift a little to fit your screen, keeping clear of the notch or Dynamic Island and the home bar. CHEAT only shows once you've switched it on in the tray, and LEVEL only while cheat mode is on. Buttons are slightly see-through until you touch them, and a touch just beside a button still counts.

#### Moving and looking

- **Move:** put your left thumb down anywhere on the left part of the screen (a bit less than half of it) and the stick appears under it. Slide to walk; it walks however far you push it.
- **Run:** a small marker with a double chevron sits above the stick. Push your thumb up onto it to run straight ahead (you feel a tick as you get there); come back off it to walk again. Running is DOOM 3's own run, so it uses stamina exactly as holding Shift does on PC, and stops when your stamina runs out.
- **Always Run:** the tray's RUN button (the double chevron) switches it on, lit blue; the marker then hides and the stick always runs, still using stamina.
- **Look:** drag anywhere else on the screen. A drag that starts on FIRE, JUMP, CROUCH, RELOAD or LIGHT also looks round, so you can fire and aim with one thumb.
- **Look speed:** the tray's LOOK button steps through 0.5x, 0.75x, 1x, 1.25x, 1.5x, 2x, 2.5x and 3x; hold it to go back to the default, 1x. The same setting is the LOOK SPEED slider in the app's settings. It's remembered.

#### Buttons

- **FIRE:** hold to fire. DOOM 3 has no USE key: doors, lifts and computer screens work by aiming at them and pressing FIRE.
- **JUMP** and **CROUCH:** held for as long as you touch them.
- **RELOAD:** tap to reload.
- **LIGHT:** tap for the flashlight, as the F key does on PC. In DOOM 3 the flashlight is a weapon of its own, so you put your gun away to hold it.
- **NEXT WPN:** tap for the next weapon; slide or hold it for the weapon wheel (below).
- **PDA:** tap to open your PDA. On the PDA, your finger is the pointer: tap to click, drag to scroll its text and lists, and tap the close button in the corner (where MENU is) to put it away. In a multiplayer game this button is **SCORES**: hold it to see the scores.
- **Tips and objectives:** while one is on screen, a tap anywhere that isn't a button puts it away.
- **Cinematics and the intro:** tap anywhere to skip.

#### The weapon wheel (NEXT WPN)

- **Slide** your thumb off NEXT WPN (about 10 points) and the wheel opens at once: keep sliding toward a weapon and lift to take it.
- **Hold** NEXT WPN still for 0.3 s and the wheel opens to tap: tap a weapon.
- Each slice is one weapon, with its name and ammo, coloured by what it fires. A weapon you have but have no ammo for is dim and says *no ammo*; one you haven't found yet is faint and says *not found yet*.
- The gap at the bottom of the wheel cancels. You feel a tick as you move from slice to slice.
- In single player the game holds still while the wheel is open; in multiplayer it goes on.

#### SAVE and LOAD: a tap for the page, a short hold for quick save

- **Tap SAVE or LOAD** for DOOM 3's own Save Game or Load Game page.
- **Hold SAVE or LOAD for 0.3 s**, while a ring fills round the button, to quick save or quick load; sliding your finger off cancels, and if both are held, SAVE wins. The hold is there so a stray tap can't save over your quick save or throw away your progress.
- The game can't save or load during a multiplayer game; a tap there says so.

#### MENU and its hidden tray

- **Tap MENU** for the game's menu.
- **Hold MENU** for 0.45 s and a tray of buttons opens under the top row. Slide onto one and lift to use it, or lift first and tap. Tap MENU again, or anywhere else, to close it. The tray has:
  - **GYRO:** tap to switch tilt aiming off, or back on in the mode you used last. Hold it to open a second row with **MODE** (TOUCH or ALWAYS) and **SENS** (below).
  - **RUN:** Always Run on (lit blue) or off.
  - **LOOK:** the look speed (above).
  - **OPACITY:** tap for a slider under the tray that makes every control (but the tray) more see-through, down to 20%; hold it to go back to full. Remembered.
  - **FPS:** a small frame-rate counter at the bottom of the screen, on or off.
  - **CHEAT:** shows the CHEAT button and turns cheat mode on; tap again to hide it and turn cheat mode off. Hold it to choose the laugh you hear as cheat mode goes on (below).
  - **LEVEL:** only while cheat mode is on (below).
  - **Keyboard:** opens DOOM 3's console with a keyboard, for typing its commands.
  - Under the tray, in small dim text, the build you have (for example *build 41 · Nov 17*): handy when you report a bug.

#### Tilt aiming (gyro)

- **OFF** (the default): no tilt aiming.
- **TOUCH:** the phone's movement aims while a thumb is down on the stick, the look area or a button you can look with. Lift your thumbs and the view stays put, so you can move the phone back without turning.
- **ALWAYS:** the phone's movement always aims.
- **SENS:** 1.0x, 1.5x (the default), 2.0x or 3.0x. At 1.0x the view turns as far as the phone does.
- Your choices are remembered. Tilt aiming is off while a wheel, the tray or a menu is open.

#### The camera: photos, selfies, bursts and Action Freeze

CAMERA (the camera symbol) is in the middle of the top row. Every photo is of the game as you see it, without the HUD.

- **Tap** for a photo.
- **Hold still for 0.5 s** for a selfie: the view swings round to in front of you and takes one photo of you, then everything goes back as it was.
- **Slide sideways** for a burst: a photo every 0.25 s for as long as you hold it, up to 20.
- **Slide down** (a bit further, so not by chance) for **Action Freeze**: the world stops and the HUD hides. Move the camera with the stick, turn it by dragging, raise it with JUMP and lower it with CROUCH, and tap CAMERA for photos. The X where MENU was goes back to the game, exactly where you left it.
- **Slide up** for the **cinematic burst**: the moment stops and five photos are taken as the camera sweeps round you, then the game goes on.
- Photos go to your **Photos** app. The first time, iOS asks whether the app may add to your photos; if you say no, the photo isn't kept and the app says *Allow Photos in Settings to save*.
- In multiplayer, a tap or a burst still takes photos, a hold takes an ordinary photo instead of a selfie, and Action Freeze and the cinematic burst don't work (the game goes on for everyone else).

#### Multiplayer and co-op

- **Please read this first:** multiplayer and co-op have not been tried between two devices yet, so they may not work. Sorry! If you try them, please tell us how it went (see *Found a bug?*).
- **MULTIPLAYER** in the main menu is DOOM 3's own multiplayer menu, where you can start a game or join one. The first time, iOS asks whether the app may find devices on your local network: say yes, or other phones' games won't show.
- **Same Wi-Fi:** games started on other phones running this app on the same Wi-Fi appear in the list of games.
- **Join by address:** over the list of games, **JOIN** in the top corner lets you type a game's address. It also shows this phone's own addresses, to give to a friend. Over the internet, the free Tailscale app on each phone puts them on one private network: use the host's Tailscale address.
- **Co-op and survival** (from LibreCoop): switch to **Co-op: DOOM 3** or **Co-op: Resurrection of Evil** (see *Switching games*), then choose MULTIPLAYER. Everyone in the game needs the same game files.
- When you type a name in the multiplayer menus, the iOS keyboard comes up; Enter puts it away. Over a game in progress, an X where MENU is goes back to the game.

#### Cheat mode (single player)

- Switch it on with the tray's **CHEAT**: the CHEAT button (a pentagram in a ring) appears in the top row and cheat mode goes on, with a laugh from the game's own sounds (Dr. Betruger's, unless you pick another). Cheat mode is always off when the app starts; the button stays (greyed) until you hide it again from the tray.
- **Hold the CHEAT button for 0.5 s** (a ring of fire fills round it) to switch cheat mode on or off. Going on, the pentagram flashes and sends out embers; while on, it glows hell red and beats slowly like a heart.
- **While it's on:** god mode, every weapon, and endless ammo: every magazine stays full, so you never reload. It's put on again for each new level and each loaded game.
- **Tap the CHEAT button** for the cheat menu, whether cheat mode is on or not: **Noclip** (walk through walls), **Notarget** (the monsters take no notice of you) and **Slow motion**. A tap switches each on (gold) or off, and the menu stays open; touch anywhere else to close it. The game holds still while it's open. These end at each new level and when you load a game.
- **LEVEL** (in the tray while cheat mode is on): a list of the game's single-player levels, in order. Tap one to go there.
- **The laugh:** hold the tray's CHEAT for a list of the game's laughs; tap one to hear it and keep it.
- Cheat mode isn't available in multiplayer games, and the CHEAT button hides there.

#### Menus, settings, leaving the app, and the console

- **The main menu** starts as DOOM 3's own, filling the screen, with a row of big buttons along the bottom: **CONTINUE** (your newest save), **NEW GAME**, **LOAD GAME**, **MULTIPLAYER**, **MODS** and **OPTIONS**; over a game in progress, **RESUME**, **SAVE GAME**, **LOAD GAME**, **OPTIONS** and **MAIN MENU**. Its **STYLE** button (where *UPDATES* used to be) chooses **Classic** (that one), **Modern** (the app's own menu, with big buttons and your newest save to continue) or **Original** (DOOM 3's menu exactly as it was, with a *NEW MENU* button in the corner to come back). **MENU STYLE** in the settings chooses too.
- **Switching games:** **MODS** (in the Modern menu, **GAMES**) lists DOOM 3, Resurrection of Evil (once its files are in), Co-op: DOOM 3 and Co-op: Resurrection of Evil; tap one to switch to it.
- **OPTIONS** (in the Modern menu, **SETTINGS**) has BRIGHTNESS, FIELD OF VIEW, VOLUME, LOOK SPEED, PLAY INTRO AT START and MENU STYLE, and **MORE DOOM 3 SETTINGS** opens DOOM 3's own options (controls, sound, video).
- **New game:** with Resurrection of Evil installed, NEW GAME first asks which game, DOOM 3 or Resurrection of Evil (the one running is marked PLAYING NOW); picking the other switches to it. Then RECRUIT, MARINE and VETERAN; NIGHTMARE once the game has unlocked it.
- **The console:** the tray's keyboard button opens it with its own keyboard, with buttons to hide and show the keyboard and to close the console.
- **Leaving the app doesn't save your game.** Save first (hold SAVE for a quick save, or tap it for the Save Game page).

#### Small print

- Game controllers: dhewm3's own controller support is built in, but it hasn't been tried on an iPhone, and the touch controls stay on screen.
- The touch settings (gyro, look speed, Always Run, the CHEAT button and its laugh) are kept by iOS, not in the app's folder, and are remembered.

### Known limitations

**Sorry about the bugs.** This is an unofficial first release, made by a fan and tried by very few people so far. Expect bugs, and save often. Every report helps (see *Found a bug?*).

- **First release, limited testing:** it has been played a lot on one iPhone during development. Not tried yet: iPads (the app is marked for iPad, but has never been installed on one), game controllers, and game files from disc copies.
- **Multiplayer and co-op are untested:** they have never been tried between two phones, nor over the internet with Tailscale, so they may well not work yet. Sorry: that's the next thing to test and fix. Single player is what has been played.
- **Only the original DOOM 3 (2004) and Resurrection of Evil.** The BFG Edition's files don't work, and neither do mods that come with their own game code (only DOOM 3's, Resurrection of Evil's and LibreCoop's are built in).
- **Selfies** are one photo of you in an ordinary pose: DOOM 3 has no animation of the player holding a phone, and enemies aren't posed.
- **Photos need Photos access:** without it, photos aren't kept anywhere.
- **Your saves aren't in the Files app** (see *Install*), so you can't copy them out yourself.
- **No layout editor:** the buttons can't be moved or resized.
- **The app's own version number** is 1.0 (in your sideloading tool), not 0.1; this release is ios-v0.1.

### Requirements

- An **iPhone on iOS 18 or newer** (iPhone XS, XR or newer). The app is also marked for iPad, but has never been tried on one.
- **Your own PC copy of the original DOOM 3**, for its game files: Steam or GOG (both include the original game and Resurrection of Evil alongside the BFG Edition), or a disc copy patched to version 1.3.1. You'll need the computer it's installed on, to copy them to your iPhone.
  - For **DOOM 3**: the nine files `pak000.pk4` to `pak008.pk4` from its `base` folder, about 1.5 GB.
  - For **Resurrection of Evil** (optional): also `pak000.pk4` and `pak001.pk4` from its `d3xp` folder.
- A **sideloading tool or signing service** (something that installs apps from outside the App Store) that can install an app file (`.ipa`) you give it, for example SideStore or AltStore. The `.ipa` isn't signed for your iPhone, so it can't be installed without one. With a free Apple ID, apps installed this way must be refreshed every 7 days, and only 3 can be installed at once.

### Install

1. Download **`DOOM3-iOS-unsigned.ipa`**, below.
2. Install it with your sideloading tool or signing service, following that tool's own instructions (whether iOS asks you to trust a developer or to turn on Developer Mode depends on the tool). On your home screen the app is called **DOOM 3**.
3. **Open the app once.** With no game files yet, it shows a screen titled *Game files needed*, which says what to copy where, with a **Check Again** button. That's expected: by then the app has made its folder for your files, *On My iPhone > DOOM 3* in the Files app, with an empty `base` folder and an empty `d3xp` folder in it. Leave the app open.
4. On your computer, find the original DOOM 3's folder (in Steam: right-click DOOM 3, then *Manage > Browse local files*; in GOG Galaxy: *Manage installation > Show folder*). The folder you want has a `base` folder with `pak000.pk4` to `pak008.pk4` in it. If you see files ending in `.resources` instead, that's the BFG Edition: look for the other folder.
5. Copy the files into the Files app's **On My iPhone > DOOM 3**, keeping their names:
   - DOOM 3's `pak000.pk4` to `pak008.pk4` into the **`base`** folder there (everything else in DOOM 3's `base` folder can come too, but isn't needed);
   - for Resurrection of Evil, its `d3xp` folder's `pak000.pk4` and `pak001.pk4` into the **`d3xp`** folder there.

   Copy them directly into those folders, not inside another folder and not as a `.zip`. Use whatever way you like to get files into the Files app, for example a Mac's Finder or Windows' iTunes or Apple Devices app (*Files* for the DOOM 3 app), or iCloud Drive and then *Move* in the Files app. A copy from Windows with capital letters in the names (`Base`, `PAK000.PK4`) is fine: the app renames them.
6. Back in the app, tap **Check Again** (or open the app again). If the intro plays, tap to skip it to the main menu.
7. **For Resurrection of Evil,** switch to it in the main menu: tap **MODS**, then **Resurrection of Evil** (see *Switching games*). The app starts the game you played last, so next time it opens in Resurrection of Evil; choose DOOM 3 under MODS to go back.

**If the game files are missing:** the app checks for `base/pak000.pk4` in its folder. Until it's there, it keeps showing *Game files needed* and says *Not found yet: base/pak000.pk4* when you tap Check Again. Check that the files are directly in the `base` folder in *On My iPhone > DOOM 3*.

**LibreCoop's folders:** once your files are found, the app also puts a small `librecoop` folder (and, with Resurrection of Evil, `librecoopd3xp`) next to `base` and `d3xp`. They're LibreCoop's co-op mods, which come with the app: leave them there.

**Updating:** install a newer `.ipa` over this one with the same tool and the same Apple ID, and your game files, saves and settings stay.

**Your saves** are kept in the app's private storage, not in the Files app, so you can't copy them out. They're kept when you update the app the same way, and included in your iPhone's iCloud or computer backups, but **deleting the app deletes them**, along with the game files you copied in.

**Found a bug?** Please report it here, not to the upstream dhewm3 or LibreCoop projects, and say you're on **ios-v0.1** and which build (under MENU's tray; your sideloading app shows version 1.0): https://github.com/sithewok13-dev/doom3-ios/issues

**Download:** under *Assets* below: `DOOM3-iOS-unsigned.ipa`. The *iOS latest build* prerelease, also on the Releases page, is rebuilt automatically after every code change, before anyone has tried it: use this release.

---

**Thank you** to everyone whose work this app stands on:

- **id Software**, who made DOOM 3 and released its source code under the GPL in 2011 ([id-Software/DOOM-3](https://github.com/id-Software/DOOM-3)).
- **Daniel Gibson and the dhewm3 contributors**, who have kept that code running on today's computers for over a decade ([dhewm3](https://github.com/dhewm/dhewm3)). This app is dhewm3 1.5.5 underneath.
- **Tom Kidd** ([tomkidd](https://github.com/tomkidd)), whose [DOOM3-iOS](https://github.com/tomkidd/DOOM3-iOS) port this repository was forked from, with contributions from Dave Nicolson and Yoshi Sugawara; its OpenGL ES renderer still draws the game here.
- **Gabriel Cuvillier**, for [d3wasm](https://github.com/gabrielcuvillier/d3wasm), DOOM 3 in a web browser, whose OpenGL ES work that renderer shares.
- **Stradex**, for [LibreCoop](https://github.com/Stradex/librecoop), the co-op and survival modes.
- The people behind [SDL](https://www.libsdl.org), [OpenAL Soft](https://openal-soft.org) and [ANGLE](https://chromium.googlesource.com/angle/angle).

Unofficial build. DOOM 3 and DOOM 3: Resurrection of Evil are by id Software. This app is not made, endorsed or supported by id Software, Bethesda Softworks, ZeniMax Media or Microsoft, and is not affiliated with them. DOOM and id Software are trademarks of their owners.

This app is free software under the GNU GPL version 3 (https://github.com/sithewok13-dev/doom3-ios/blob/ios/dhewm3/COPYING.txt). It's built on [dhewm3](https://github.com/dhewm/dhewm3) by Daniel Gibson and contributors, from id Software's DOOM 3 GPL source code (https://github.com/id-Software/DOOM-3), with the OpenGL ES renderer from Tom Kidd's [DOOM3-iOS](https://github.com/tomkidd/DOOM3-iOS), which this repository was forked from, and Gabriel Cuvillier's [d3wasm](https://github.com/gabrielcuvillier/d3wasm), and co-op from Stradex's [LibreCoop](https://github.com/Stradex/librecoop) (GNU GPL v3, https://github.com/sithewok13-dev/doom3-ios/blob/ios/librecoop/COPYING.txt). Its source code, iOS changes included, is the `ios` branch: https://github.com/sithewok13-dev/doom3-ios/tree/ios (this release is the tag `ios-v0.1`: https://github.com/sithewok13-dev/doom3-ios/tree/ios-v0.1).

The app also includes libraries under their own licences: SDL 3 (zlib licence, https://github.com/libsdl-org/SDL/blob/release-3.4.12/LICENSE.txt); OpenAL Soft (GNU LGPL v2 or later, https://github.com/kcat/openal-soft/blob/1.24.3/COPYING; linked statically, and the full source and build scripts are in this repository, https://github.com/sithewok13-dev/doom3-ios/blob/ios/ios/build-deps.sh); ANGLE, which draws the game's OpenGL ES through Metal (BSD-style licence, https://github.com/google/angle/blob/main/LICENSE, with the third-party code built into it under the permissive licences listed in its source); and, inside dhewm3, stb_image, stb_image_write and stb_vorbis (public domain or MIT) and minizip (zlib licence).

<details>
<summary>Licence notices</summary>

**ANGLE** (BSD-style licence):

Copyright 2018 The ANGLE Project Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- Neither the name of TransGaming Inc., Google Inc., 3DLabs Inc. Ltd., nor the names of their contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

**SDL 3** (zlib licence): Copyright (C) 1997-2026 Sam Lantinga.

</details>
