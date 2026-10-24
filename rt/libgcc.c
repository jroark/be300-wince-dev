/*
 * clang emits libgcc-named helpers for soft-float and 64-bit division.
 * COREDLL exports Microsoft's equivalents for the MIPS compiler; forward to
 * them. Values cross as raw bits (doubles in an a0/a1 pair, floats in one
 * register), which is the same o32 soft-float convention on both sides.
 */
typedef unsigned int u32;
typedef unsigned long long u64;
typedef long long s64;

#define D2(name, ms) extern u64 ms(u64, u64); u64 name(u64 a, u64 b) { return ms(a, b); }
#define F2(name, ms) extern u32 ms(u32, u32); u32 name(u32 a, u32 b) { return ms(a, b); }

D2(__adddf3, __dpadd)
D2(__subdf3, __dpsub)
D2(__muldf3, __dpmul)
D2(__divdf3, __dpdiv)
F2(__addsf3, __fpadd)
F2(__subsf3, __fpsub)
F2(__mulsf3, __fpmul)
F2(__divsf3, __fpdiv)

/* Comparisons: MS helpers return a C boolean; libgcc's return a value
   the caller tests against zero. NaN must make every ordered test false. */
extern int __eqd(u64, u64), __ned(u64, u64), __ltd(u64, u64);
extern int __led(u64, u64), __gtd(u64, u64), __ged(u64, u64);
extern int __eqs(u32, u32), __nes(u32, u32), __lts(u32, u32);
extern int __les(u32, u32), __gts(u32, u32), __ges(u32, u32);

static int nan_d(u64 a) { return ((a >> 52) & 0x7FF) == 0x7FF && (a & 0xFFFFFFFFFFFFFull); }
static int nan_f(u32 a) { return ((a >> 23) & 0xFF) == 0xFF && (a & 0x7FFFFF); }

int __eqdf2(u64 a, u64 b) { return __eqd(a, b) ? 0 : 1; }
int __nedf2(u64 a, u64 b) { return __ned(a, b) ? 1 : 0; }
int __ltdf2(u64 a, u64 b) { return __ltd(a, b) ? -1 : 1; }
int __ledf2(u64 a, u64 b) { return __led(a, b) ? 0 : 1; }
int __gtdf2(u64 a, u64 b) { return __gtd(a, b) ? 1 : -1; }
int __gedf2(u64 a, u64 b) { return __ged(a, b) ? 0 : -1; }
int __unorddf2(u64 a, u64 b) { return nan_d(a) || nan_d(b); }
int __eqsf2(u32 a, u32 b) { return __eqs(a, b) ? 0 : 1; }
int __nesf2(u32 a, u32 b) { return __nes(a, b) ? 1 : 0; }
int __ltsf2(u32 a, u32 b) { return __lts(a, b) ? -1 : 1; }
int __lesf2(u32 a, u32 b) { return __les(a, b) ? 0 : 1; }
int __gtsf2(u32 a, u32 b) { return __gts(a, b) ? 1 : -1; }
int __gesf2(u32 a, u32 b) { return __ges(a, b) ? 0 : -1; }
int __unordsf2(u32 a, u32 b) { return nan_f(a) || nan_f(b); }

/* Conversions */
extern u64 __litodp(int), __ultodp(u32), __fptodp(u32), __ll_to_d(s64), __ull_to_d(u64);
extern u32 __litofp(int), __ultofp(u32), __dptofp(u64), __ll_to_f(s64), __ull_to_f(u64);
extern int __dptoli(u64), __fptoli(u32);
extern u32 __dptoul(u64), __fptoul(u32);
extern s64 __d_to_ll(u64), __f_to_ll(u32);
extern u64 __d_to_ull(u64), __f_to_ull(u32);

u64 __floatsidf(int a) { return __litodp(a); }
u64 __floatunsidf(u32 a) { return __ultodp(a); }
u64 __floatdidf(s64 a) { return __ll_to_d(a); }
u64 __floatundidf(u64 a) { return __ull_to_d(a); }
u64 __extendsfdf2(u32 a) { return __fptodp(a); }
u32 __floatsisf(int a) { return __litofp(a); }
u32 __floatunsisf(u32 a) { return __ultofp(a); }
u32 __floatdisf(s64 a) { return __ll_to_f(a); }
u32 __floatundisf(u64 a) { return __ull_to_f(a); }
u32 __truncdfsf2(u64 a) { return __dptofp(a); }
int __fixdfsi(u64 a) { return __dptoli(a); }
u32 __fixunsdfsi(u64 a) { return __dptoul(a); }
s64 __fixdfdi(u64 a) { return __d_to_ll(a); }
u64 __fixunsdfdi(u64 a) { return __d_to_ull(a); }
int __fixsfsi(u32 a) { return __fptoli(a); }
u32 __fixunssfsi(u32 a) { return __fptoul(a); }
s64 __fixsfdi(u32 a) { return __f_to_ll(a); }
u64 __fixunssfdi(u32 a) { return __f_to_ull(a); }

/* 64-bit integer division */
extern s64 __ll_div(s64, s64), __ll_rem(s64, s64);
extern u64 __ull_div(u64, u64), __ull_rem(u64, u64);

s64 __divdi3(s64 a, s64 b) { return __ll_div(a, b); }
s64 __moddi3(s64 a, s64 b) { return __ll_rem(a, b); }
u64 __udivdi3(u64 a, u64 b) { return __ull_div(a, b); }
u64 __umoddi3(u64 a, u64 b) { return __ull_rem(a, b); }
