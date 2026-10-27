# The DOOM 3 app around the engine: bundle id, Info.plist, the first-launch
# screen and the icons. Included at the end of dhewm3/neo/CMakeLists.txt on
# iOS, with IOS_APP_DIR pointing here.

set(IOS_BUNDLE_ID "com.sithewok.doom3" CACHE STRING "The app's bundle id")
set(IOS_VERSION "1.0" CACHE STRING "CFBundleShortVersionString")
set(IOS_BUILD_NUMBER "1" CACHE STRING "CFBundleVersion (CI passes its run number)")
set(IOS_EXECUTABLE "DOOM3")

target_sources(${DHEWM3BINARY} PRIVATE "${IOS_APP_DIR}/IOSGameData.m")
set_source_files_properties("${IOS_APP_DIR}/IOSGameData.m" PROPERTIES COMPILE_FLAGS "-fobjc-arc")

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
	"-framework Metal" "-framework OpenGLES" "-framework QuartzCore"
	"-framework UIKit" "-framework UniformTypeIdentifiers"
)

# Icons and the launch screen colour: compile the asset catalog into the
# bundle, as Xcode would, and add the icon keys actool reports to Info.plist.
set(IOS_BUNDLE_DIR "$<TARGET_BUNDLE_DIR:${DHEWM3BINARY}>")
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
