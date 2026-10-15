echo "Option 1: Only in Antie/VSCode/IntelliJ"
echo "Warn: This option may break webview sometimes"
echo "Use 'Dart' extension in Antie/VSCode"
echo "Debug Start -> Palette -> Dart: Hot reload"
echo "See: https://github.com/Dart-Code/Dart-Code/issues/2708"
echo ""

echo "Option 2: This option seems observing 1 file only"
echo "Warn: This option may break webview sometimes"
echo "This option is incomplete."
echo 'dart run --observe app.dart'
echo ""

echo "Option 3: This option is avail in any env"
echo "Warn: This option may break webview sometimes, too."
echo "Use Dart + DartVM together with its hotreload protocol"
echo "Already in app-sample.dart"