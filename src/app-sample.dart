// Libs
import "libs.dart";
import "appbase.dart";
import 'package:hotreloader/hotreloader.dart';

// App with custom features
class App extends Appbase {    
}  

void main() async{
    // Experimental: Disabled, breaks Dart-Webview communication, sometimes.
    // To disable: this line and the line enable-vm-service in run.ps1
    await HotReloader.create();
    // 1s delay to ensure communication with webview in isolate(?)
    await sleepMs(1000);
    print("App is running... Modify code to hot reload!");

    // Start app
    print("Dawio starting...");
    print("Platform name: ${getPlatformName()}");
    var app = new App();  
    app.start();    
}  