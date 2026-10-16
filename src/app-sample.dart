// Libs
import 'package:hotreloader/hotreloader.dart';
import "libs.dart";
import "appbase.dart";
import "modules/constants.dart";

// App with custom features
class App extends Appbase {    

    // Test
    Future<String> test(params) async{
        return "test";
    }

    // Add more method
    void customInit(){
        this.funcs["test"] = (this.test,asyn);
    }
}  

void main() async{
    // Hot reload enabled via HotReloader and --enable-vm-service
    await HotReloader.create();
    print("App is running... modify code to hot reload!");

    // Start app
    print("Dawio starting...");
    print("Platform name: ${getPlatformName()}");
    var app = new App();  
    app.init();
    app.customInit();
    app.start();    
}  