// Libs
import "dart:isolate";
import "libs.dart";

var ____CLASS____;

// App class
class Appbase {    
    // Ctor
    Appbase();

    // Echo back the params
    dynamic echo(params){
        print("Echo is called by JS");
        return params;
    }

    // Sum numbers
    Future<dynamic> sum(params) async{
        print("Sum is called by JS");
        return params;
    }

    var ___CORE____;

    // Start the app
    Future<void> start() async{
        // Functions for frontend
        var funcs = {
            "echo":this.echo, "sum":this.sum
        };

        // Load frontend
        var html = await Fs.readFile("./frontend/bundle.html");        

        // // Backend thread
        // var receiver = ReceivePort(); 
        // receiver.listen((map){
        //     // todo
        // });
        // Isolate.spawn((SendPort sendPort){
        //     // todo
        // },receiver.sendPort);

        // THIS COMMENT IS OUTDATED, SEE FIX IN webview2x FOLDER.
        // Key points
        //   - When webview.dll is in isolate, every FFI funcs must be in there
        //   - Use create ReceivePort inside and outside for communication.
        // ------------------------------------------------------
        // WebView_ MUST hold the main thread for Dart<->JS communication to work,
        // unsure reason but tested, WebView2 comm won't function in Isolate.
        // *****************************************************************
        // POSSIBLY: WebView NEEDS TO BE ON MAIN THREAD FOR ITS MESSAGE LOOP
        // TO BE ABLE TO RECEIVE MESSAGES INCLUDING WEBVIEW_DISPATCH, ETC.
        // OR ALL THE CREATED PARTS OF WEBVIEW.DLL NEED TO COORDINATE AROUND
        // A KNOWN THREAD WHICH IS THE MAIN THREAD. UI IS GOOD ON MAIN THREAD
        // TO BE SMOOTHEST.
        // *****************************************************************
        // Additional details about webview.dll (github.com/webview)
        //   - webview_bind binds to Dart func
        //   - Inside the bound Dart func, can't call webview_return directly
        //   - Inside the found Dart func, do webview_dispatch
        var receiver = ReceivePort();
        receiver.listen((data){
            //
        });

        Map<String,dynamic> data = {
            "outer": receiver.sendPort
        };
        Isolate.spawn((data){
            print("Spawning WebView thread...");
            WebView_.createAndRun(funcs,html); // Don't await here, no use.       

            if (!platformIsWeb())
                processExit();
        },data);
    }
}

// var ____CORE____;

// // Main
// void main(){
//     print("Dawio starting...");
//     print("Platform name: ${getPlatformName()}");
//     var app = new App();
//     app.start();
// }