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

// The engine's side of the app's own main menu (see sys/ios/ios_menu.h)

#include "sys/platform.h"
#include "idlib/LangDict.h"
#include "idlib/Lexer.h"
#include "framework/Licensee.h"
#include "framework/Common.h"
#include "framework/DeclManager.h"
#include "framework/DeclEntityDef.h"
#include "framework/CVarSystem.h"
#include "framework/CmdSystem.h"
#include "framework/FileSystem.h"
#include "framework/KeyInput.h"
#include "framework/Session_local.h"
#include "ui/UserInterface.h"
#include "sys/sys_public.h"
#include "sys/ios/ios_input.h"
#include "sys/ios/ios_menu.h"

// what the menu asked for since the last frame, done between frames (its
// taps come in the middle of one, as SDL pumps its events)
static int newGameSkill = -1;
static bool quitAsked;
static idStr classicLabel;

int IOS_MenuIsMain( void ) {
	return sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiMainMenu;
}

int IOS_MenuInGame( void ) {
	return sessLocal.mapSpawned && IOS_MenuIsMain();
}

int IOS_MenuGameKind( void ) {
	idStr game = cvarSystem->GetCVarString( "fs_game" );
	if ( game.Find( "librecoop", false ) >= 0 ) {
		return 2;
	}
	if ( game.Icmp( "d3xp" ) == 0 || idStr::Icmp( cvarSystem->GetCVarString( "fs_game_base" ), "d3xp" ) == 0 ) {
		return 1;
	}
	return 0;
}

/*
================
IOS_MenuSaves

The saved games of the game running, newest first, as the game's own Load
Game lists them: the name given and the level's from each one's .txt, its
screenshot's file
================
*/
int IOS_MenuSaves( iosMenuSave_t *out, int max ) {
	idStrList files;
	idList<fileTIME_T> times;
	sessLocal.GetSaveGameList( files, times );
	int n = 0;
	for ( int i = 0; i < times.Num() && n < max; i++ ) {
		const idStr &file = files[times[i].index];
		iosMenuSave_t &s = out[n++];
		memset( &s, 0, sizeof( s ) );
		idStr::Copynz( s.file, file, sizeof( s.file ) );
		idStr::Copynz( s.title, file, sizeof( s.title ) );
		idLexer src( LEXFL_NOERRORS | LEXFL_NOSTRINGCONCAT );
		if ( src.LoadFile( va( "savegames/%s.txt", file.c_str() ) ) ) {
			idToken tok;
			if ( src.ReadToken( &tok ) ) {
				idStr::Copynz( s.title, tok, sizeof( s.title ) );
			}
			if ( src.ReadToken( &tok ) ) {
				idStr::Copynz( s.level, tok, sizeof( s.level ) );
			}
		}
		idStr shot = fileSystem->RelativePathToOSPath( va( "savegames/%s.tga", file.c_str() ), "fs_savepath" );
		idStr::Copynz( s.shot, shot, sizeof( s.shot ) );
		s.time = (long long)times[i].timeStamp;
	}
	return n;
}

int IOS_MenuNightmare( void ) {
	return cvarSystem->GetCVarBool( "g_nightmare" );
}

void IOS_MenuNewGame( int skill ) {
	newGameSkill = skill;
}

void IOS_MenuLoadGame( const char *file ) {
	idStr name = file;
	name.Replace( "\"", "" );
	cmdSystem->BufferCommandText( CMD_EXEC_APPEND, va( "loadGame \"%s\"\n", name.c_str() ) );
}

// named for its level and the time, as a phone's photos are
void IOS_MenuSaveGame( void ) {
	idStr level = sessLocal.mapSpawnData.serverInfo.GetString( "si_map" );
	const idDecl *mapDef = declManager->FindType( DECL_MAPDEF, level, false );
	if ( mapDef ) {
		level = common->GetLanguageDict()->GetString( static_cast<const idDeclEntityDef *>( mapDef )->dict.GetString( "name", level ) );
	} else {
		level.StripPath();
	}
	time_t now = time( NULL );
	char when[32];
	strftime( when, sizeof( when ), "%b %d %H-%M", localtime( &now ) );
	idStr name = va( "%s %s", level.c_str(), when );
	name.Replace( "\"", "" );
	cmdSystem->BufferCommandText( CMD_EXEC_APPEND, va( "saveGame \"%s\"\n", name.c_str() ) );
}

void IOS_MenuQuitToMain( void ) {
	quitAsked = true;
}

/*
================
IOS_MenuMods

DOOM 3, then the mods the game finds (Resurrection of Evil and LibreCoop's
co-op among them), named as the menu says them
================
*/
static const char *IOS_ModTitle( const char *dir, const char *description ) {
	if ( idStr::Icmp( dir, "d3xp" ) == 0 ) {
		return "Resurrection of Evil";
	}
	if ( idStr::Icmp( dir, "librecoop" ) == 0 ) {
		return "Co-op: DOOM 3";
	}
	if ( idStr::Icmp( dir, "librecoopd3xp" ) == 0 ) {
		return "Co-op: Resurrection of Evil";
	}
	return ( description && description[0] ) ? description : dir;
}

int IOS_MenuMods( iosMenuMod_t *out, int max, int *current ) {
	const char *game = cvarSystem->GetCVarString( "fs_game" );
	int n = 0;
	*current = 0;
	if ( n < max ) {
		idStr::Copynz( out[n].dir, "", sizeof( out[n].dir ) );
		idStr::Copynz( out[n].title, "DOOM 3", sizeof( out[n].title ) );
		n++;
	}
	idModList *list = fileSystem->ListMods();
	for ( int i = 0; i < list->GetNumMods() && n < max; i++ ) {
		const char *dir = list->GetMod( i );
		if ( idStr::Icmp( dir, BASE_GAMEDIR ) == 0 ) {
			continue;
		}
		idStr::Copynz( out[n].dir, dir, sizeof( out[n].dir ) );
		idStr::Copynz( out[n].title, IOS_ModTitle( dir, list->GetDescription( i ) ), sizeof( out[n].title ) );
		if ( idStr::Icmp( dir, game ) == 0 ) {
			*current = n;
		}
		n++;
	}
	fileSystem->FreeModList( list );
	return n;
}

// as the game's Mods menu does it (Session_menu.cpp's loadMod): the mods
// built on Resurrection of Evil need it as their base
void IOS_MenuSwitchGame( const char *dir ) {
	static const char * const d3xpMods[] = { "librecoopd3xp", "d3le", "bloodmod_roe", "perfected_roe", "sikkmodd3xp" };
	const char *base = "";
	for ( int i = 0; i < (int)( sizeof( d3xpMods ) / sizeof( d3xpMods[0] ) ); i++ ) {
		if ( idStr::Icmp( dir, d3xpMods[i] ) == 0 ) {
			base = "d3xp";
		}
	}
	cvarSystem->SetCVarString( "fs_game", dir );
	cvarSystem->SetCVarString( "fs_game_base", base );
	cmdSystem->BufferCommandText( CMD_EXEC_APPEND, "reloadEngine menu\n" );
}

int IOS_MenuPressClassic( const char *label ) {
	float x, y;
	if ( !IOS_MenuIsMain() || !IOS_GuiFindLabel( sessLocal.guiMainMenu, label, &x, &y ) ) {
		return 0;
	}
	classicLabel = label;
	return 1;
}

float IOS_CVarFloat( const char *name ) {
	return cvarSystem->GetCVarFloat( name );
}

void IOS_SetCVar( const char *name, const char *value ) {
	cvarSystem->SetCVarString( name, value );
}

/*
================
IOS_MenuFrame

What the menu asked for, between frames
================
*/
void IOS_MenuFrame( void ) {
	if ( newGameSkill >= 0 ) {
		int skill = newGameSkill;
		newGameSkill = -1;
		if ( IOS_MenuIsMain() ) {
			// as the game's own menu starts one: its skill, then startGame
			// (the story intro comes next, as ever)
			const char *map = IOS_MenuGameKind() == 1 ? "game/erebus1" : "game/mars_city1";
			sessLocal.guiMainMenu->SetStateInt( "skill", skill );
			sessLocal.HandleMainMenuCommands( va( "startGame %s", map ) );
		}
	}
	if ( quitAsked ) {
		quitAsked = false;
		cmdSystem->BufferCommandText( CMD_EXEC_APPEND, "disconnect\n" );
	}
	if ( classicLabel.Length() > 0 ) {
		// the button's middle clicked, as a mouse would
		float x, y;
		if ( IOS_MenuIsMain() && IOS_GuiFindLabel( sessLocal.guiMainMenu, classicLabel, &x, &y ) ) {
			sessLocal.guiMainMenu->SetCursor( x, y );
			for ( int down = 1; down >= 0; down-- ) {
				sysEvent_t ev;
				memset( &ev, 0, sizeof( ev ) );
				ev.evType = SE_KEY;
				ev.evValue = K_MOUSE1;
				ev.evValue2 = down;
				sessLocal.ProcessEvent( &ev );
			}
		}
		classicLabel.Clear();
	}
}
