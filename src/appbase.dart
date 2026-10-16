// Libs
import "dart:isolate";
import "libs.dart";
import "modules/constants.dart";

var ____CLASS____;

// App class
class Appbase {    
    int? webviewAddress;

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
        await sleepMs(1000);
        print("After sleep");
        return params;
    }

    var ___CORE____;
    
    // Make js code
    String makeJsCode(port){
        return """
        var _acallProms = {};

        function newLock(){
            var unlock,lock=new Promise((res,rej)=>{ unlock=res; });
            return [lock,unlock];
        }
        function toJson(v){
            return JSON.stringify(v);
        }
        function fromJson(str){
            try { return JSON.parse(str); }
            catch { return null; }
        }
        async function acall(funcName,params){
            var callId = Math.random().toString();            
            var [lock,unlock]=newLock();
            _acallProms[callId]={ unlock };

            window._ws.send(toJson({
                callId, func:funcName, params
            }));
            return await lock;
        }

        window._ws = new WebSocket('ws://localhost:$port/ws');
        _ws.onopen = () => _ws.send(toJson({ msg:'Hello Dart!' }));

        _ws.onmessage = ev =>{
            var obj = fromJson(ev.data);

            if (obj.callId){
                let rsult = obj.result;
                _acallProms[obj.callId](result);
            }
        };
        """;
    }

    // Start the app
    Future<void> start() async{
        // Functions for frontend
        var funcs = {
            "echo":(this.echo,syn), "sum":(this.sum,asyn)
        };

        // Load frontend
        var html = await Fs.readFile("./frontend/bundle.min.html");   

        // Port for frontend to ws to
        if (!platformIsWeb()){
            var backend;
            backend = await HttpServer.bind('0.0.0.0', 0);
            print("Local port: ${backend.port}");

            backend.listen((request) async {
                if (request.uri.path == '/ws') {
                    final ws = await WebSocketTransformer.upgrade(request);

                    ws.listen((message) async{                        
                        print('Received: $message');
                        // ws.add('Echo: $message');
                        var obj = fromJson(message);

                        if (obj["func"] != null){
                            var funcName = obj["func"];
                            var params = obj["params"];
                            var callId = obj["callId"];
                            var result = await funcs[funcName]!.$1(params);
                            ws.add(toJson({
                                "callId":callId, "result":result
                            }));
                        }
                    });
                    return;
                }
                // Normal HTTP requests
                request.response
                ..statusCode = HttpStatus.ok
                ..write('HTTP backend is running');
                await request.response.close();
            });
            html += "<script>window._backendPort = ${backend.port};</script>";     
            html += "<script>${makeJsCode(backend.port)}</script>";
        }        

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
        receiver.listen((data) async{
            if (data["webviewAddress"] != null){
                this.webviewAddress = data["webviewAddress"];
            }else if (data["func"] != null){
                var funcName = data["func"];
                var params = data["params"];
                var respondTo = data["respondTo"];
                var result = await funcs[funcName]!.$1(params);

                // NOTE: EVEN STATIC PROPS IN DIFFERENT ISOLATES DIFFER.
                // Static method but calling from main thread is different 
                // from inside the isolate spawn below, when the WebView_.createAndRun
                // is called, it sends back the webview address to use.
                WebView_.sendToJs(this.webviewAddress!, respondTo, result);
            }
        });

        Map<String,dynamic> data = {
            "outer": receiver.sendPort
        };
        Isolate.spawn((data){
            print("Spawning WebView thread...");
            var outer = data["outer"];
            WebView_.createAndRun(outer!,funcs,html); // Don't await here, no use.       

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