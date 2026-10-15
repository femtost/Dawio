// Google AI Mode
#include <windows.h>
#include <string>
#include "webview.h" // Include the webview header from the library

// Global handles and pointers
HWND hEditInput = NULL;
HWND hBtnGo = NULL;
webview_t g_webview = NULL;
WNDPROC oldEditProc = NULL;

#define IDC_INPUT_BOX 101
#define IDC_GO_BUTTON 102

// Function to handle changing URLs
void NavigateToInputUrl() {
    if (!g_webview || !hEditInput) return;

    wchar_t wUrl[1024];
    GetWindowTextW(hEditInput, wUrl, 1024);

    // Convert wide characters to UTF-8 for webview_navigate
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wUrl, -1, NULL, 0, NULL, NULL);
    std::string url(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, wUrl, -1, &url[0], size_needed, NULL, NULL);

    // Strip trailing null character safely added by std::string sizing
    if (!url.empty() && url.back() == '\0') {
        url.pop_back();
    }

    // Basic URL validation fallback if user omits schema
    if (url.find("http://") != 0 && url.find("https://") != 0 && url.find("file://") != 0) {
        url = "https://" + url;
    }

    // Call webview.dll routine to navigate
    webview_navigate(g_webview, url.c_str());
}

// Subclass the edit box to catch the 'Enter' key press
LRESULT CALLBACK EditSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    if (uMsg == WM_KEYDOWN && wParam == VK_RETURN) {
        NavigateToInputUrl();
        return 0; // Prevent the default beep sound on Enter
    }
    return CallWindowProc(oldEditProc, hWnd, uMsg, wParam, lParam);
}

// Window Procedure for the hosting container window
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_CREATE: {
            // 1. Create the text input field (Address Box)
            hEditInput = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"https://www.google.com",
                WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
                10, 10, 500, 25, hWnd, (HMENU)IDC_INPUT_BOX, NULL, NULL);

            // Subclass to intercept Enter key press
            oldEditProc = (WNDPROC)SetWindowLongPtrW(hEditInput, GWLP_WNDPROC, (LONG_PTR)EditSubclassProc);

            // 2. Create the "Go" button
            hBtnGo = CreateWindowW(L"BUTTON", L"Go",
                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                520, 10, 60, 25, hWnd, (HMENU)IDC_GO_BUTTON, NULL, NULL);

            // 3. Initialize Webview inside the remaining container window space
            g_webview = webview_create(0, hWnd);
            webview_set_title(g_webview, "WebView.dll Address Bar Demo");
            webview_navigate(g_webview, "https://www.google.com");
            break;
        }

        case WM_SIZE: {
            int width = LOWORD(lp);
            int height = HIWORD(lp);

            // Dynamically adjust elements relative to window resizes
            MoveWindow(hEditInput, 10, 10, width - 90, 25, TRUE);
            MoveWindow(hBtnGo, width - 70, 10, 60, 25, TRUE);

            // Adjust webview widget window boundary below the controls
            HWND hWebviewWindow = (HWND)webview_get_window(g_webview);
            MoveWindow(hWebviewWindow, 0, 45, width, height - 45, TRUE);
            break;
        }

        case WM_COMMAND: {
            if (LOWORD(wp) == IDC_GO_BUTTON) {
                NavigateToInputUrl();
            }
            break;
        }

        case WM_DESTROY:
            if (g_webview) {
                webview_destroy(g_webview);
            }
            PostQuitMessage(0);
            break;

        default:
            return DefWindowProcW(hWnd, msg, wp, lp);
    }
    return 0;
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int nCmdShow) {
    WNDCLASSEXW wc = { sizeof(WNDCLASSEXW), CS_HREDRAW | CS_VREDRAW, WndProc, 0, 0,
                       hInst, NULL, LoadCursor(NULL, IDC_ARROW), (HBRUSH)(COLOR_WINDOW+1),
                       NULL, L"WebviewContainerClass", NULL };
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(0, L"WebviewContainerClass", L"Webview Browser Window",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 800, 600,
        NULL, NULL, hInst, NULL);

    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);

    // Keep the main process loop alive; webview shares this execution loop thread natively
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return (int)msg.wParam;
}
