import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
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

typedef webview_terminate_native = ffi.Void Function(ffi.Pointer<ffi.Void> w);
typedef WebviewTerminate = void Function(ffi.Pointer<ffi.Void> w);

// The C Callback signature used by webview_dispatch: void fn(webview_t w, void *arg)
typedef webview_dispatch_fn_native = ffi.Void Function(ffi.Pointer<ffi.Void> w, ffi.Pointer<ffi.Void> arg);

// webview_dispatch C function signature
typedef webview_dispatch_native = ffi.Void Function(
    ffi.Pointer<ffi.Void> w, 
    ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>> fn, 
    ffi.Pointer<ffi.Void> arg
);
typedef WebviewDispatch = void Function(
    ffi.Pointer<ffi.Void> w, 
    ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>> fn, 
    ffi.Pointer<ffi.Void> arg
);

// Initialization payload sent from the WebView worker isolate to the main isolate
class WebviewWorkerInit {
    final int webviewAddress;
    final int dispatchCallbackAddress;
    final int terminateCallbackAddress;
    final SendPort isolateCommandPort;

    WebviewWorkerInit({
        required this.webviewAddress,
        required this.dispatchCallbackAddress,
        required this.terminateCallbackAddress,
        required this.isolateCommandPort,
    });
}

// Configuration passed to the stdin listener
class StdinWorkerConfig {
    final int webviewAddress;
    final int callbackAddress;
    final int terminateCallbackAddress;

    StdinWorkerConfig(this.webviewAddress, this.callbackAddress, this.terminateCallbackAddress);
}

// Top-level dispatch callback for navigation executed on the worker isolate UI loop thread
void onNativeDispatch(ffi.Pointer<ffi.Void> webviewInstance, ffi.Pointer<ffi.Void> urlArgPointer) {
    if (urlArgPointer == ffi.nullptr || webviewInstance == ffi.nullptr) return;

    // 1. Cast the raw generic pointer back into a UTF-8 C-String pointer
    final ffi.Pointer<Utf8> urlStringPointer = urlArgPointer.cast<Utf8>();
    final String urlString = urlStringPointer.toDartString();

    print('[WebView UI Thread] Navigating to: $urlString');

    // 2. Perform the navigation action inside the native GUI execution loop thread context
    final dylib = ffi.DynamicLibrary.open('webview.dll');
    final WebviewNavigate webviewNavigate = dylib.lookupFunction<webview_navigate_native, WebviewNavigate>('webview_navigate');

    webviewNavigate(webviewInstance, urlStringPointer);

    // 3. Free the string memory allocated on the native heap during the dispatch setup
    calloc.free(urlStringPointer);
}

// Top-level dispatch callback for termination executed on the worker isolate UI loop thread
void onNativeTerminate(ffi.Pointer<ffi.Void> webviewInstance, ffi.Pointer<ffi.Void> arg) {
    if (webviewInstance == ffi.nullptr) return;

    print('[WebView UI Thread] Terminating webview loop...');
    final dylib = ffi.DynamicLibrary.open('webview.dll');
    final WebviewTerminate webviewTerminate = dylib.lookupFunction<webview_terminate_native, WebviewTerminate>('webview_terminate');

    webviewTerminate(webviewInstance);
}

// Dedicated background isolate entry point for WebView initialization and message loop.
// Moving webviewRun here ensures the native Win32 message loop does NOT block
// the main thread's Dart async event loop / I/O loop.
void _webviewWorker(SendPort mainSendPort) {
    final String dllPath = 'webview.dll';
    final dylib = ffi.DynamicLibrary.open(dllPath);

    final WebviewCreate webviewCreate = dylib.lookupFunction<webview_create_native, WebviewCreate>('webview_create');
    final WebviewRun webviewRun = dylib.lookupFunction<webview_run_native, WebviewRun>('webview_run');
    final WebviewDestroy webviewDestroy = dylib.lookupFunction<webview_destroy_native, WebviewDestroy>('webview_destroy');
    final WebviewNavigate webviewNavigate = dylib.lookupFunction<webview_navigate_native, WebviewNavigate>('webview_navigate');

    print('Initializing native Webview context in isolate...');
    final ffi.Pointer<ffi.Void> webviewInstance = webviewCreate(0, ffi.nullptr);

    // Initial page load
    final initialUrlPtr = 'https://www.google.com'.toNativeUtf8();
    webviewNavigate(webviewInstance, initialUrlPtr);
    calloc.free(initialUrlPtr);

    // Register native callbacks in this isolate.
    // Dart FFI requires Pointer.fromFunction callbacks to be executed on the isolate that created them.
    final dispatchCallbackPointer = ffi.Pointer.fromFunction<webview_dispatch_fn_native>(onNativeDispatch);
    final terminateCallbackPointer = ffi.Pointer.fromFunction<webview_dispatch_fn_native>(onNativeTerminate);

    final workerReceivePort = ReceivePort();

    // Send initialized handles and callback pointers to main isolate
    mainSendPort.send(WebviewWorkerInit(
        webviewAddress: webviewInstance.address,
        dispatchCallbackAddress: dispatchCallbackPointer.address,
        terminateCallbackAddress: terminateCallbackPointer.address,
        isolateCommandPort: workerReceivePort.sendPort,
    ));

    workerReceivePort.listen((message) {
        if (message == 'terminate') {
            final WebviewTerminate webviewTerminate = dylib.lookupFunction<webview_terminate_native, WebviewTerminate>('webview_terminate');
            webviewTerminate(webviewInstance);
        }
    });

    // Native blocking loop running in this worker isolate
    webviewRun(webviewInstance);

    // Clean up when loop exits
    webviewDestroy(webviewInstance);
    workerReceivePort.close();
    mainSendPort.send('closed');
}

// Asynchronous stdin listener.
// Utilizing Dart's asynchronous I/O stream, this does NOT block the main event loop.
StreamSubscription<String> _stdinListener(StdinWorkerConfig config) {
    final dylib = ffi.DynamicLibrary.open('webview.dll');
    final WebviewDispatch webviewDispatch = dylib.lookupFunction<webview_dispatch_native, WebviewDispatch>('webview_dispatch');

    final webviewInstance = ffi.Pointer<ffi.Void>.fromAddress(config.webviewAddress);
    final dispatchCallback = ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>>.fromAddress(config.callbackAddress);
    final terminateCallback = ffi.Pointer<ffi.NativeFunction<webview_dispatch_fn_native>>.fromAddress(config.terminateCallbackAddress);

    return stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return;

            if (trimmed.toLowerCase() == 'exit' || trimmed.toLowerCase() == 'quit') {
                print('[Stdin] Received exit command, closing webview...');
                webviewDispatch(webviewInstance, terminateCallback, ffi.nullptr);
                return;
            }

            String targetUrl = trimmed;
            if (!targetUrl.startsWith('http://') && 
                !targetUrl.startsWith('https://') && 
                !targetUrl.startsWith('file://')) {
                targetUrl = 'https://$targetUrl';
            }

            print('[Stdin] Input received ("$trimmed"), dispatching to: $targetUrl');

            // Allocate a UTF-8 representation of our string directly on the native heap.
            // This is freed inside `onNativeDispatch` once the isolate UI loop handles navigation.
            final ffi.Pointer<Utf8> urlNativeStringHeap = targetUrl.toNativeUtf8();
            webviewDispatch(
                webviewInstance,
                dispatchCallback,
                urlNativeStringHeap.cast<ffi.Void>()
            );
        });
}

void main() async {
    final String dllPath = 'webview.dll';
    if (!File(dllPath).existsSync()) {
        print('Error: webview.dll not found in the current directory!');
        return;
    }

    final initCompleter = Completer<WebviewWorkerInit>();
    final mainReceivePort = ReceivePort();
    StreamSubscription<String>? stdinSub;

    mainReceivePort.listen((message) {
        if (message is WebviewWorkerInit && !initCompleter.isCompleted) {
            initCompleter.complete(message);
        } else if (message == 'closed') {
            stdinSub?.cancel();
            mainReceivePort.close();
            exit(0);
        }
    });

    // 1. Spawn the dedicated WebView runner isolate
    await Isolate.spawn(_webviewWorker, mainReceivePort.sendPort);

    // 2. Wait for the isolate to initialize WebView and provide handles
    final initData = await initCompleter.future;

    // 3. Start non-blocking asynchronous stdin listener on the active Dart event loop
    stdinSub = _stdinListener(StdinWorkerConfig(
        initData.webviewAddress,
        initData.dispatchCallbackAddress,
        initData.terminateCallbackAddress,
    ));

    print('\n======================================================');
    print('Webview Running via Webview_Dispatch Queue (in Isolate)!');
    print('Type a URL here and press Enter (or type "exit" to quit):');
    print('Example: pub.dev or github.com');
    print('======================================================\n');
}
