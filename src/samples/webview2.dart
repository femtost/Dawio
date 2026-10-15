// Libs
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// --- C Function Signatures (Native) ---
typedef WebViewCreateC = Pointer<Void> Function(Int32 debug, Pointer<Void> window);
typedef WebViewNavigateC = Void Function(Pointer<Void> w, Pointer<Char> url);
typedef WebViewRunC = Void Function(Pointer<Void> w);
typedef WebViewEvalC = Void Function(Pointer<Void> w, Pointer<Char> js);
typedef WebViewDestroyC = Void Function(Pointer<Void> w);

// --- Dart Function Signatures (Managed) ---
typedef WebViewCreateDart = Pointer<Void> Function(int debug, Pointer<Void> window);
typedef WebViewNavigateDart = void Function(Pointer<Void> w, Pointer<Char> url);
typedef WebViewRunDart = void Function(Pointer<Void> w);
typedef WebViewEvalDart = void Function(Pointer<Void> w, Pointer<Char> js);
typedef WebViewDestroyDart = void Function(Pointer<Void> w);

void main() {
    // 1. Open the compiled webview.dll file
    final dl = DynamicLibrary.open('webview.dll');

    // 2. Map all the required lifecycle functions from the DLL
    final WebViewCreateDart webviewCreate = dl
        .lookup<NativeFunction<WebViewCreateC>>('webview_create')
        .asFunction();

    final WebViewNavigateDart webviewNavigate = dl
        .lookup<NativeFunction<WebViewNavigateC>>('webview_navigate')
        .asFunction();

    final WebViewRunDart webviewRun = dl
        .lookup<NativeFunction<WebViewRunC>>('webview_run')
        .asFunction();

    final WebViewEvalDart webviewEval = dl
        .lookup<NativeFunction<WebViewEvalC>>('webview_eval')
        .asFunction();

    final WebViewDestroyDart webviewDestroy = dl
        .lookup<NativeFunction<WebViewDestroyC>>('webview_destroy')
        .asFunction();

    // 3. Create the top-level WebView2 window context
    // Debug mode is set to 0 (false), parent window is nullptr
    final Pointer<Void> w = webviewCreate(0, nullptr);

    if (w == nullptr) {
        print("Failed to initialize webview instance.");
        return;
    }

    // 4. Navigate to your target page
    final urlPointer = 'https://www.example.com'.toNativeUtf8();
    webviewNavigate(w, urlPointer.cast<Char>());
    calloc.free(urlPointer);

    // 5. Setup your JavaScript code to run
    // Note: Since webview_run blocks the thread, if you want to execute eval 
    // after the window opens, you should trigger it via native window hooks, 
    // bindings, or run webview_run on a separate thread/isolate if needed.
    final jsCodePointer = "document.body.style.backgroundColor = 'teal';".toNativeUtf8();
    webviewEval(w, jsCodePointer.cast<Char>());
    calloc.free(jsCodePointer);

    // 6. Start the blocking Win32 window message loop
    print("Opening WebView2 window...");
    webviewRun(w);

    // 7. Clean up memory once the user closes the window
    webviewDestroy(w);
}
// EOF