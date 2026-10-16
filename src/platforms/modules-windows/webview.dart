// Libs
import 'dart:ffi';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Modules
import "../../modules/utils.dart";
import "../../modules/constants.dart";

var ____FFI____;

// Foreign functions
typedef WebViewCreateC = Pointer<Void> Function(Int32 debug, Pointer<Void> window);
typedef WebViewCreateDart = Pointer<Void> Function(int debug, Pointer<Void> window);

typedef WebViewNavigateC = Void Function(Pointer<Void> w, Pointer<Char> url);
typedef WebViewNavigateDart = void Function(Pointer<Void> w, Pointer<Char> url);

typedef WebViewRunC = Void Function(Pointer<Void> w);
typedef WebViewRunDart = void Function(Pointer<Void> w);

typedef WebViewEvalC = Void Function(Pointer<Void> w, Pointer<Char> js);
typedef WebViewEvalDart = void Function(Pointer<Void> w, Pointer<Char> js);

typedef WebViewDestroyC = Void Function(Pointer<Void> w);
typedef WebViewDestroyDart = void Function(Pointer<Void> w);

typedef WebViewBindCallbackC = Void Function(Pointer<Char> id,Pointer<Char> req,Pointer<Void> arg);
typedef WebViewBindCallbackDart = void Function(Pointer<Char> id,Pointer<Char> req,Pointer<Void> arg);

typedef WebViewBindC = Int32 Function(Pointer<Void> w,Pointer<Char> name,
    Pointer<NativeFunction<WebViewBindCallbackC>> fn,Pointer<Void> arg);
typedef WebViewBindDart = int Function(Pointer<Void> w,Pointer<Char> name,
    Pointer<NativeFunction<WebViewBindCallbackC>> fn,Pointer<Void> arg);

typedef WebViewReturnC = Int32 Function(Pointer<Void> w,Pointer<Char> id,Int32 status,
    Pointer<Char> result);
typedef WebViewReturnDart = int Function(Pointer<Void> w,Pointer<Char> id,int status,
    Pointer<Char> result);

typedef WebViewDispatchCallbackC = Void Function(Pointer<Void> w,Pointer<Void> arg);
typedef WebViewDispatchCallbackDart = void Function(Pointer<Void> w,Pointer<Void> arg);

typedef WebViewDispatchC = Void Function(Pointer<Void> w,
    Pointer<NativeFunction<WebViewDispatchCallbackC>> fn,Pointer<Void> arg);
typedef WebViewDispatchDart = void Function(Pointer<Void> w,
    Pointer<NativeFunction<WebViewDispatchCallbackC>> fn,Pointer<Void> arg);

typedef WebViewTerminateC = Void Function(Pointer<Void> w);
typedef WebViewTerminateDart = void Function(Pointer<Void> w);

var ____CLASSES____;

// Config for webview
class WebViewConfig {
    final int webviewAddress;
    final int navigateFuncAddr;    
    final int terminateFuncAddr;
    final int jsCallReturnFuncAddr;
    final int jsProcReturnFuncAddr;

    // Ctor
    WebViewConfig(
        this.webviewAddress, this.navigateFuncAddr, this.terminateFuncAddr,
        this.jsCallReturnFuncAddr, this.jsProcReturnFuncAddr
    );
}

// WebView for Windows
// See: https://github.com/webview/webview/blob/master/core/include/webview/api.h
// Communication: 
//   - JS -> Dart: webview_bind + webview_dispatch (with webview_return)
//   - JS -> Dart: websocket
//   - Dart -> JS: webview_eval + wait for webview_bind call.
//   - Dart -> JS: websocket
class WebView_ {
    static Map funcs = {};
    static late Pointer<Void> webview;
    static late WebViewConfig config;
    static Map<String,dynamic> jsCallResults = {}; // id-> result
    static Map<String,dynamic> jsProcResults = {}; // id-> result
    static SendPort? outer;

    // Send to js
    // NOTE: USE WEBSOCKET TO SEND TO JS INSTEAD!
    // WARN: THIS METHOD IS CALLED FROM MAIN THREAD, NOT FROM INSIDE THE
    // ISOLATE OF THE WEBVIEW.
    static void sendToJs(int webviewAddress, String respondTo, value){
        final dl = DynamicLibrary.open('webview.dll');        
        print(respondTo);
        print(value);
        // ISSUE: CAN'T CALL FUNCS OF WEBVIEW.DLL FROM THREAD
        // WHERE THE WEBVIEW IS NOT CREATED AT.
        print("Webview address: ${webviewAddress}");

        // See the proof of working in dispatchJsCallResult
        // but doesn't working here in wrong thread:
        final WebViewEvalDart webviewEval = 
            dl.lookupFunction<WebViewEvalC, WebViewEvalDart>('webview_eval');
        Pointer<Char> str = "alert()".toNativeUtf8().cast<Char>();
        var webviewPtr = Pointer<Void>.fromAddress(webviewAddress);
        webviewEval(webviewPtr, str);
        malloc.free(str);

        dl.close();
    }

    // Top-level dispatch callback for navigation executed on the main UI thread
    static void dispatchNavigation(Pointer<Void> webviewInstance, Pointer<Void> urlArgPointer) {
        if (urlArgPointer == nullptr || webviewInstance == nullptr) return;

        // 1. Cast the raw generic pointer back into a UTF-8 C-String pointer
        final Pointer<Utf8> urlStringPointer = urlArgPointer.cast<Utf8>();
        final String urlString = urlStringPointer.toDartString();
        print('[WebView UI Thread] Navigating to: $urlString');

        // 2. Perform the navigation action inside the main GUI execution loop thread context
        final dylib = DynamicLibrary.open('webview.dll');
        final WebViewNavigateDart webviewNavigate = 
            dylib.lookupFunction<WebViewNavigateC, WebViewNavigateDart>('webview_navigate');
        webviewNavigate(webviewInstance, urlStringPointer.cast<Char>());

        // 3. Free the string memory allocated on the heap during the dispatch call setup
        calloc.free(urlStringPointer);
        dylib.close();
    }

    // Top-level dispatch callback for termination executed on the main UI thread
    static void dispatchTermination(Pointer<Void> webviewInstance, Pointer<Void> arg) {
        if (webviewInstance == nullptr) return;

        print('[WebView UI Thread] Terminating webview loop...');
        final dylib = DynamicLibrary.open('webview.dll');
        final WebViewTerminateDart webviewTerminate = 
            dylib.lookupFunction<WebViewTerminateC, WebViewTerminateDart>('webview_terminate');

        webviewTerminate(webviewInstance);
        dylib.close();
    }

    // Send back result to JS
    static void dispatchJsCallResult(Pointer<Void> w, Pointer<Void> id){
        // onJsCall malloc'ed the id, free at end of this method
        final Pointer<Utf8> idHeapPtr = id.cast<Utf8>();
        String idStr = idHeapPtr.toDartString(); // Managed str, no need free.

        // todo: Load dll once
        final dylib = DynamicLibrary.open('webview.dll');
        final WebViewReturnDart webviewReturn = 
            dylib.lookupFunction<WebViewReturnC, WebViewReturnDart>('webview_return');

        // PROOF OF WORK TO CHECK sendToJs, DONT REMOVE.
        // Proof that eval works:
        // final WebViewEvalDart webviewEval = 
        //     dylib.lookupFunction<WebViewEvalC, WebViewEvalDart>('webview_eval');
        // Pointer<Char> str = "alert()".toNativeUtf8().cast<Char>();
        // var webviewPtr = Pointer<Void>.fromAddress(webview.address);
        // webviewEval(webviewPtr, str);
        // malloc.free(str);

        // Return the result to the call from JS
        print("Call returning...");        
        final result = toJson(_thisclass.jsCallResults[idStr]);
        _thisclass.jsCallResults.remove(idStr); // Created in onJsCall
        final resultPtr = result!.toNativeUtf8();

        final targetWebview = (w != nullptr) ? w : _thisclass.webview;
        // Fails at this point if using the original 'id' pointer by webview:
        // (see bug note in onJsCall)
        webviewReturn(targetWebview, idHeapPtr.cast<Char>(), 0, resultPtr.cast<Char>());
        print("Call returned");

        calloc.free(idHeapPtr); // Created in onJsCall, free here.
        calloc.free(resultPtr);
        dylib.close();
    }

    // Receive calls from JS, process and prepare to send back result
    // Can work with both sync and async funcs in _thisclass.funcs
    // but if heavy processing is needed: use onJsProc as it has a separate isolate
    // to avoid heavy load on main thread.
    static void onJsCall(Pointer<Char> id,Pointer<Char> req,Pointer<Void> arg) {
        // Clone to use, 'id' string is created by webview.dll and freed
        String idStr = id.cast<Utf8>().toDartString(); // Not to use id from this line
        print('id: $idStr');
        String json = req.cast<Utf8>().toDartString();
        print('req: $json');
        var arr = jsonDecode(json); // Always 2 items, required.
        var funcName = arr[0];
        var params = arr[1];

        void dispatchResult(dynamic res) {
            print("Sending to webview: $res");
            _thisclass.jsCallResults[idStr] = res; // Will remove in dispatchJsCallResult

            final webviewInstance = Pointer<Void>.fromAddress(config.webviewAddress);
            final callback = Pointer<NativeFunction<WebViewDispatchCallbackC>>
                .fromAddress(config.jsCallReturnFuncAddr);
            final dylib = DynamicLibrary.open('webview.dll');
            final WebViewDispatchDart webviewDispatch = 
                dylib.lookupFunction<WebViewDispatchC, WebViewDispatchDart>('webview_dispatch');
            
            // Allocate id on native heap so it outlives this callback frame!
            // idHeapPtr will be freed in: dispatchJsCallResult
            final Pointer<Utf8> idHeapPtr = idStr.toNativeUtf8(); // malloc
            webviewDispatch(
                webviewInstance, callback,
                // Use cloned string (old bug code: id.cast, see: docs/issues)
                idHeapPtr.cast<Void>()
            );
            dylib.close();
            print("Sent");
        }
        // onJsCall is in the isolate which starts WebView_.createAndRun
        // but webview consumes the thread and blocks Dart event loop.
        // Can't 'await' at all, even ReceivePort in this onJsCall doesn't work as it relies on 
        // the event loop; must create isolate and poll for result?
        // Static method can be passed to isolate but no points without props outside.
        // Dynamic method can'T be passed to isolate (it's isolated, no shared vars).
        // Can't pass Future to another isolate coz it's on the event loop where it's created.  
        // Thus isolate is no use, send message to main thread instead:
        if (_thisclass.funcs[funcName].$2 == asyn) {
            print("Func is async");    
            dispatchResult({"error":"use-acall-for-async-not-call"});

            // This old method wont work coz sendToJs method doesnt'
            // _thisclass.outer!.send({
            //     "func":funcName, "params":params, "respondTo":randStr()
            // });            

            // To use sendToJs but not working.
            // This '.then' assign the callback but never run coz webview consumed thread.
            // res.then((val){ 
            //     print("Inside then");
            //     dispatchResult(val);
            // });            
        } else {
            var res = _thisclass.funcs[funcName].$1(params);
            dispatchResult(res);
        }
    }

    // Send back result to JS after long running isolate
    static void dispatchJsProcResult(Pointer<Void> w, Pointer<Void> id){
        // DEP: now using pcall thru websocket
    }

    // Receive calls from JS, long processing and prepare to send back result
    static void onJsProc(Pointer<Char> id,Pointer<Char> req,Pointer<Void> arg) {
        // DEP: now using pcall thru websocket
    }

    // Console input
    static void stdinListener(WebViewConfig config) {
        final dylib = DynamicLibrary.open('webview.dll');
        final WebViewDispatchDart webviewDispatch = 
            dylib.lookupFunction<WebViewDispatchC, WebViewDispatchDart>('webview_dispatch');

        final webviewInstance = Pointer<Void>.fromAddress(config.webviewAddress);
        final dispatchCallback = Pointer<NativeFunction<WebViewDispatchCallbackC>>
            .fromAddress(config.navigateFuncAddr);
        final terminateCallback = Pointer<NativeFunction<WebViewDispatchCallbackC>>
            .fromAddress(config.terminateFuncAddr);

        while (true) {
            final line = stdin.readLineSync();
            if (line == null) break;
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;

            if (trimmed.toLowerCase() == 'exit' || trimmed.toLowerCase() == 'quit') {
                print('[Stdin] Received exit command, closing webview...');
                webviewDispatch(webviewInstance, terminateCallback, nullptr);
                break;
            }
            String targetUrl = trimmed;

            if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://') && 
                    !targetUrl.startsWith('file://')) {
                targetUrl = 'https://$targetUrl';
            }
            print('[Stdin] Input received ("$trimmed"), dispatching to: $targetUrl');

            // Allocate a UTF-8 representation of our string directly on the native heap.
            // This is freed inside `onNativeDispatch` once the main thread handles navigation.
            final Pointer<Utf8> urlNativeStringHeap = targetUrl.toNativeUtf8();
            webviewDispatch(
                webviewInstance, dispatchCallback, urlNativeStringHeap.cast<Void>()
            );
        }
        dylib.close();
    }

    // Create
    // ********************************************
    // WARN: RUN ONCE ONLY, MEMLEAK NOT TESTED YET.
    // ********************************************
    static Future<void> createAndRun(SendPort outer,Map funcs,String html) async{
        _thisclass.outer = outer;
        _thisclass.funcs = funcs;

        // 1. Open the compiled webview.dll file
        final dl = DynamicLibrary.open('webview.dll');

        // 2. Map all the required lifecycle functions from the DLL
        final WebViewCreateDart webviewCreate = dl
            .lookup<NativeFunction<WebViewCreateC>>('webview_create').asFunction();
        final WebViewNavigateDart webviewNavigate = dl
            .lookup<NativeFunction<WebViewNavigateC>>('webview_navigate').asFunction();
        final WebViewRunDart webviewRun = dl
            .lookup<NativeFunction<WebViewRunC>>('webview_run').asFunction();
        final WebViewEvalDart webviewEval = dl
            .lookup<NativeFunction<WebViewEvalC>>('webview_eval').asFunction();
        final WebViewDestroyDart webviewDestroy = dl
            .lookup<NativeFunction<WebViewDestroyC>>('webview_destroy').asFunction();
        final WebViewBindDart webviewBind = dl
            .lookup<NativeFunction<WebViewBindC>>('webview_bind').asFunction();
        final WebViewReturnDart webviewReturn = dl
            .lookup<NativeFunction<WebViewReturnC>>('webview_return').asFunction<WebViewReturnDart>();   
        final WebViewDispatchDart webviewDispatch = dl
            .lookup<NativeFunction<WebViewDispatchC>>('webview_dispatch').asFunction<WebViewDispatchDart>();

        // Make data url
        var dataUrl = "data:text/html;charset=utf-8,${Uri.encodeComponent(html)}";

        // 3. Create the top-level WebView2 window context
        // Debug mode is set to 0 (false), parent window is nullptr
        final Pointer<Void> webview = webviewCreate(0, nullptr);

        if (webview == nullptr) {
            print("Failed to initialize webview instance.");
            dl.close();
            return;
        }
        _thisclass.webview = webview;

        // JS call: synchronous calculation 
        final onJsCallFunc = Pointer.fromFunction<WebViewBindCallbackC>(_thisclass.onJsCall);
        final name = 'call'.toNativeUtf8();
        webviewBind(webview,name.cast<Char>(),onJsCallFunc,nullptr);
        calloc.free(name);

        // JS call: Asynchronous calculation 
        // DEP: Now using pcall thru' websocket
        /*
        final onJsProcessingFunc = Pointer.fromFunction<WebViewBindCallbackC>(_thisclass.onJsProc);
        final name2 = 'proc'.toNativeUtf8();
        webviewBind(webview,name2.cast<Char>(),onJsProcessingFunc,nullptr);
        calloc.free(name2);
        */

        // Config for webview
        final Pointer<NativeFunction<WebViewDispatchCallbackC>> navigateFunc = 
            Pointer.fromFunction<WebViewDispatchCallbackC>(dispatchNavigation);
        final Pointer<NativeFunction<WebViewDispatchCallbackC>> terminateFunc = 
            Pointer.fromFunction<WebViewDispatchCallbackC>(dispatchTermination);
        final Pointer<NativeFunction<WebViewDispatchCallbackC>> jsCallReturnFunc = 
            Pointer.fromFunction<WebViewDispatchCallbackC>(dispatchJsCallResult);
        final Pointer<NativeFunction<WebViewDispatchCallbackC>> jsProcReturnFunc = 
            Pointer.fromFunction<WebViewDispatchCallbackC>(dispatchJsProcResult);        

        config = WebViewConfig(
            webview.address, navigateFunc.address, terminateFunc.address,
            jsCallReturnFunc.address, jsProcReturnFunc.address
        );
        _thisclass.outer!.send({
            "webviewAddress":webview.address
        });
        print("Webview address: ${webview.address}");        

        // 4. Navigate to your target page
        final urlPointer = dataUrl.toNativeUtf8();
        webviewNavigate(webview, urlPointer.cast<Char>());
        calloc.free(urlPointer);
        
        // // Read console to change url
        // await Isolate.spawn(
        //     stdinListener, config
        // );

        // 5. Start the blocking Win32 window message loop
        print("Opening WebView2 window...");
        webviewRun(webview);

        // 6. Clean up memory once the user closes the window
        webviewDestroy(webview);
        dl.close();
        print("Main window closed");
    } // create
}
typedef _thisclass = WebView_;
