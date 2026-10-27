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
 * iOS: the app's entry point, its folders, and the game code.
 *
 * Folders: the player's own game files (base/, and d3xp/ for Resurrection of
 * Evil) are read from the app's Documents folder, which the Files app shows
 * as On My iPhone > DOOM 3. Saves and the config go to Library/Application
 * Support/dhewm3: backed up, but out of the way in Files.
 *
 * Game code: iOS can't load libraries at run time, so both games are linked
 * in (see the end of CMakeLists.txt) as GetGameAPI_base and GetGameAPI_d3xp.
 * Sys_DLL_Load() hands those out by library name, so the engine loads and
 * switches games (fs_game, the Mods menu) just as it does on other systems.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "sys/platform.h"
#include "idlib/Str.h"
#include "framework/Licensee.h"
#include "framework/Common.h"
#include "framework/CVarSystem.h"
#include "framework/Game.h"
#include "sys/sys_local.h"
#include "sys/posix/posix_public.h"

// the app around the engine (ios/IOSGameData.m)
extern "C" void IOS_WaitForGameData( void );
extern "C" bool IOS_HasGameFolder( const char *folder );

extern "C" gameExport_t *GetGameAPI_base( gameImport_t *import );
extern "C" gameExport_t *GetGameAPI_d3xp( gameImport_t *import );

static char base_path[MAXPATHLEN];
static char exe_path[MAXPATHLEN];
static char save_path[MAXPATHLEN];

// the game played last, started again next time
static NSString * const lastGameKey = @"dhewm3LastGame";

const char* Posix_GetExePath() {
	return exe_path;
}

const char* Posix_GetSavePath() {
	return save_path;
}

bool Sys_GetPath( sysPath_t type, idStr &path ) {
	switch ( type ) {
	case PATH_BASE:
		path = base_path;
		return true;

	case PATH_CONFIG:
	case PATH_SAVE:
		path = save_path;
		return true;

	case PATH_EXE:
		path = exe_path;
		return true;
	}

	return false;
}

void Sys_Shutdown( void ) {
	Posix_Shutdown();
}

int Sys_GetSystemRam( void ) {
	return (int)( [NSProcessInfo processInfo].physicalMemory / ( 1024 * 1024 ) );
}

void Sys_DoStartProcess( const char *exeName, bool dofork ) {
	common->Printf( "Sys_DoStartProcess: not on iOS (%s)\n", exeName );
}

void idSysLocal::OpenURL( const char *url, bool quit ) {
	NSURL *nsurl = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
	if ( nsurl ) {
		[[UIApplication sharedApplication] openURL:nsurl options:@{} completionHandler:nil];
	}
}

// MACOS_X helpers that framework/ code asks for on every Apple platform
const char* OSX_GetLocalizedString( const char* key ) {
	return key;
}

void OSX_GetVideoCard( int& outVendorId, int& outDeviceId ) {
	outVendorId = -1;
	outDeviceId = -1;
}

bool OSX_GetCPUIdentification( int& cpuId, bool& oldArchitecture ) {
	cpuId = 0;
	oldArchitecture = false;
	return true;
}

/*
==================
The game code, linked in. A "library" handle is 1 + its index here.
==================
*/
static const struct {
	const char *name;	// library name the engine asks for, without its suffix
	GetGameAPI_t getGameAPI;
} gameModules[] = {
	{ "base", GetGameAPI_base },
	{ "d3xp", GetGameAPI_d3xp },
};

uintptr_t Sys_DLL_Load( const char *path ) {
	idStr name = path;
	name.StripPath();
	name.StripFileExtension();
	for ( int i = 0; i < (int)( sizeof( gameModules ) / sizeof( gameModules[0] ) ); i++ ) {
		if ( name.Icmp( gameModules[i].name ) == 0 ) {
			return i + 1;
		}
	}
	return 0;
}

void* Sys_DLL_GetProcAddress( uintptr_t handle, const char *sym ) {
	int i = (int)handle - 1;
	if ( i < 0 || i >= (int)( sizeof( gameModules ) / sizeof( gameModules[0] ) ) || idStr::Cmp( sym, "GetGameAPI" ) != 0 ) {
		return NULL;
	}
	return (void *)gameModules[i].getGameAPI;
}

void Sys_DLL_Unload( uintptr_t handle ) {
}

static void SetPaths( void ) {
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *docs = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES )[0];
	idStr::Copynz( base_path, [docs fileSystemRepresentation], sizeof( base_path ) );

	idStr::Copynz( exe_path, [[[NSBundle mainBundle] executablePath] fileSystemRepresentation], sizeof( exe_path ) );

	NSString *support = NSSearchPathForDirectoriesInDomains( NSApplicationSupportDirectory, NSUserDomainMask, YES )[0];
	NSString *save = [support stringByAppendingPathComponent:@"dhewm3"];
	[fm createDirectoryAtPath:save withIntermediateDirectories:YES attributes:nil error:nil];
	idStr::Copynz( save_path, [save fileSystemRepresentation], sizeof( save_path ) );
}

int main( int argc, char *argv[] ) {
	@autoreleasepool {
		// until the player's game files are in Documents, a native screen
		// says what to copy where
		IOS_WaitForGameData();

		SetPaths();
	}

	// some C libraries' locale settings break scanf, strtod etc. with ','
	// as the radix, as on Linux
	setenv( "LC_ALL", "C", 1 );

	Posix_InitSignalHandlers();

	// start the game played last, if its files are still there
	NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:lastGameKey];
	idStr lastGame = saved ? [saved UTF8String] : "";
	idStrList args;
	for ( int i = 1; i < argc; i++ ) {
		args.Append( argv[i] );
	}
	if ( lastGame.Length() > 0 && lastGame.Icmp( BASE_GAMEDIR ) != 0 && IOS_HasGameFolder( lastGame.c_str() ) ) {
		args.Append( "+set" );
		args.Append( "fs_game" );
		args.Append( lastGame );
	}
	idList<const char *> cargs;
	for ( int i = 0; i < args.Num(); i++ ) {
		cargs.Append( args[i].c_str() );
	}
	common->Init( cargs.Num(), (char **)cargs.Ptr() );

	while ( 1 ) {
		@autoreleasepool {
			common->Frame();

			// remember a game switch (the Mods menu sets fs_game and restarts)
			const char *game = cvarSystem->GetCVarString( "fs_game" );
			if ( lastGame.Icmp( game ) != 0 ) {
				lastGame = game;
				[[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithUTF8String:game] forKey:lastGameKey];
			}
		}
	}
	return 0;
}
