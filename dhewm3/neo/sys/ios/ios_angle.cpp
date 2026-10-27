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

// ANGLE (OpenGL ES on Metal) for iOS: see ios_angle.h

#include <SDL3/SDL.h>
#include <SDL3/SDL_metal.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>

#include "sys/platform.h"
#include "framework/Common.h"
#include "sys/ios/ios_angle.h"

static SDL_MetalView	metalView = NULL;
static EGLDisplay		display = EGL_NO_DISPLAY;
static EGLSurface		surface = EGL_NO_SURFACE;
static EGLContext		context = EGL_NO_CONTEXT;
static EGLConfig		config = NULL;

static void Fail( const char *what ) {
	common->Warning( "ANGLE: %s (EGL error 0x%04x)", what, (unsigned)eglGetError() );
	SDL_SetError( "ANGLE: %s", what );
}

// ANGLE picks a backend per display, so ask for Metal by name rather than
// relying on it being the default on Apple platforms
static EGLDisplay GetMetalDisplay( void ) {
	PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplayEXT =
		(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress( "eglGetPlatformDisplayEXT" );
	if ( getPlatformDisplayEXT ) {
		const EGLint attribs[] = {
			EGL_PLATFORM_ANGLE_TYPE_ANGLE, EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE,
			EGL_NONE
		};
		EGLDisplay metal = getPlatformDisplayEXT( EGL_PLATFORM_ANGLE_ANGLE, (void *)(uintptr_t)EGL_DEFAULT_DISPLAY, attribs );
		if ( metal != EGL_NO_DISPLAY ) {
			return metal;
		}
		common->Warning( "ANGLE: no Metal display, using the default one" );
	}
	return eglGetDisplay( EGL_DEFAULT_DISPLAY );
}

SDL_GLContext IOS_GL_CreateContext( SDL_Window *window ) {
	if ( context != EGL_NO_CONTEXT ) {
		IOS_GL_DestroyContext( (SDL_GLContext)context );
	}

	// SDL's Metal view is backed by a CAMetalLayer, sized and scaled for the
	// window; ANGLE draws straight into that layer
	metalView = SDL_Metal_CreateView( window );
	if ( !metalView ) {
		common->Warning( "ANGLE: SDL_Metal_CreateView failed: %s", SDL_GetError() );
		return NULL;
	}
	void *layer = SDL_Metal_GetLayer( metalView );
	if ( !layer ) {
		common->Warning( "ANGLE: SDL_Metal_GetLayer failed: %s", SDL_GetError() );
		IOS_GL_DestroyContext( NULL );
		return NULL;
	}

	display = GetMetalDisplay();
	EGLint major = 0, minor = 0;
	if ( display == EGL_NO_DISPLAY || !eglInitialize( display, &major, &minor ) ) {
		Fail( "eglInitialize failed" );
		IOS_GL_DestroyContext( NULL );
		return NULL;
	}
	common->Printf( "ANGLE: EGL %d.%d, %s\n", major, minor, eglQueryString( display, EGL_VENDOR ) );

	// what dhewm3 asks for on other systems: 8 bits per channel and alpha,
	// 24-bit depth, 8-bit stencil (for the shadows), no multisampling
	const EGLint configAttribs[] = {
		EGL_RENDERABLE_TYPE,	EGL_OPENGL_ES3_BIT,
		EGL_SURFACE_TYPE,		EGL_WINDOW_BIT,
		EGL_RED_SIZE,			8,
		EGL_GREEN_SIZE,			8,
		EGL_BLUE_SIZE,			8,
		EGL_ALPHA_SIZE,			8,
		EGL_DEPTH_SIZE,			24,
		EGL_STENCIL_SIZE,		8,
		EGL_NONE
	};
	EGLint numConfigs = 0;
	if ( !eglChooseConfig( display, configAttribs, &config, 1, &numConfigs ) || numConfigs < 1 ) {
		Fail( "eglChooseConfig found no config" );
		IOS_GL_DestroyContext( NULL );
		return NULL;
	}

	surface = eglCreateWindowSurface( display, config, (EGLNativeWindowType)layer, NULL );
	if ( surface == EGL_NO_SURFACE ) {
		Fail( "eglCreateWindowSurface failed" );
		IOS_GL_DestroyContext( NULL );
		return NULL;
	}

	// an OpenGL ES 3.0 context, which runs the renderer's GLSL ES 1.00 shaders
	const EGLint contextAttribs[] = {
		EGL_CONTEXT_MAJOR_VERSION, 3,
		EGL_CONTEXT_MINOR_VERSION, 0,
		EGL_NONE
	};
	context = eglCreateContext( display, config, EGL_NO_CONTEXT, contextAttribs );
	if ( context == EGL_NO_CONTEXT || !eglMakeCurrent( display, surface, surface, context ) ) {
		Fail( "eglCreateContext or eglMakeCurrent failed" );
		IOS_GL_DestroyContext( NULL );
		return NULL;
	}

	return (SDL_GLContext)context;
}

bool IOS_GL_DestroyContext( SDL_GLContext unused ) {
	if ( display != EGL_NO_DISPLAY ) {
		eglMakeCurrent( display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT );
		if ( context != EGL_NO_CONTEXT ) {
			eglDestroyContext( display, context );
		}
		if ( surface != EGL_NO_SURFACE ) {
			eglDestroySurface( display, surface );
		}
		eglTerminate( display );
	}
	context = EGL_NO_CONTEXT;
	surface = EGL_NO_SURFACE;
	display = EGL_NO_DISPLAY;
	config = NULL;

	// the view must outlive the surface drawing into its layer
	if ( metalView ) {
		SDL_Metal_DestroyView( metalView );
		metalView = NULL;
	}
	return true;
}

bool IOS_GL_SwapWindow( SDL_Window *window ) {
	if ( display == EGL_NO_DISPLAY || surface == EGL_NO_SURFACE ) {
		return false;
	}
	return eglSwapBuffers( display, surface ) == EGL_TRUE;
}

SDL_FunctionPointer IOS_GL_GetProcAddress( const char *proc ) {
	return (SDL_FunctionPointer)eglGetProcAddress( proc );
}

bool IOS_GL_SetSwapInterval( int interval ) {
	if ( display == EGL_NO_DISPLAY ) {
		return false;
	}
	// iOS always composites on vsync; 0 only means "don't wait"
	return eglSwapInterval( display, interval ? 1 : 0 ) == EGL_TRUE;
}

bool IOS_GL_SetAttribute( SDL_GLAttr attr, int value ) {
	return true;
}

bool IOS_GL_GetAttribute( SDL_GLAttr attr, int *value ) {
	EGLint eglAttr;
	switch ( attr ) {
	case SDL_GL_RED_SIZE:			eglAttr = EGL_RED_SIZE; break;
	case SDL_GL_GREEN_SIZE:			eglAttr = EGL_GREEN_SIZE; break;
	case SDL_GL_BLUE_SIZE:			eglAttr = EGL_BLUE_SIZE; break;
	case SDL_GL_ALPHA_SIZE:			eglAttr = EGL_ALPHA_SIZE; break;
	case SDL_GL_DEPTH_SIZE:			eglAttr = EGL_DEPTH_SIZE; break;
	case SDL_GL_STENCIL_SIZE:		eglAttr = EGL_STENCIL_SIZE; break;
	case SDL_GL_MULTISAMPLEBUFFERS:	eglAttr = EGL_SAMPLE_BUFFERS; break;
	case SDL_GL_MULTISAMPLESAMPLES:	eglAttr = EGL_SAMPLES; break;
	default:
		*value = 0;	// no debug context and the like
		return true;
	}
	EGLint v = 0;
	if ( display == EGL_NO_DISPLAY || config == NULL || !eglGetConfigAttrib( display, config, eglAttr, &v ) ) {
		*value = 0;
		return false;
	}
	*value = v;
	return true;
}
