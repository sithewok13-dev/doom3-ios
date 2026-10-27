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
 * OpenGL ES 2.0 builds (GLES2) leave out tr_rendertools.cpp (the r_show*
 * debug drawing) and the dmap and renderbump compilers: they draw with
 * desktop OpenGL's fixed-function calls, which OpenGL ES doesn't have.
 * These are their entry points, doing nothing.
 */

#include "sys/platform.h"
#include "framework/Common.h"
#include "renderer/tr_local.h"

void RB_DrawBounds( const idBounds &bounds ) {}
void RB_SimpleSurfaceSetup( const drawSurf_t *drawSurf ) {}
void RB_SimpleWorldSetup( void ) {}
void RB_PolygonClear( void ) {}
void RB_ShowDestinationAlpha( void ) {}
void RB_ScanStencilBuffer( void ) {}
void RB_CountStencilBuffer( void ) {}
void RB_ShowOverdraw( void ) {}
void RB_ShowIntensity( void ) {}
void RB_ShowDepthBuffer( void ) {}
void RB_ShowLightCount( void ) {}
void RB_ShowSilhouette( void ) {}
void RB_ShowLights( void ) {}
void RB_ShowPortals( void ) {}
void RB_ClearDebugText( int time ) {}
void RB_AddDebugText( const char *text, const idVec3 &origin, float scale, const idVec4 &color, const idMat3 &viewAxis, const int align, const int lifetime, const bool depthTest ) {}
float RB_DrawTextLength( const char *text, float scale, int len ) { return 0.0f; }
void RB_ShowDebugText( void ) {}
void RB_ClearDebugLines( int time ) {}
void RB_AddDebugLine( const idVec4 &color, const idVec3 &start, const idVec3 &end, const int lifeTime, const bool depthTest ) {}
void RB_ShowDebugLines( void ) {}
void RB_ClearDebugPolygons( int time ) {}
void RB_AddDebugPolygon( const idVec4 &color, const idWinding &winding, const int lifeTime, const bool depthTest ) {}
void RB_ShowDebugPolygons( void ) {}
void RB_TestGamma( void ) {}
void RB_TestImage( void ) {}
void RB_RenderDebugTools( drawSurf_t **drawSurfs, int numDrawSurfs ) {}
void RB_ShutdownDebugTools( void ) {}
void RB_ShowImages( void ) {}

static void NotInThisBuild( const char *what ) {
	common->Printf( "%s isn't available in the OpenGL ES build\n", what );
}

void Dmap_f( const idCmdArgs &args ) { NotInThisBuild( "dmap" ); }
void RenderBump_f( const idCmdArgs &args ) { NotInThisBuild( "renderbump" ); }
void RenderBumpFlat_f( const idCmdArgs &args ) { NotInThisBuild( "renderbumpflat" ); }
