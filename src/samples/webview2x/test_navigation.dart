import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  print('====================================================');
  print('Starting Automated Navigation Test for webview2x.dart');
  print('====================================================');

  final process = await Process.start('dart', ['webview2x.dart'], workingDirectory: Directory.current.path);

  final List<String> logs = [];
  final Completer<void> readyCompleter = Completer<void>();
  final Completer<void> pubDevCompleter = Completer<void>();
  final Completer<void> githubCompleter = Completer<void>();
  final Completer<void> exitCompleter = Completer<void>();

  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    final tagged = '[APP STDOUT] $line';
    print(tagged);
    logs.add(line);

    if (line.contains('Type a URL here and press Enter') && !readyCompleter.isCompleted) {
      readyCompleter.complete();
    }
    if (line.contains('[WebView UI Thread] Navigating to: https://pub.dev') && !pubDevCompleter.isCompleted) {
      pubDevCompleter.complete();
    }
    if (line.contains('[WebView UI Thread] Navigating to: https://github.com') && !githubCompleter.isCompleted) {
      githubCompleter.complete();
    }
    if (line.contains('Terminating webview loop') && !exitCompleter.isCompleted) {
      exitCompleter.complete();
    }
  });

  process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    print('[APP STDERR] $line');
  });

  // 1. Wait for webview to initialize
  print('\n[TEST] Step 1: Waiting for webview initialization...');
  await readyCompleter.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw Exception('Timed out waiting for webview initialization!'),
  );
  print('[TEST] PASS: Webview initialized and ready for input.\n');

  // Small delay to ensure stdin reader is waiting
  await Future.delayed(const Duration(milliseconds: 500));

  // 2. Send "pub.dev\n"
  print('[TEST] Step 2: Simulating user typing "pub.dev" and pressing Enter...');
  process.stdin.writeln('pub.dev');
  await process.stdin.flush();

  await pubDevCompleter.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw Exception('Timed out waiting for navigation to pub.dev!'),
  );
  print('[TEST] PASS: Successfully received Enter and navigated to https://pub.dev on UI thread.\n');

  await Future.delayed(const Duration(seconds: 1));

  // 3. Send "github.com\n"
  print('[TEST] Step 3: Simulating user typing "github.com" and pressing Enter...');
  process.stdin.writeln('github.com');
  await process.stdin.flush();

  await githubCompleter.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw Exception('Timed out waiting for navigation to github.com!'),
  );
  print('[TEST] PASS: Successfully received Enter and navigated to https://github.com on UI thread.\n');

  await Future.delayed(const Duration(seconds: 1));

  // 4. Send "exit\n"
  print('[TEST] Step 4: Simulating user typing "exit" and pressing Enter...');
  process.stdin.writeln('exit');
  await process.stdin.flush();

  final exitCode = await process.exitCode.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      process.kill();
      throw Exception('Timed out waiting for clean exit!');
    },
  );

  print('[TEST] Process exited with exit code: $exitCode');
  if (exitCode == 0) {
    print('\n====================================================');
    print('ALL AUTOMATED TESTS PASSED SUCCESSFULLY!');
    print('====================================================');
  } else {
    throw Exception('Process exited with non-zero exit code: $exitCode');
  }
}
