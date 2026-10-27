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
 * The app's own main menu (ios/IOSMenu.m) over DOOM 3's, laid out for the
 * phone's screen: what it asks of the engine (sys/ios/ios_menu.cpp). Plain
 * C, as the menu is Objective-C. DOOM 3's own menu stays under it, a tap
 * away (its multiplayer, its other settings), and can be had instead.
 */

#ifndef __IOS_MENU_H__
#define __IOS_MENU_H__

#ifdef __cplusplus
extern "C" {
#endif

// where the menu is: over DOOM 3's main menu (0: not), over a game in play
int		IOS_MenuIsMain( void );
int		IOS_MenuInGame( void );
// the game running: 0 DOOM 3, 1 Resurrection of Evil, 2 LibreCoop's co-op
// (either game); its name as the menu says it
int		IOS_MenuGameKind( void );

// the saved games, newest first: the name given, the level's, when, and the
// screenshot's file (a TGA, "" if none) for the menu to show
#define IOS_MENU_MAX_SAVES 64
typedef struct {
	char	file[64];		// as loadGame takes it
	char	title[64];
	char	level[64];
	char	shot[512];
	long long time;			// seconds since 1970
} iosMenuSave_t;
int		IOS_MenuSaves( iosMenuSave_t *out, int max );

// the game's own menu commands, done between frames: a new game at a
// difficulty (0 Recruit .. 3 Nightmare), a saved game loaded, the game saved
// (named for its level and the time), back to the main menu, the game
// switched to (a mod folder; "" DOOM 3)
int		IOS_MenuNightmare( void );		// Nightmare unlocked (the game finished)
void	IOS_MenuNewGame( int skill );
void	IOS_MenuLoadGame( const char *file );
void	IOS_MenuSaveGame( void );
void	IOS_MenuQuitToMain( void );
#define IOS_MENU_MAX_MODS 16
typedef struct {
	char	dir[64];		// "" DOOM 3
	char	title[96];
} iosMenuMod_t;
int		IOS_MenuMods( iosMenuMod_t *out, int max, int *current );
void	IOS_MenuSwitchGame( const char *dir );

// DOOM 3's own menu: its button showing label pressed (MULTIPLAYER,
// OPTIONS...); 1 if there was one
int		IOS_MenuPressClassic( const char *label );

// settings: a cvar's value, and set
float	IOS_CVarFloat( const char *name );
void	IOS_SetCVar( const char *name, const char *value );

// the intro videos as the game starts (the app's setting)
int		IOS_PlayIntro( void );

// the menu style (the app's: 0 CLASSIC, DOOM 3's own main menu across the
// whole screen; 1 MODERN, the app's own; 2 ORIGINAL, DOOM 3's as it is)
int		IOS_MenuStyle( void );
// where the main menu shows label, in the 640 x 480 (4:3 in the middle of the
// screen); 1 if it does
int		IOS_MenuLabelRect( const char *label, float *x, float *y, float *w, float *h );

#ifdef __cplusplus
}
#endif

#endif /* !__IOS_MENU_H__ */
