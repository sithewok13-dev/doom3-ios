# The DOOM 3 app around the engine: bundle id, Info.plist, the first-launch
# screen and the icons. Included at the end of dhewm3/neo/CMakeLists.txt on
# iOS, with IOS_APP_DIR pointing here.

set(IOS_BUNDLE_ID "com.sithewok.doom3" CACHE STRING "The app's bundle id")
set(IOS_VERSION "1.0" CACHE STRING "CFBundleShortVersionString")
set(IOS_BUILD_NUMBER "1" CACHE STRING "CFBundleVersion (CI passes its run number)")
set(IOS_EXECUTABLE "DOOM3")

# the first-launch screen, the touch controls and finding games on the
# Wi-Fi (Objective-C, ARC)
set(IOS_APP_SOURCES
	"${IOS_APP_DIR}/IOSGameData.m"
	"${IOS_APP_DIR}/IOSTouch.m"
	"${IOS_APP_DIR}/IOSNetwork.m"
)
target_sources(${DHEWM3BINARY} PRIVATE ${IOS_APP_SOURCES})
set_source_files_properties(${IOS_APP_SOURCES} PROPERTIES COMPILE_FLAGS "-fobjc-arc")

configure_file("${IOS_APP_DIR}/Info.plist.in" "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" @ONLY)
set_target_properties(${DHEWM3BINARY} PROPERTIES
	OUTPUT_NAME "${IOS_EXECUTABLE}"
	MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
)

# What static SDL3 builds on, in case its package doesn't pass them all on.
target_link_libraries(${DHEWM3BINARY}
	"-framework AVFoundation" "-framework AudioToolbox" "-framework CoreAudio"
	"-framework CoreBluetooth" "-framework CoreGraphics" "-framework CoreHaptics"
	"-framework CoreMotion" "-framework Foundation" "-framework GameController"
	"-framework Metal" "-framework QuartzCore"
	"-framework UIKit" "-framework UniformTypeIdentifiers"
)

# ANGLE (OpenGL ES on Metal): its two frameworks, linked by @rpath and copied
# into the app's Frameworks folder
set(ANGLE_FRAMEWORK_DIR "${ANGLE_ROOT}/out/ios")
target_link_libraries(${DHEWM3BINARY}
	"-F${ANGLE_FRAMEWORK_DIR}" "-framework libEGL" "-framework libGLESv2"
	"-Wl,-rpath,@executable_path/Frameworks"
)

set(IOS_BUNDLE_DIR "$<TARGET_BUNDLE_DIR:${DHEWM3BINARY}>")
add_custom_command(TARGET ${DHEWM3BINARY} POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E make_directory "${IOS_BUNDLE_DIR}/Frameworks"
	COMMAND ${CMAKE_COMMAND} -E copy_directory "${ANGLE_FRAMEWORK_DIR}/libEGL.framework" "${IOS_BUNDLE_DIR}/Frameworks/libEGL.framework"
	COMMAND ${CMAKE_COMMAND} -E copy_directory "${ANGLE_FRAMEWORK_DIR}/libGLESv2.framework" "${IOS_BUNDLE_DIR}/Frameworks/libGLESv2.framework"
	COMMENT "Bundling ANGLE"
	VERBATIM)

# LibreCoop's mod folders (its defs, scripts and strings; no game data): in
# the app as Mods/<folder>/pak000.zip (a .pk4 as LibreCoop's autopak.py
# makes it) and description.txt, for IOS_InstallMods to put in Documents.
# (A .zip, so the package step's check that no game data is in the app
# stays simple: no .pk4 at all.)
if(LIBRECOOP_DIR AND EXISTS "${LIBRECOOP_DIR}/librecoop")
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/librecoop/description.txt" "LibreCoop: co-op and survival for DOOM 3")
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/librecoopd3xp/description.txt" "LibreCoop: co-op and survival for Resurrection of Evil")
	foreach(mod librecoop librecoopd3xp)
		if(mod STREQUAL "librecoop")
			set(modsrc "${LIBRECOOP_DIR}/librecoop")
		else()
			set(modsrc "${LIBRECOOP_DIR}/librecoopxp")
		endif()
		add_custom_command(TARGET ${DHEWM3BINARY} POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E make_directory "${IOS_BUNDLE_DIR}/Mods/${mod}"
			COMMAND ${CMAKE_COMMAND} -E chdir "${modsrc}"
				${CMAKE_COMMAND} -E tar cf "${IOS_BUNDLE_DIR}/Mods/${mod}/pak000.zip" --format=zip def script strings
			COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/${mod}/description.txt" "${IOS_BUNDLE_DIR}/Mods/${mod}/description.txt"
			COMMENT "Bundling LibreCoop's ${mod} mod folder"
			VERBATIM)
	endforeach()
endif()

# Icons and the launch screen colour: compile the asset catalog into the
# bundle, as Xcode would, and add the icon keys actool reports to Info.plist.
add_custom_command(TARGET ${DHEWM3BINARY} POST_BUILD
	COMMAND xcrun actool "${IOS_APP_DIR}/Assets.xcassets"
		--compile "${IOS_BUNDLE_DIR}"
		--platform iphoneos
		--minimum-deployment-target ${CMAKE_OSX_DEPLOYMENT_TARGET}
		--target-device iphone --target-device ipad
		--app-icon AppIcon
		--output-partial-info-plist "${CMAKE_CURRENT_BINARY_DIR}/assets-Info.plist"
		--output-format human-readable-text --notices --warnings
	COMMAND /usr/libexec/PlistBuddy -c "Merge ${CMAKE_CURRENT_BINARY_DIR}/assets-Info.plist" "${IOS_BUNDLE_DIR}/Info.plist"
	COMMENT "Compiling the asset catalog (icons) into the app"
	VERBATIM)
