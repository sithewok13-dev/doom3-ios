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
};

// What the overlay shows for: hidden in menus and the PDA (a finger is the
// mouse there), the controls in play, a tap to skip over cinematics and the
// story intro, and the console's keyboard and close buttons over the console
enum {
	IOSTOUCH_MODE_HIDDEN = 0,
	IOSTOUCH_MODE_GAMEPLAY,
	IOSTOUCH_MODE_SKIP,
	IOSTOUCH_MODE_CONSOLE,
};

// the keys the on-screen keyboard sends the console besides text
enum {
	IOSTOUCH_KEY_BACKSPACE = 0,
	IOSTOUCH_KEY_ENTER,
};

// the overlay (ios/IOSTouch.m)
void	IOSTouch_Frame( int mode );						// once a frame, on the main thread
void	IOSTouch_TakeInput( iosTouchInput_t *input );	// as each usercmd is built

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

#ifdef __cplusplus
}
#endif

#endif /* !__IOS_TOUCH_H__ */
