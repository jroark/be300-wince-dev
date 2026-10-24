/*
 * Process entry for BE-300 executables. The WinCE loader calls the image
 * entry point with WinMain's arguments and ends the process when it
 * returns, so all this does is forward to WinMain.
 */
#include <windows.h>

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPWSTR, int);

int WINAPI WinMainCRTStartup(HINSTANCE inst, HINSTANCE prev, LPWSTR cmd, int show)
{
    return WinMain(inst, prev, cmd, show);
}
