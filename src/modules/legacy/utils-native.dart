// Deprecated mechanism
// Won't compile when using native OS APIs, eg. .dll, .so
// 'cause Dart can't compile imports which use native binaries of 
// different OSes at the same time.
// ***********************************
// Instead, use: run.ps1 PLATFORM-NAME
// ***********************************
/*
// Libs
import 'dart:io';

// Imports
#IFDEF ANDROID 
import "utils_android.dart" as android;
#ENDIF

#IFDEF IOS 
import "utils_ios.dart" as ios;
#ENDIF 

#IFDEF WINDOWS 
import "utils_windows.dart" as windows;
#ENDIF 

#IFDEF MACOS 
import "utils_macos.dart" as macos;
#ENDIF 

#IFDEF LINUX 
import "utils_linux.dart" as linux;
#ENDIF

var ____FUNCS____;

final platformIsWeb = (){
    if (Platform.isAndroid) return android.platformIsWeb;
    if (Platform.isIOS) return ios.platformIsWeb;
    if (Platform.isWindows) return windows.platformIsWeb;
    if (Platform.isMacOS) return macos.platformIsWeb;
    if (Platform.isLinux) return linux.platformIsWeb;
}();

var ____CLASS____;

final Utils_ = (){
    if (Platform.isAndroid) return android.Utils_;
    if (Platform.isIOS) return ios.Utils_;
    if (Platform.isWindows) return windows.Utils_;
    if (Platform.isMacOS) return macos.Utils_;
    if (Platform.isLinux) return linux.Utils_;
}();
*/