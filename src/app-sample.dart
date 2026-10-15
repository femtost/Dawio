// Libs
import "libs.dart";
import "appbase.dart";
import 'package:hotreloader/hotreloader.dart';

class App extends Appbase {
    
}  

void main() async{
    // Experimental: Disabled, breaks Dart-Webview communication, sometimes.
     await HotReloader.create();
    // 1s delay to ensure communication with webview in isolate
    await sleepMs(1000);


  print("App is running... Modify code to hot reload!");

    print("Dawio starting...");
    print("Platform name: ${getPlatformName()}");
    var app = new App();  
    app.start();    
}  