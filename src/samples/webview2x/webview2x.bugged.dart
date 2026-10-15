import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- FFI Bindings Definitions for webview.dll ---
typedef webview_create_native = ffi.Pointer<ffi.Void> Function(ffi.Int32 debug, ffi.Pointer<ffi.Void> window);
typedef WebviewCreate = ffi.Pointer<ffi.Void> Function(int debug, ffi.Pointer<ffi.Void> window);

typedef webview_navigate_native = ffi.Void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<Utf8> url);
typedef WebviewNavigate = void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<Utf8> url);

typedef webview_run_native = ffi.Void Function(ffi.Pointer<ffi.Void> w);
typedef WebviewRun = void Function(ffi.Pointer<ffi.Void> w);

typedef webview_destroy_native = ffi.Void Function(ffi.Pointer<ffi.Void> w);
typedef WebviewDestroy = void Function(ffi.Pointer<ffi.Void> w);

// The C Callback signature used by webview_dispatch: void fn(webview_t w, void *arg)
typedef webview_dispatch_fn_native = ffi.Void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<ffi.Void> arg);

// webview_dispatch C function signature
typedef webview_dispatch_native = ffi.Void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>> fn, ffi.Pointer<ffi.Void> arg);
typedef WebviewDispatch = void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>> fn, ffi.Pointer<ffi.Void> arg);

// This function MUST be a static or top-level function to be converted into a native C pointer
void onNativeDispatch(ffi.Pointer<ffi.Void> webviewInstance, ffi.Pointer<ffi.Void> urlArgPointer) {
    // if (urlArgPointer == ffi.nullptr || webviewInstance == ffi.nullptr) return;

    // 1. Cast the raw generic pointer back into a UTF-8 C-String pointer
    final ffi.Pointer<Utf8> urlStringPointer = urlArgPointer.cast<Utf8>();

    // 2. Perform the safe navigation action inside the main GUI execution loop thread context
    // We use standard DynamicLibrary lookup locally inside the dispatch step to find the function
    final dylib = ffi.DynamicLibrary.open('webview.dll');
    final WebviewNavigate webviewNavigate = dylib.lookupFunction<webview_navigate_native, WebviewNavigate>('webview_navigate');

    webviewNavigate(webviewInstance, urlStringPointer);

    // 3. Free the string memory allocated on the heap during the dispatch call setup
    calloc.free(urlStringPointer);
}

void main() async {
    final String dllPath = 'webview.dll';
    if (!File(dllPath).existsSync()) {
        print('Error: webview.dll not found in the current directory!');
        return;
    }

    final dylib = ffi.DynamicLibrary.open(dllPath);

    final WebviewCreate webviewCreate = dylib.lookupFunction<webview_create_native, WebviewCreate>('webview_create');
    final WebviewRun webviewRun = dylib.lookupFunction<webview_run_native, WebviewRun>('webview_run');
    final WebviewDestroy webviewDestroy = dylib.lookupFunction<webview_destroy_native, WebviewDestroy>('webview_destroy');
    final WebviewDispatch webviewDispatch = dylib.lookupFunction<webview_dispatch_native, WebviewDispatch>('webview_dispatch');

    print('Initializing native Webview context...');
    final ffi.Pointer<ffi.Void> webviewInstance = webviewCreate(0, ffi.nullptr);

    // Load the initial home layout page safely
    final dylibNav = dylib.lookupFunction<webview_navigate_native, WebviewNavigate>('webview_navigate');
    final initialUrlPtr = 'https://www.google.com'.toNativeUtf8();
    dylibNav(webviewInstance, initialUrlPtr);
    calloc.free(initialUrlPtr);

    // Convert our top-level Dart function into an active C function pointer structure
    final ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>> dispatchCallbackPointer = 
        ffi.Pointer.fromFunction<webview_dispatch_fn_native>(onNativeDispatch);

    // Start an asynchronous listener loop reading terminal user actions manually
    // Using stdin.listen keeps the stream non-blocking so the underlying native thread can flow
    stdin.listen((List<int> codes) {
        final String line = String.fromCharCodes(codes).trim();
        if (line.isEmpty) return;

        String targetUrl = line;
        if (!targetUrl.startsWith('http://') && 
            !targetUrl.startsWith('https://') && 
            !targetUrl.startsWith('file://')) {
            targetUrl = 'https://\$targetUrl';
        }

        print('Dispatching navigation pipeline event for: \$targetUrl');

        // Allocate a UTF-8 representation of our string directly onto the native heap.
        // This MUST NOT be freed here because the async GUI loop will read it later inside `onNativeDispatch`.
        final ffi.Pointer<Utf8> urlNativeStringHeap = targetUrl.toNativeUtf8();

        // Push the function pointer and data memory address safely into the UI loop queue stack
        webviewDispatch(
            webviewInstance, 
            dispatchCallbackPointer, 
            urlNativeStringHeap.cast<ffi.Void>()
        );
    });

    print('\n======================================================');
    print('Webview Running via Webview_Dispatch Queue!');
    print('Type a URL here and press Enter:');
    print('Example: pub.dev or github.com');
    print('======================================================\n');

    // Blocks the main process loop frame natively, but `stdin.listen` continues routing inputs asynchronously
    webviewRun(webviewInstance);

    webviewDestroy(webviewInstance);
    exit(0);
}
