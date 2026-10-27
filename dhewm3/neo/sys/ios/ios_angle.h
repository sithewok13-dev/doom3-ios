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
 * iOS renders through ANGLE's Metal backend instead of Apple's deprecated
 * OpenGL ES. SDL3's UIKit backend only knows Apple's OpenGL ES (EAGL), with
 * no EGL, so SDL is built without OpenGL support and the context comes from
 * here: an EGL surface on SDL's Metal view. SDL still owns the window,
 * events, audio and controllers.
 *
 * Included by sys/glimp.cpp after the SDL headers: the SDL_GL_* calls there
 * become these, so dhewm3's own window code stays as it is. Adapted from the
 * Jedi Knight port's iosAngle.c.
 */

#ifndef __IOS_ANGLE_H__
#define __IOS_ANGLE_H__

#include <SDL3/SDL.h>

SDL_GLContext		IOS_GL_CreateContext( SDL_Window *window );
bool				IOS_GL_DestroyContext( SDL_GLContext context );
bool				IOS_GL_SwapWindow( SDL_Window *window );
SDL_FunctionPointer	IOS_GL_GetProcAddress( const char *proc );
bool				IOS_GL_SetSwapInterval( int interval );
bool				IOS_GL_SetAttribute( SDL_GLAttr attr, int value );	// the config is fixed: ignored
bool				IOS_GL_GetAttribute( SDL_GLAttr attr, int *value );	// what the context really has

// the window is drawn by Metal (ANGLE), not by SDL's OpenGL ES
#undef SDL_WINDOW_OPENGL
#define SDL_WINDOW_OPENGL			SDL_WINDOW_METAL

#define SDL_GL_CreateContext		IOS_GL_CreateContext
#define SDL_GL_DestroyContext		IOS_GL_DestroyContext
#define SDL_GL_SwapWindow			IOS_GL_SwapWindow
#define SDL_GL_GetProcAddress		IOS_GL_GetProcAddress
#define SDL_GL_SetSwapInterval		IOS_GL_SetSwapInterval
#define SDL_GL_SetAttribute			IOS_GL_SetAttribute
#define SDL_GL_GetAttribute			IOS_GL_GetAttribute

#endif /* !__IOS_ANGLE_H__ */
