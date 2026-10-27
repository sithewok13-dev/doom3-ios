/*
===========================================================================

Doom 3 GPL Source Code
Copyright (C) 1999-2011 id Software LLC, a ZeniMax Media company.

This file is part of the Doom 3 GPL Source Code ("Doom 3 Source Code").

Doom 3 Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 Source Code.  If not, see <http://www.gnu.org/licenses/>.

===========================================================================
*/


/*
 * The touch controls (ios/IOSTouch.m) and the engine (sys/ios/ios_input.cpp)
 * talk through this: plain C, as one side is Objective-C.
 *
 * Touches never go through key bindings: what the stick, the look drags and
 * the buttons ask for goes straight into the usercmd being built
 * (idUsercmdGenLocal::MakeCurrent), as Serious Sam's port puts its touches
 * into the player's actions. One-off things (a weapon, the menu, a quick
 * save) are impulses, key presses or console commands.
 */

#ifndef __IOS_TOUCH_H__
#define __IOS_TOUCH_H__

#ifdef __cplusplus
extern "C" {
#endif

// What the touch controls hold for one usercmd
typedef struct {
	int		forward, right;		// -127..127, as the movement keys give
	int		up;					// 127 jumping, -127 crouching
	int		buttons;			// IOSTOUCH_CMD_*
	float	yaw, pitch;			// degrees to turn left and to tilt down since the last one
} iosTouchInput_t;

enum {
	IOSTOUCH_CMD_ATTACK	= 1 << 0,
	IOSTOUCH_CMD_RUN	= 1 << 1,	// the run marker, or Always Run (vanilla stamina either way)
	IOSTOUCH_CMD_SCORES	= 1 << 2,	// multiplayer: the scores (held)
};

// What the overlay shows for: in menus only a keyboard button (a finger is
// the mouse there), the controls in play, a tap to skip over cinematics and the story
// intro, a close button over the PDA (whose cursor goes where a finger is),
// and the console's keyboard and close buttons over the console
enum {
	IOSTOUCH_MODE_HIDDEN = 0,
	IOSTOUCH_MODE_GAMEPLAY,
	IOSTOUCH_MODE_SKIP,
	IOSTOUCH_MODE_PDA,
	IOSTOUCH_MODE_CONSOLE,
	IOSTOUCH_MODE_MENU,		// the menus: only a keyboard button (names in the multiplayer menus)
};

// One slot of the weapon wheel, as the game reports it (sys/ios/ios_game.h)
#define IOSTOUCH_MAX_WEAPONS 32
typedef struct {
	int		slot;				// the game's weapon number (def_weaponN)
	char	className[64];		// its entityDef (weapon_shotgun)
	char	name[48];			// as the game names it (Shotgun)
	int		owned, selectable;	// the player has it; has it and can switch to it (ammo)
	int		ammo;				// -1: it takes none
} iosTouchWeapon_t;

// the keys the on-screen keyboard sends the console besides text
enum {
	IOSTOUCH_KEY_BACKSPACE = 0,
	IOSTOUCH_KEY_ENTER,
};

// the overlay (ios/IOSTouch.m)
void	IOSTouch_Frame( int mode );						// once a frame, on the main thread
void	IOSTouch_TakeInput( iosTouchInput_t *input );	// as each usercmd is built
int		IOSTouch_GuiTouch( float *x, float *y, float *w, float *h );	// a finger on the PDA: where, and the screen's size (points)
float	IOSTouch_TakeGuiScroll( void );	// how far (points, + down) it dragged since the last call
void	IOSTouch_PhotoTaken( const char *path );	// a photo written there (PNG), for Photos; NULL: none

// the engine (sys/ios/ios_input.cpp), for the overlay
void	IOS_Impulse( int impulse );			// a weapon slot, reload, next weapon, the PDA...
void	IOS_Flashlight( void );				// whatever the game binds to F (the flashlight)
void	IOS_Command( const char *text );	// a console command, run next frame
void	IOS_PressKey( int sdlScancode );	// a key's press and release (Escape: the menu)
int		IOS_CVarInteger( const char *name );
void	IOS_Skip( void );					// skip the cinematic or the story intro
void	IOS_ConsoleText( const char *text );	// typed into the console (UTF-8)
void	IOS_ConsoleKey( int key );			// IOSTOUCH_KEY_*, into the console
void	IOS_CloseConsole( void );
int		IOS_GetWeapons( iosTouchWeapon_t *out, int max, int *current );	// the weapon wheel's slots, in the game's order
void	IOS_PickWeapon( int slot );			// switch to it
void	IOS_HoldGame( int hold );			// the game holds still while the wheel is open
void	IOS_Dismiss( void );				// a tap: the tip or objective showing goes away
void	IOS_SetCheat( int on );				// the cheat button: cheat mode on or off
void	IOS_ToggleFly( void );				// FLY (noclip), in cheat mode
void	IOS_GetCheats( int *on, int *flying );	// as the game has them now
void	IOS_TakePhoto( int selfie );		// the camera: a photo, or a selfie (third person, from the front)
void	IOS_StartFreeze( void );			// Action Freeze: the world stops, a free camera to look round it
void	IOS_EndFreeze( void );
void	IOS_CinemaBurst( void );			// five photos round the player, the world stopped meanwhile
int		IOS_Frozen( void );					// Action Freeze (or the cinematic burst) is on
int		IOS_InGame( void );					// a level is running, no menu over it
int		IOS_Multiplayer( void );			// a multiplayer game (no pausing, cheats or Action Freeze)
void	IOS_MenuText( const char *text );	// typed into a menu's text field (UTF-8; "\n" Enter)
void	IOS_MenuBackspace( void );
void	IOS_Connect( const char *address );	// join the game there (JOIN: Tailscale, or any address)
// The menus: the text field with the focus (0: none; another number,
// another field); the multiplayer games' list showing (JOIN there); the
// menu over a game in play, and back to it
intptr_t IOS_MenuTextField( void );
int		IOS_MenuServerList( void );
int		IOS_MenuOverGame( void );
void	IOS_ResumeGame( void );

// The levels of the game running (for the cheat's LEVEL), in its order
#define IOSTOUCH_MAX_LEVELS 64
typedef struct {
	char	name[64];		// as the game names it
	char	path[64];		// for the map command (game/mars_city1)
} iosTouchLevel_t;
int		IOS_GetLevels( iosTouchLevel_t *out, int max );
void	IOS_GoToLevel( const char *path );

// Cheat mode going on: its sound, Betruger's laugh, from the player's own
// DOOM 3 files
void	IOS_PlayCheatSound( void );

#ifdef __cplusplus
}
#endif

#endif /* !__IOS_TOUCH_H__ */
