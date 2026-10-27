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
 * What the game code tells the app once a frame from idPlayer::Think() (in
 * both games, game/ and d3xp/): both are linked into the app, so they can
 * call it directly (see sys/ios/ios_main.mm).
 */

#ifndef __IOS_GAME_H__
#define __IOS_GAME_H__

#ifdef __cplusplus
extern "C" {
#endif

// the local player: whether the PDA is open, whether a cinematic plays
void	IOS_GameReport( int pdaOpen, int inCinematic );

// The local player's weapons, for the weapon wheel: the weapon wanted
// (idealWeapon), then each slot NextWeapon goes through, in its order, with
// its name, whether the player has it and can switch to it, and its ammo
// (-1: it takes none)
void	IOS_WeaponsBegin( int current );
void	IOS_WeaponSlot( int slot, const char *className, const char *name, int owned, int selectable, int ammo );
// the slot picked on the wheel since the last call, or -1
int		IOS_TakeWeaponPick( void );

// the PDA (an idUserInterface): a finger on it puts its cursor where it is,
// and dragged scrolls the text or list under it
void	IOS_RouteGuiTouch( void *gui );

// a tap on the screen since the last call: the tip or the objective showing
// goes away
int		IOS_TakeDismiss( void );

// The cheat button: whether cheat mode is wanted (god mode, every weapon and
// ammo, the monsters taking no notice), and *serial, which changes each
// time it's switched; FLY (noclip) asked for since the last call; and the
// local player's cheats as they are
int		IOS_CheatWanted( int *serial );
int		IOS_TakeFly( void );
void	IOS_CheatReport( int god, int noclip );

// The camera's Action Freeze: where the player's view is now (the free
// camera starts there); and whether the view is the free camera's, from org
// looking along angles (pitch, yaw, roll) -- circling pivot (*hasPivot),
// when it's to be kept out of the walls between them
void	IOS_ViewReport( const float *org, const float *angles );
int		IOS_FreezeCam( float *org, float *angles, float *pivot, int *hasPivot );

#ifdef __cplusplus
}
#endif

#endif /* !__IOS_GAME_H__ */
