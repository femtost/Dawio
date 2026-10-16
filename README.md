# Dawio

Dart And Web In One<br>
Dart + HTML/CSS, a crossplatform codebase.


# Purpose

Dart is the **best-of-both-world** language for statictyped speed (similar to C/C++) 
and dynamictyped flexibility (similar to JS).

JS(minimal)/HTML/CSS is for fast and **flexible UI** development. While JS
is only vanilla JS and with minimal libs, it's for UI performance, UX.


# Tech Stack

Backend (Logic)
  - Dart (with some features from Flutter but not Flutter UI)

Frontend (WebView)
  - JS(minimal)/HTML/CSS


# How to Use

Start point
  - Clone/fork this repo, itself is an app.

Update
  - Git pull from this original repo.  

Run command:
  - `cd src && run.ps1 VARIATION-NAME PLATFORM-NAME`
  - Example: `run.ps1 sample windows`
  - No variation, production: `run.ps1 main windows`


# Dependencies

All platforms
  - `Dart`: Built-in libraries

Android
  - *Note*: To find webview.dll equivalent, or Android native

iOS
  - *Note*: To find webview.dll equivalent, or iOS native

Windows
  - `webview.dll`: github.com/webview/webview
      - Use 'pip install webview_python'
      - Run 'python', import webview_python once or twice
      - Go to the pip package webview_python to get *webview.dll & WebView2Loader.dll*

macOS
  - `webview.dylib`: Use the same method of webview.dll to get

Linux
  - `webview.so`: Use the same method of webview.dll to get

Web
  - `Iframe Tag`: Instead of webview

Legacy 
  - `WebView2Loader.dll` from https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.4191.47
      - Download, change to .zip, find the DLL file
      - Use name WebView2Loader.nuget.dll to avoid confusion with the one by webview_python


# Conventions

Class naming:
  - Use `ClassName` for pure Dart class
  - The `ClassName_` is copied out from platforms/modules-x

____
