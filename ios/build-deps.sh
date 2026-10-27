#!/bin/bash
# Builds the static libraries the iOS app links, SDL3 and OpenAL Soft, and
# installs them into one prefix (default: build-ios-deps/ in the repo).
# CI caches that prefix, keyed on this file.
#
#   ios/build-deps.sh [prefix]
set -euo pipefail

SDL_TAG=release-3.4.12
OPENAL_TAG=1.24.3

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=${1:-$ROOT/build-ios-deps}
SRC=$PREFIX/src
TOOLCHAIN=$ROOT/ios/toolchain.cmake
mkdir -p "$SRC"

fetch() { # repo tag dir
	[ -d "$SRC/$3" ] || git clone --quiet --depth 1 --branch "$2" "$1" "$SRC/$3"
}

build() { # dir, then extra cmake args
	local dir=$1; shift
	cmake -S "$SRC/$dir" -B "$SRC/$dir/build-ios" -G Ninja \
		--toolchain "$TOOLCHAIN" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_INSTALL_LIBDIR=lib \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		"$@"
	cmake --build "$SRC/$dir/build-ios"
	cmake --install "$SRC/$dir/build-ios"
}

fetch https://github.com/libsdl-org/SDL "$SDL_TAG" SDL
# no OpenGL in SDL: ANGLE draws on SDL's Metal view (sys/ios/ios_angle.h)
build SDL \
	-DSDL_SHARED=OFF -DSDL_STATIC=ON \
	-DSDL_OPENGLES=OFF -DSDL_OPENGL=OFF \
	-DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF

# CoreAudio is the only real output on iOS: without it OpenAL Soft would
# still build, with the null backend, and every sound would be silent.
fetch https://github.com/kcat/openal-soft "$OPENAL_TAG" openal-soft
build openal-soft \
	-DLIBTYPE=STATIC \
	-DALSOFT_REQUIRE_COREAUDIO=ON \
	-DALSOFT_UTILS=OFF -DALSOFT_NO_CONFIG_UTIL=ON -DALSOFT_EXAMPLES=OFF \
	-DALSOFT_INSTALL_CONFIG=OFF -DALSOFT_INSTALL_HRTF_DATA=OFF \
	-DALSOFT_INSTALL_AMBDEC_PRESETS=OFF -DALSOFT_INSTALL_EXAMPLES=OFF \
	-DALSOFT_INSTALL_UTILS=OFF

echo "Dependencies installed in $PREFIX"
