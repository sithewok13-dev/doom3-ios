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

// The touch controls' hooks in the engine (sys/ios/ios_input.cpp)

#ifndef __IOS_INPUT_H__
#define __IOS_INPUT_H__

class idVec3;
class usercmd_t;

void	IOS_TouchFrame( void );
void	IOS_AddTouchToUsercmd( usercmd_t &cmd, idVec3 &viewangles );
bool	IOS_GameHeld( void );	// the game holds still: the weapon wheel is open
void	IOS_MenuFrame( void );	// (sys/ios/ios_menu.cpp) what the app's menu asked for

// (ui/Window.cpp) the text or list under x, y in gui scrolled by lines
class idUserInterface;
void	IOS_ScrollGuiAt( idUserInterface *gui, float x, float y, float lines );
void *	IOS_GuiTextField( idUserInterface *gui );
bool	IOS_GuiListShown( idUserInterface *gui, const char *listName );
bool	IOS_GuiFindLabel( idUserInterface *gui, const char *label, float *x, float *y );

#endif /* !__IOS_INPUT_H__ */
