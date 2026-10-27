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

// The engine's side of the touch controls (see sys/ios/ios_touch.h)

#include <SDL3/SDL.h>

#include "sys/platform.h"
#include "idlib/math/Vector.h"
#include "framework/Common.h"
#include "framework/CVarSystem.h"
#include "framework/CmdSystem.h"
#include "framework/Console.h"
#include "framework/KeyInput.h"
#include "framework/UsercmdGen.h"
#include "framework/Session_local.h"
#include "sys/sys_public.h"
#include "sys/ios/ios_touch.h"
#include "sys/ios/ios_game.h"
#include "sys/ios/ios_input.h"

// a game report older than this (no game running, or it stopped) counts for nothing
static const int GAME_REPORT_MSEC = 500;

static struct {
	int		time;
	bool	pdaOpen;
	bool	inCinematic;
} gameReport;

// impulses asked for since the last usercmd, each sent in one of its own
static const int MAX_IMPULSES = 8;
static int impulses[MAX_IMPULSES];
static int numImpulses;

void IOS_GameReport( int pdaOpen, int inCinematic ) {
	gameReport.time = Sys_Milliseconds();
	gameReport.pdaOpen = pdaOpen != 0;
	gameReport.inCinematic = inCinematic != 0;
}

void IOS_Impulse( int impulse ) {
	if ( numImpulses < MAX_IMPULSES ) {
		impulses[numImpulses++] = impulse;
	}
}

void IOS_Flashlight( void ) {
	// the flashlight is a weapon slot in both games; use whatever F is bound to
	const char *binding = idKeyInput::GetBinding( 'f' );
	if ( idStr::Icmpn( binding, "_impulse", 8 ) == 0 ) {
		IOS_Impulse( atoi( binding + 8 ) );
	} else if ( binding[0] != '\0' ) {
		IOS_Command( binding );
	}
}

void IOS_Command( const char *text ) {
	cmdSystem->BufferCommandText( CMD_EXEC_APPEND, va( "%s\n", text ) );
}

void IOS_PressKey( int sdlScancode ) {
	for ( int down = 1; down >= 0; down-- ) {
		SDL_Event ev;
		memset( &ev, 0, sizeof( ev ) );
		ev.type = down ? SDL_EVENT_KEY_DOWN : SDL_EVENT_KEY_UP;
		ev.key.timestamp = SDL_GetTicksNS();
		ev.key.scancode = (SDL_Scancode)sdlScancode;
		ev.key.key = SDL_GetKeyFromScancode( (SDL_Scancode)sdlScancode, SDL_KMOD_NONE, false );
		ev.key.down = down != 0;
		SDL_PushEvent( &ev );
	}
}

int IOS_CVarInteger( const char *name ) {
	return cvarSystem->GetCVarInteger( name );
}

/*
================
IOS_TouchFrame

Once a frame: shows the touch controls in play, hides them wherever a finger
is the mouse (menus, the console, the PDA) and in cinematics.
================
*/
void IOS_TouchFrame( void ) {
	bool inGame = sessLocal.mapSpawned && sessLocal.guiActive == NULL && !console->Active();
	bool gameFresh = Sys_Milliseconds() - gameReport.time < GAME_REPORT_MSEC;
	if ( gameFresh && ( gameReport.pdaOpen || gameReport.inCinematic ) ) {
		inGame = false;
	}
	IOSTouch_Frame( inGame ? IOSTOUCH_MODE_GAMEPLAY : IOSTOUCH_MODE_HIDDEN );
}

/*
================
IOS_AddTouchToUsercmd

From idUsercmdGenLocal::MakeCurrent(), after the keys, mouse and controller
had their say: what the touch controls hold now.
================
*/
void IOS_AddTouchToUsercmd( usercmd_t &cmd, idVec3 &viewangles ) {
	iosTouchInput_t in;
	IOSTouch_TakeInput( &in );

	if ( in.forward != 0 ) {
		cmd.forwardmove = idMath::ClampChar( in.forward );
	}
	if ( in.right != 0 ) {
		cmd.rightmove = idMath::ClampChar( in.right );
	}
	if ( in.up != 0 ) {
		cmd.upmove = idMath::ClampChar( in.up );
	}
	if ( in.buttons & IOSTOUCH_CMD_ATTACK ) {
		cmd.buttons |= BUTTON_ATTACK;
	}
	if ( in.buttons & IOSTOUCH_CMD_RUN ) {
		cmd.buttons |= BUTTON_RUN;
	}

	viewangles[YAW] += in.yaw;
	viewangles[PITCH] += in.pitch;

	// one impulse per usercmd, as a key press sends it
	if ( numImpulses > 0 ) {
		cmd.impulse = impulses[0];
		cmd.flags ^= UCF_IMPULSE_SEQUENCE;
		numImpulses--;
		memmove( impulses, impulses + 1, numImpulses * sizeof( impulses[0] ) );
	}
}
