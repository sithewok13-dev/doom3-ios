<img align="left" width="100" height="100" src="icon_doom3.png">

# DOOM 3 for iPhone and iPad

&nbsp;

The original 2004 DOOM 3 and its expansion, Resurrection of Evil, in one app, on
[dhewm3](https://dhewm3.org) 1.5.5. Work in progress, on the `ios` branch.

**You bring the game.** No game files are included. You need your own copy of the
original DOOM 3 (Steam, GOG or disc, patched to 1.3.1). The BFG Edition's files
don't work. On first launch the app says what to copy:

- DOOM 3's `base` folder contents into Files > On My iPhone > DOOM 3 > `base`
  (the nine files `pak000.pk4` to `pak008.pk4`)
- for Resurrection of Evil, also its `d3xp` folder contents into `d3xp`
  (`pak000.pk4`, `pak001.pk4`), then pick it under **Mods** in the main menu

## Building

GitHub Actions builds it on every push to `ios` (`.github/workflows/ios.yml`) and
keeps an unsigned `DOOM3-iOS-unsigned.ipa` with each run, for sideloading or for
TestFlight through ios-pipeline. To build on a Mac with Xcode, CMake and Ninja:

```sh
ios/build-deps.sh                      # SDL3 and OpenAL Soft for iOS, into build-ios-deps/
cmake -S dhewm3/neo -B build-ios -G Ninja --toolchain ios/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=$PWD/build-ios-deps -DCMAKE_FIND_ROOT_PATH=$PWD/build-ios-deps
cmake --build build-ios                # build-ios/DOOM3.app
```

## What's where

- `dhewm3/`: dhewm3 1.5.5 (imported unmodified, then changed in later commits)
  with the OpenGL ES renderer and the iOS system code (`neo/sys/ios/`)
- `ios/`: the app around it: Info.plist, icons, the first-launch screen, the
  dependency build
- `docs/ios/PLAN.md`: the plan and the decisions made so far

## Credits

- [dhewm3](https://github.com/dhewm/dhewm3) by Daniel Gibson and contributors,
  from id Software's DOOM 3 GPL source
- The OpenGL ES renderer from Tom Kidd's [DOOM3-iOS](https://github.com/tomkidd/DOOM3-iOS),
  which this repository was forked from, and Gabriel Cuvillier's
  [d3wasm](https://github.com/gabrielcuvillier/d3wasm)
- [SDL](https://www.libsdl.org) and [OpenAL Soft](https://openal-soft.org)

The code is GPLv3, like the DOOM 3 source.
