#ifndef RUNNER_SPLASH_WINDOW_H_
#define RUNNER_SPLASH_WINDOW_H_

#include <windows.h>

// Displays a lightweight native Win32 splash card immediately upon launch.
void ShowNativeSplash(HINSTANCE instance);

// Closes and releases resources of the native splash card once Flutter renders its first frame.
void CloseNativeSplash();

#endif  // RUNNER_SPLASH_WINDOW_H_
