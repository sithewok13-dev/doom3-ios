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
 * Multiplayer on the same Wi-Fi (ios/IOSNetwork.m): the games served from
 * here advertised with Bonjour, and the ones on the network found with it,
 * as iOS doesn't let an app broadcast to find them as DOOM 3 does.
 */

#ifndef __IOS_NET_H__
#define __IOS_NET_H__

#ifdef __cplusplus
extern "C" {
#endif

void	IOSNet_Advertise( int port, const char *name );	// the server's port (0: none any more)
void	IOSNet_Browse( void );								// start looking for games (asks for Local Network the first time)
int		IOSNet_Servers( char addresses[][32], int max, int onlyNew );	// "a.b.c.d:port" of the games found (onlyNew: since last asked)

#ifdef __cplusplus
}
#endif

#endif /* !__IOS_NET_H__ */
