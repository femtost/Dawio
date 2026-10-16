// Libs
import "libs.dart";
import "appbase.dart";
import 'package:hotreloader/hotreloader.dart';

// App with custom features
class App extends Appbase {    
}  

void main() async{
    // Hot reload enabled via HotReloader and --enable-vm-service
    await HotReloader.create();
    print("App is running... modify code to hot reload!");

    // Start app
    print("Dawio starting...");
    print("Platform name: ${getPlatformName()}");
    var app = new App();  
    app.start();    
}  