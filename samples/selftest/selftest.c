/*
 * Exercises the code paths the toolchain has to get right: 64-bit
 * division and soft-float helpers forwarded to COREDLL, data/bss
 * relocations, jump tables, function pointers and struct copies.
 * Results go to \Nand Disk\selftest.log and the debug serial port.
 */
#include <windows.h>

static HANDLE g_log;
static int g_fail, g_pass;
static int g_bss[64];
static int g_data[4] = { 11, 22, 33, 44 };
struct big { int v[40]; };

static void out(const WCHAR *s)
{
    char buf[256];
    DWORD n, w;

    OutputDebugStringW(s);
    n = WideCharToMultiByte(CP_ACP, 0, s, -1, buf, sizeof(buf), NULL, NULL);
    if (g_log != INVALID_HANDLE_VALUE && n > 0)
        WriteFile(g_log, buf, n - 1, &w, NULL);
}

static void check(const WCHAR *what, long long got, long long want)
{
    WCHAR line[160];

    if (got == want)
        g_pass++;
    else
        g_fail++;
    wsprintfW(line, L"%s %s got=%d:%u want=%d:%u\r\n", got == want ? L"PASS" : L"FAIL",
              what, (int)(got >> 32), (unsigned)got, (int)(want >> 32), (unsigned)want);
    out(line);
}

/* volatile operands keep clang from folding everything at compile time */
static volatile long long vs64a = -1234567890123LL, vs64b = 1000;
static volatile unsigned long long vu64a = 0xFEDCBA9876543210ULL, vu64b = 0x12345;
static volatile double vda = 2.5, vdb = -0.75, vnan;
static volatile float vfa = 3.0f, vfb = 0.5f;
static volatile int vi = -7;
static volatile unsigned vu = 3000000000u;

static int pick(int k)
{
    switch (k) {
    case 0: return 100;
    case 1: return 201;
    case 2: return 302;
    case 3: return 403;
    case 4: return 504;
    case 5: return 605;
    case 6: return 706;
    default: return -1;
    }
}

static int add1(int x) { return x + 1; }
static int dbl(int x) { return x * 2; }
static int (*const g_ops[])(int) = { add1, dbl };

/* A variadic function of our own: va_start must find the register arguments
 * clang spilled (tools/include/be300-fixups.h). */
static long long vsum(int n, ...)
{
    va_list ap;
    long long t = 0;
    int i;

    va_start(ap, n);
    for (i = 0; i < n; i++)
        t += i == 3 ? va_arg(ap, long long) : va_arg(ap, int);
    va_end(ap);
    return t;
}

static int vfmt(WCHAR *buf, const WCHAR *fmt, ...)
{
    va_list ap;
    int n;

    va_start(ap, fmt);
    n = wvsprintfW(buf, fmt, ap);
    va_end(ap);
    return n;
}

static struct big make_big(int seed)
{
    struct big b;
    int i;
    for (i = 0; i < 40; i++)
        b.v[i] = seed + i;
    return b;
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPWSTR cmd, int show)
{
    struct big b;
    double d;
    float f;
    WCHAR line[96];
    int i, sum = 0;

    g_log = CreateFileW(L"\\Nand Disk\\selftest.log", GENERIC_WRITE, 0, NULL,
                        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    out(L"SELFTEST BEGIN\r\n");

    check(L"s64 div", vs64a / vs64b, -1234567890LL);
    check(L"s64 mod", vs64a % vs64b, -123LL);
    check(L"u64 div", (long long)(vu64a / vu64b), (long long)(0xFEDCBA9876543210ULL / 0x12345));
    check(L"u64 mod", (long long)(vu64a % vu64b), (long long)(0xFEDCBA9876543210ULL % 0x12345));

    d = vda * vdb + 1.0;                        /* -0.875 */
    check(L"dbl mul/add", (long long)(d * 1000.0), -875);
    check(L"dbl div", (long long)(vda / vdb * 1000.0), -3333);
    check(L"dbl sub", (long long)((vda - vdb) * 100.0), 325);
    check(L"dbl lt", vdb < vda, 1);
    check(L"dbl gt", vdb > vda, 0);
    check(L"dbl le", vda <= vda, 1);
    check(L"dbl ge", vdb >= vda, 0);
    check(L"dbl eq", vda == 2.5, 1);
    check(L"dbl ne", vda != 2.5, 0);
    vnan = 0.0;
    vnan = vnan / vnan;
    check(L"dbl nan lt", vnan < vda, 0);
    check(L"dbl nan ne", vnan != vnan, 1);
    check(L"int->dbl->int", (long long)(int)((double)vi * 1.5), -10);
    check(L"uint->dbl", (long long)((double)vu), 3000000000LL);
    check(L"dbl->s64", (long long)(vda * 1e12), 2500000000000LL);
    check(L"s64->dbl", (long long)((double)vs64a / 1000.0), -1234567890LL);

    f = vfa * vfb - 0.25f;                      /* 1.25 */
    check(L"flt mul/sub", (long long)(f * 100.0f), 125);
    check(L"flt div", (long long)(vfa / vfb), 6);
    check(L"flt lt", vfb < vfa, 1);
    check(L"flt->dbl", (long long)((double)vfb * 10.0), 5);
    check(L"dbl->flt", (long long)((float)vda * 2.0f), 5);

    for (i = 0; i < 8; i++)
        sum += pick(i);
    check(L"switch table", sum, 2820);   /* includes default: -1 */
    check(L"fn ptrs", g_ops[1](g_ops[0](20)), 42);
    for (i = 0; i < 64; i++)
        sum += g_bss[i];
    check(L"bss zero", sum, 2820);
    check(L"data init", g_data[0] + g_data[3], 55);
    b = make_big(5);
    check(L"struct copy", b.v[0] + b.v[39], 49);

    check(L"varargs", vsum(5, 1, 20, 300, 4000000000000LL, 50000), 4000000050321LL);
    vfmt(line, L"%d-%s-%u", 7, L"ok", 9u);
    check(L"varargs fmt", lstrcmpW(line, L"7-ok-9"), 0);

    wsprintfW(line, L"SELFTEST END pass=%d fail=%d\r\n", g_pass, g_fail);
    out(line);
    if (g_log != INVALID_HANDLE_VALUE)
        CloseHandle(g_log);
    return g_fail;
}
