/*
 * Minimal BE-300 GUI app: a full-screen window that paints a greeting.
 * Tap anywhere to exit. Also leaves \Nand Disk\hello.log behind so a
 * scripted run can confirm the app executed.
 */
#include <windows.h>
#include "resource.h"

static const WCHAR kClass[] = L"HelloBE300";

/* The first call of a run truncates the log; later calls append. */
static void write_log(const WCHAR *text)
{
    static BOOL started;
    HANDLE f = CreateFileW(L"\\Nand Disk\\hello.log", GENERIC_WRITE, 0, NULL,
                           started ? OPEN_ALWAYS : CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL, NULL);
    char buf[128];
    DWORD n, written;

    if (f == INVALID_HANDLE_VALUE)
        return;
    started = TRUE;
    SetFilePointer(f, 0, NULL, FILE_END);
    n = WideCharToMultiByte(CP_ACP, 0, text, -1, buf, sizeof(buf), NULL, NULL);
    if (n > 0)
        WriteFile(f, buf, n - 1, &written, NULL);
    CloseHandle(f);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        RECT rc;
        HDC dc = BeginPaint(hwnd, &ps);
        GetClientRect(hwnd, &rc);
        rc.bottom = rc.bottom / 2;
        DrawTextW(dc, L"Hello from clang on macOS!", -1, &rc,
                  DT_CENTER | DT_BOTTOM | DT_SINGLELINE);
        rc.top = rc.bottom + 16;
        rc.bottom = rc.top + 40;
        DrawTextW(dc, L"Tap to exit.", -1, &rc, DT_CENTER | DT_TOP | DT_SINGLELINE);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_LBUTTONDOWN:
        DestroyWindow(hwnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPWSTR cmd, int show)
{
    WNDCLASSW wc = {0};
    HWND hwnd;
    MSG msg;

    OutputDebugStringW(L"Hello: started\r\n");
    write_log(L"hello: WinMain reached\r\n");

    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.hIcon = LoadIconW(inst, MAKEINTRESOURCEW(IDI_HELLO));
    wc.hCursor = NULL;
    wc.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
    wc.lpszClassName = kClass;
    if (!RegisterClassW(&wc))
        return 1;

    hwnd = CreateWindowW(kClass, L"Hello", WS_VISIBLE, 0, 0,
                         GetSystemMetrics(SM_CXSCREEN),
                         GetSystemMetrics(SM_CYSCREEN),
                         NULL, NULL, inst, NULL);
    if (!hwnd)
        return 1;
    write_log(L"hello: window created\r\n");
    ShowWindow(hwnd, show);
    UpdateWindow(hwnd);

    while (GetMessageW(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return (int)msg.wParam;
}
