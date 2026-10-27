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
#include "framework/async/AsyncNetwork.h"
#include "ui/UserInterface.h"
#include "framework/FileSystem.h"
#include "framework/DeclManager.h"
#include "sound/sound.h"
#include "renderer/RenderSystem.h"
#include "idlib/LangDict.h"
#include "sys/sys_public.h"
#include "sys/ios/ios_touch.h"
#include "sys/ios/ios_game.h"
#include "sys/ios/ios_input.h"
#include "sys/ios/ios_net.h"
#include "sys/ios/ios_menu.h"

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

// what the overlay asked for since the last frame, done after it (the
// overlay's callbacks come in the middle of one, as SDL pumps its events)
// the local player's weapons, as the game last reported them
static iosTouchWeapon_t weapons[IOSTOUCH_MAX_WEAPONS];
static int numWeapons;
static int currentWeapon = -1;
static int weaponPick = -1;

// the weapon wheel is open: no game frames run (as under a menu)
static bool gameHeld;

// a tap asked the tip or objective showing to go
static bool dismissAsked;

// the menu over a game asked to go, back to the game
static bool resumeAsked;

// the cheat button, and the cheats as the game last reported them
static int cheatWanted;
static int cheatSerial;
static bool flyAsked;
static bool cheatGod, cheatNoclip;

// the camera: a photo asked for; a selfie waits for the third person view
// to be drawn before it's taken
enum { PHOTO_NONE = 0, PHOTO_ASKED, SELFIE_ASKED, SELFIE_TURNING };
static int photoState;
static int photoTime;
static const int SELFIE_TURN_MSEC = 150;
static const char * const PHOTO_FILE = "ios_photo.png";

// Action Freeze: the world stopped (g_stopTime: only the player thinks), and
// a free camera the stick, a drag (the look) and JUMP and CROUCH (up and
// down) move, starting at the player's view; the player stays still. The
// cinematic burst: IOS_CINEMA_SHOTS photos from in front of the player,
// round it, IOS_CINEMA_MSEC apart (the view drawn from each before it's
// taken), then the world goes on.
static const float IOS_FREEZE_SPEED = 4.0f;		// units a usercmd, the stick right out
static const int IOS_CINEMA_SHOTS = 5;
static const int IOS_CINEMA_MSEC = 120;
static const float IOS_CINEMA_RANGE = 90.0f;
static const float IOS_CINEMA_STEP = 30.0f;		// degrees round between shots
static bool frozen;
static idVec3 freezeOrg;
static idAngles freezeAngles;
static bool freezePivotOn;
static idVec3 freezePivot;
static idStr freezeStopTime, freezeHud;
static idVec3 viewOrg;
static idAngles viewAngles( 0.0f, 0.0f, 0.0f );
static int cinemaShot = -1;		// the next one (-1: no burst)
static bool cinemaPlaced;
static int cinemaTime;

static void IOS_Shoot( void );

static bool skipAsked;

// The intro videos (the id logo) as the game starts, over the main menu:
// for this long, or until a tap skips them
static const int INTRO_MSEC = 10000;
static int introStart = -1;		// when the main menu first showed (-1: not yet)
static bool introOver;

static bool closeConsoleAsked;
static idList<sysEvent_t> consoleEvents;

void IOS_GameReport( int pdaOpen, int inCinematic ) {
	gameReport.time = Sys_Milliseconds();
	gameReport.pdaOpen = pdaOpen != 0;
	gameReport.inCinematic = inCinematic != 0;
}

void IOS_WeaponsBegin( int current ) {
	numWeapons = 0;
	currentWeapon = current;
}

void IOS_WeaponSlot( int slot, const char *className, const char *name, int owned, int selectable, int ammo ) {
	if ( numWeapons >= IOSTOUCH_MAX_WEAPONS ) {
		return;
	}
	iosTouchWeapon_t &w = weapons[numWeapons++];
	w.slot = slot;
	idStr::Copynz( w.className, className, sizeof( w.className ) );
	idStr::Copynz( w.name, name, sizeof( w.name ) );
	w.owned = owned;
	w.selectable = selectable;
	w.ammo = ammo;
}

int IOS_TakeWeaponPick( void ) {
	int pick = weaponPick;
	weaponPick = -1;
	return pick;
}

int IOS_GetWeapons( iosTouchWeapon_t *out, int max, int *current ) {
	int n = Min( numWeapons, max );
	memcpy( out, weapons, n * sizeof( weapons[0] ) );
	*current = currentWeapon;
	return n;
}

void IOS_PickWeapon( int slot ) {
	weaponPick = slot;
}

void IOS_HoldGame( int hold ) {
	gameHeld = hold != 0;
}

bool IOS_GameHeld( void ) {
	// (a multiplayer game goes on for everyone else: never held)
	return gameHeld && !idAsyncNetwork::IsActive();
}

int IOS_Multiplayer( void ) {
	return idAsyncNetwork::IsActive();
}

/*
================
IOS_MenuText

Typing into a menu's text field (a player or server name): as a keyboard's
typing comes, SDL's text input events. (Their text is copied as they are
read: a few buffers in turn are kept long enough.)
================
*/
void IOS_MenuText( const char *text ) {
	static char buffers[16][32];
	static int next;
	for ( const char *c = text; *c; ) {
		if ( *c == '\n' || *c == '\r' ) {
			IOS_PressKey( SDL_SCANCODE_RETURN );
			c++;
			continue;
		}
		char *buf = buffers[next];
		next = ( next + 1 ) % 16;
		int n = 0;
		while ( *c && *c != '\n' && *c != '\r' && n < (int)sizeof( buffers[0] ) - 1 ) {
			buf[n++] = *c++;
		}
		buf[n] = '\0';
		SDL_Event ev;
		memset( &ev, 0, sizeof( ev ) );
		ev.type = SDL_EVENT_TEXT_INPUT;
		ev.text.timestamp = SDL_GetTicksNS();
		ev.text.text = buf;
		SDL_PushEvent( &ev );
	}
}

void IOS_Connect( const char *address ) {
	idStr adr = address;
	adr.StripLeading( ' ' );
	adr.StripTrailingWhitespace();
	if ( adr.Length() > 0 && adr.Find( ';' ) < 0 && adr.Find( '"' ) < 0 ) {
		IOS_Command( va( "connect %s", adr.c_str() ) );
	}
}

intptr_t IOS_MenuTextField( void ) {
	return (intptr_t)IOS_GuiTextField( sessLocal.guiActive );
}

int IOS_MenuServerList( void ) {
	return sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiMainMenu
		&& IOS_GuiListShown( sessLocal.guiMainMenu, "serverList" );
}

int IOS_MenuOverGame( void ) {
	return sessLocal.mapSpawned && sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiMainMenu;
}

void IOS_ResumeGame( void ) {
	resumeAsked = true;
}

void IOS_MenuBackspace( void ) {
	IOS_PressKey( SDL_SCANCODE_BACKSPACE );
}

void IOS_SetCheat( int on ) {
	cheatWanted = on != 0;
	cheatSerial++;
}

int IOS_CheatWanted( int *serial ) {
	*serial = cheatSerial;
	return cheatWanted;
}

void IOS_ToggleFly( void ) {
	flyAsked = true;
}

int IOS_TakeFly( void ) {
	int asked = flyAsked;
	flyAsked = false;
	return asked;
}

void IOS_CheatReport( int god, int noclip ) {
	cheatGod = god != 0;
	cheatNoclip = noclip != 0;
}

void IOS_GetCheats( int *on, int *flying ) {
	bool fresh = Sys_Milliseconds() - gameReport.time < GAME_REPORT_MSEC;
	*on = fresh && cheatGod;
	*flying = fresh && cheatNoclip;
}

int IOS_InGame( void ) {
	return sessLocal.mapSpawned && sessLocal.guiActive == NULL && !console->Active();
}

void IOS_ViewReport( const float *org, const float *angles ) {
	viewOrg.Set( org[0], org[1], org[2] );
	viewAngles.Set( angles[0], angles[1], angles[2] );
}

int IOS_FreezeCam( float *org, float *angles, float *pivot, int *hasPivot ) {
	if ( !frozen ) {
		return 0;
	}
	for ( int i = 0; i < 3; i++ ) {
		org[i] = freezeOrg[i];
		angles[i] = freezeAngles[i];
		pivot[i] = freezePivot[i];
	}
	*hasPivot = freezePivotOn;
	return 1;
}

int IOS_Frozen( void ) {
	return frozen;
}

void IOS_StartFreeze( void ) {
	if ( frozen || !IOS_InGame() || IOS_Multiplayer() ) {
		return;
	}
	frozen = true;
	freezeOrg = viewOrg;
	freezeAngles = viewAngles;
	freezeAngles.roll = 0.0f;
	freezePivotOn = false;
	freezeStopTime = cvarSystem->GetCVarString( "g_stopTime" );
	freezeHud = cvarSystem->GetCVarString( "g_showHud" );
	cvarSystem->SetCVarBool( "g_stopTime", true );
	cvarSystem->SetCVarBool( "g_showHud", false );
}

void IOS_EndFreeze( void ) {
	if ( !frozen ) {
		return;
	}
	frozen = false;
	cinemaShot = -1;
	cvarSystem->SetCVarString( "g_stopTime", freezeStopTime );
	cvarSystem->SetCVarString( "g_showHud", freezeHud );
}

void IOS_CinemaBurst( void ) {
	if ( frozen ) {
		return;
	}
	IOS_StartFreeze();
	if ( frozen ) {
		cinemaShot = 0;
		cinemaPlaced = false;
		cinemaTime = Sys_Milliseconds();
	}
}

// the cinematic burst: each shot's camera placed, drawn, then taken
static void IOS_DoCinema( void ) {
	if ( cinemaShot < 0 ) {
		return;
	}
	if ( !IOS_InGame() ) {
		IOS_EndFreeze();
		return;
	}
	if ( !cinemaPlaced ) {
		// in front of the player, looking back at them, sweeping round
		float yaw = viewAngles.yaw + 180.0f + ( cinemaShot - ( IOS_CINEMA_SHOTS - 1 ) * 0.5f ) * IOS_CINEMA_STEP;
		freezePivot = viewOrg - idVec3( 0.0f, 0.0f, 12.0f );
		freezePivotOn = true;
		idVec3 dir = idAngles( 0.0f, yaw, 0.0f ).ToForward();
		freezeOrg = freezePivot + dir * IOS_CINEMA_RANGE + idVec3( 0.0f, 0.0f, 16.0f );
		freezeAngles.Set( 8.0f, yaw + 180.0f, 0.0f );
		cinemaPlaced = true;
		cinemaTime = Sys_Milliseconds();
	} else if ( Sys_Milliseconds() - cinemaTime >= IOS_CINEMA_MSEC ) {
		IOS_Shoot();
		cinemaPlaced = false;
		if ( ++cinemaShot >= IOS_CINEMA_SHOTS ) {
			IOS_EndFreeze();
		}
	}
}

void IOS_TakePhoto( int selfie ) {
	if ( photoState == PHOTO_NONE ) {
		// (frozen, the free camera's view is the photo)
		// (multiplayer: the third person view is everyone's, so no selfie)
		photoState = ( selfie && !frozen && !IOS_Multiplayer() ) ? SELFIE_ASKED : PHOTO_ASKED;
	}
}

/*
================
IOS_GetLevels

The single player levels of the game running, as its map list (mapDef
decls) names them, in its order: the ones under game/, not the
multiplayer ones
================
*/
int IOS_GetLevels( iosTouchLevel_t *out, int max ) {
	int n = 0;
	int num = fileSystem->GetNumMaps();
	for ( int i = 0; i < num && n < max; i++ ) {
		const idDict *dict = fileSystem->GetMapDecl( i );
		if ( !dict ) {
			continue;
		}
		const char *path = dict->GetString( "path" );
		if ( idStr::Icmpn( path, "game/", 5 ) != 0 || idStr::FindText( path, "/mp/", false ) >= 0 ) {
			continue;
		}
		const char *name = dict->GetString( "name" );
		if ( name[0] == '\0' ) {
			name = path;
		}
		idStr::Copynz( out[n].name, common->GetLanguageDict()->GetString( name ), sizeof( out[n].name ) );
		idStr::Copynz( out[n].path, path, sizeof( out[n].path ) );
		n++;
	}
	return n;
}

/*
================
IOS_PlayCheatSound

Cheat mode going on: Betruger's laugh -- the other one of his than "betruger
laugh 01" (as its list showed his sound shaders, underscores as spaces),
which the player tried first and passed over. From the player's own DOOM 3
files, found by its name (failing another, that one).
================
*/
void IOS_PlayCheatSound( void ) {
	static idStr found;
	static bool looked;
	if ( !looked ) {
		looked = true;
		idStr first;
		int num = declManager->GetNumDecls( DECL_SOUND );
		for ( int i = 0; i < num; i++ ) {
			const idDecl *decl = declManager->DeclByIndex( DECL_SOUND, i, false );
			if ( !decl ) {
				continue;
			}
			idStr name = decl->GetName();
			name.Replace( "_", " " );
			if ( name.Find( "betruger", false ) < 0 || name.Find( "laugh", false ) < 0 ) {
				continue;
			}
			if ( name.Find( "laugh 01", false ) >= 0 ) {
				if ( first.Length() == 0 ) {
					first = decl->GetName();
				}
				continue;
			}
			found = decl->GetName();
			break;
		}
		if ( found.Length() == 0 ) {
			found = first;
		}
	}
	idSoundWorld *world = soundSystem->GetPlayingSoundWorld();
	if ( world && found.Length() > 0 ) {
		world->PlayShaderDirectly( found );
	}
}

void IOS_GoToLevel( const char *path ) {
	IOS_Command( va( "map %s", path ) );
}

/*
================
IOS_Shoot

The photo: the game's view as it is drawn now, without the HUD (and its
crosshair), as a PNG for the touch controls to put in Photos
================
*/
extern int g_screenshotFormat;	// (renderer/RenderSystem_init.cpp)

static void IOS_Shoot( void ) {
	if ( !IOS_InGame() ) {
		IOSTouch_PhotoTaken( NULL );
		return;
	}
	bool showHud = cvarSystem->GetCVarBool( "g_showHud" );
	cvarSystem->SetCVarBool( "g_showHud", false );
	g_screenshotFormat = 2;	// PNG
	renderSystem->TakeScreenshot( renderSystem->GetScreenWidth(), renderSystem->GetScreenHeight(), PHOTO_FILE, 1, NULL );
	cvarSystem->SetCVarBool( "g_showHud", showHud );
	idStr path = fileSystem->RelativePathToOSPath( PHOTO_FILE, "fs_savepath" );
	IOSTouch_PhotoTaken( path.c_str() );
}

// the selfie's camera: in front of the player, looking back at them
static const char * const selfieCVars[] = { "pm_thirdPerson", "pm_thirdPersonAngle", "pm_thirdPersonRange", "pm_thirdPersonHeight" };
static const char * const selfieValues[] = { "1", "180", "70", "4" };
static idStr selfieSaved[4];

static void IOS_DoPhoto( void ) {
	switch ( photoState ) {
	case PHOTO_ASKED:
		IOS_Shoot();
		photoState = PHOTO_NONE;
		break;
	case SELFIE_ASKED:
		if ( !IOS_InGame() ) {
			IOSTouch_PhotoTaken( NULL );
			photoState = PHOTO_NONE;
			break;
		}
		for ( int i = 0; i < 4; i++ ) {
			selfieSaved[i] = cvarSystem->GetCVarString( selfieCVars[i] );
			cvarSystem->SetCVarString( selfieCVars[i], selfieValues[i] );
		}
		photoTime = Sys_Milliseconds();
		photoState = SELFIE_TURNING;
		break;
	case SELFIE_TURNING:
		if ( Sys_Milliseconds() - photoTime < SELFIE_TURN_MSEC ) {
			break;
		}
		IOS_Shoot();
		for ( int i = 0; i < 4; i++ ) {
			cvarSystem->SetCVarString( selfieCVars[i], selfieSaved[i] );
		}
		photoState = PHOTO_NONE;
		break;
	}
}

void IOS_Dismiss( void ) {
	dismissAsked = true;
}

int IOS_TakeDismiss( void ) {
	int asked = dismissAsked;
	dismissAsked = false;
	return asked;
}

/*
================
IOS_RouteGuiTouch

A finger on the PDA: its cursor goes where the finger is, in its 640 x 480
(the PDA is drawn 4:3 in the middle of the screen, r_scaleMenusTo43, as the
menus are), and dragged, the text or list under it scrolls with it, about a
line for each line's height dragged. (The click is the touch controls'
attack, on a tap: IOSTouch_TakeInput.)
================
*/
static const float IOS_GUI_LINE = 16.0f;	// a PDA line's height, about (640 x 480)

void IOS_RouteGuiTouch( void *gui ) {
	idUserInterface *ui = (idUserInterface *)gui;
	float px, py, w, h;
	float dy = IOSTouch_TakeGuiScroll();
	if ( !IOSTouch_GuiTouch( &px, &py, &w, &h ) || w <= 0.0f || h <= 0.0f ) {
		return;
	}
	float w43 = w, h43 = h;
	if ( w * 3.0f > h * 4.0f ) {
		w43 = h * 4.0f / 3.0f;
	} else {
		h43 = w * 3.0f / 4.0f;
	}
	float x = idMath::ClampFloat( 0.0f, (float)SCREEN_WIDTH, ( px - ( w - w43 ) * 0.5f ) * SCREEN_WIDTH / w43 );
	float y = idMath::ClampFloat( 0.0f, (float)SCREEN_HEIGHT, ( py - ( h - h43 ) * 0.5f ) * SCREEN_HEIGHT / h43 );
	ui->SetCursor( x, y );
	if ( dy != 0.0f ) {
		// the finger up shows what's further down
		IOS_ScrollGuiAt( ui, x, y, -dy * SCREEN_HEIGHT / h43 / IOS_GUI_LINE );
	}
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

void IOS_Skip( void ) {
	skipAsked = true;
}

static void QueueConsoleEvent( sysEventType_t type, int value, int value2 ) {
	sysEvent_t ev;
	memset( &ev, 0, sizeof( ev ) );
	ev.evType = type;
	ev.evValue = value;
	ev.evValue2 = value2;
	consoleEvents.Append( ev );
}

void IOS_ConsoleText( const char *text ) {
	// the console takes single-byte characters; anything else (emoji,
	// accents) is left out
	for ( const unsigned char *c = (const unsigned char *)text; *c; c++ ) {
		if ( *c == '\n' || *c == '\r' ) {
			IOS_ConsoleKey( IOSTOUCH_KEY_ENTER );
		} else if ( *c >= ' ' && *c < 0x7f && *c != '`' && *c != '~' ) {
			QueueConsoleEvent( SE_CHAR, *c, 0 );
		}
	}
}

void IOS_ConsoleKey( int key ) {
	int k = ( key == IOSTOUCH_KEY_ENTER ) ? K_ENTER : K_BACKSPACE;
	QueueConsoleEvent( SE_KEY, k, 1 );
	if ( k == K_BACKSPACE ) {
		// the edit line deletes on the character, as SDL's keys send it
		QueueConsoleEvent( SE_CHAR, K_BACKSPACE, 0 );
	}
	QueueConsoleEvent( SE_KEY, k, 0 );
}

void IOS_CloseConsole( void ) {
	closeConsoleAsked = true;
}

/*
================
IOS_DoAsked

What the overlay asked for during the frame.
================
*/
static void IOS_DoAsked( void ) {
	if ( closeConsoleAsked ) {
		closeConsoleAsked = false;
		consoleEvents.Clear();
		if ( console->Active() ) {
			console->Close();
		}
	}
	for ( int i = 0; i < consoleEvents.Num(); i++ ) {
		if ( console->Active() ) {
			console->ProcessEvent( &consoleEvents[i], false );
		}
	}
	consoleEvents.Clear();

	if ( resumeAsked ) {
		resumeAsked = false;
		if ( IOS_MenuOverGame() ) {
			sessLocal.ExitMenu();
		}
	}

	if ( skipAsked ) {
		skipAsked = false;
		if ( sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiIntro ) {
			// the story intro before Mars City: as when it ends by itself
			sessLocal.HandleIntroMenuCommands( "startGame" );
		} else if ( sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiMainMenu ) {
			// the intro videos: the main menu as without them (StartMenu's
			// "noIntro"), and Escape, as on PC
			introOver = true;
			sessLocal.guiMainMenu->HandleNamedEvent( "noIntro" );
			IOS_PressKey( SDL_SCANCODE_ESCAPE );
		} else if ( sessLocal.guiActive == NULL ) {
			// a cinematic: Escape skips it, as on PC
			IOS_PressKey( SDL_SCANCODE_ESCAPE );
		}
	}
}

bool IOS_IntroOver( void ) {
	return introOver;
}

/*
================
IOS_TouchFrame

Once a frame: shows the touch controls in play, a tap to skip over
cinematics and the story intro, the PDA's own close button and touches over
the PDA, the console's own buttons over the console, and nothing in the
menus, where a finger is the mouse.
================
*/
void IOS_TouchFrame( void ) {
	// games Bonjour has just found on the Wi-Fi, for the list being made
	char found[8][32];
	int numFound = IOSNet_Servers( found, 8, 1 );
	for ( int i = 0; i < numFound; i++ ) {
		idAsyncNetwork::client.IOS_QueryLANServer( found[i] );
	}

	IOS_DoAsked();
	IOS_MenuFrame();
	IOS_DoPhoto();
	IOS_DoCinema();

	bool gameFresh = Sys_Milliseconds() - gameReport.time < GAME_REPORT_MSEC;
	int mode = IOSTOUCH_MODE_HIDDEN;
	if ( console->Active() ) {
		mode = IOSTOUCH_MODE_CONSOLE;
	} else if ( sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiIntro ) {
		mode = IOSTOUCH_MODE_SKIP;
	} else if ( sessLocal.guiActive != NULL && sessLocal.guiActive == sessLocal.guiMainMenu && !introOver ) {
		// the intro videos as the game starts: a tap skips them
		if ( introStart < 0 ) {
			introStart = Sys_Milliseconds();
			introOver = !IOS_PlayIntro();	// (none, as the app's setting has it)
		}
		if ( Sys_Milliseconds() - introStart < INTRO_MSEC ) {
			mode = IOSTOUCH_MODE_SKIP;
		} else {
			introOver = true;
			mode = IOSTOUCH_MODE_MENU;
		}
	} else if ( sessLocal.guiActive != NULL ) {
		mode = IOSTOUCH_MODE_MENU;
	} else if ( sessLocal.mapSpawned && sessLocal.guiActive == NULL ) {
		if ( gameFresh && gameReport.inCinematic ) {
			mode = IOSTOUCH_MODE_SKIP;
		} else if ( gameFresh && gameReport.pdaOpen ) {
			mode = IOSTOUCH_MODE_PDA;
		} else {
			mode = IOSTOUCH_MODE_GAMEPLAY;
		}
	}
	if ( mode != IOSTOUCH_MODE_GAMEPLAY ) {
		// (the wheel closes with the controls, and Action Freeze ends)
		gameHeld = false;
		IOS_EndFreeze();
	}
	IOSTouch_Frame( mode );
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

	if ( frozen ) {
		// Action Freeze: the touches fly the free camera, the player stays
		if ( cinemaShot < 0 ) {
			freezeAngles.yaw += in.yaw;
			freezeAngles.pitch = idMath::ClampFloat( -89.0f, 89.0f, freezeAngles.pitch + in.pitch );
			idVec3 forward, right;
			freezeAngles.ToVectors( &forward, &right, NULL );
			freezeOrg += forward * ( in.forward / 127.0f * IOS_FREEZE_SPEED );
			freezeOrg += right * ( in.right / 127.0f * IOS_FREEZE_SPEED );
			freezeOrg.z += in.up / 127.0f * IOS_FREEZE_SPEED;
		}
		numImpulses = 0;
		return;
	}

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
	if ( in.buttons & IOSTOUCH_CMD_SCORES ) {
		cmd.buttons |= BUTTON_SCORES;
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
