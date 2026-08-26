cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "tun_process_bridge.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
if(DEFINED FLUTTER_BUILD_NAME AND NOT "${FLUTTER_BUILD_NAME}" STREQUAL "")
  target_compile_definitions(${BINARY_NAME} PRIVATE "APP_VERSION_STRING=\"${FLUTTER_BUILD_NAME}\"")
elseif(DEFINED FLUTTER_VERSION AND NOT "${FLUTTER_VERSION}" STREQUAL "")
  target_compile_definitions(${BINARY_NAME} PRIVATE "APP_VERSION_STRING=\"${FLUTTER_VERSION}\"")
else()
  target_compile_definitions(${BINARY_NAME} PRIVATE "APP_VERSION_STRING=\"1.2.18\"")
endif()

target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# High-performance compiler and linker optimizations for Release and Profile builds
if(MSVC)
  target_compile_options(${BINARY_NAME} PRIVATE
    "$<$<CONFIG:Release>:/O2;/Oi;/Ot;/GL;/Gw>"
    "$<$<CONFIG:Profile>:/O2;/Oi;/Ot;/GL;/Gw>"
  )
  set_target_properties(${BINARY_NAME} PROPERTIES
    LINK_FLAGS_RELEASE "/LTCG /OPT:REF /OPT:ICF"
    LINK_FLAGS_PROFILE "/LTCG /OPT:REF /OPT:ICF"
  )
endif()

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
