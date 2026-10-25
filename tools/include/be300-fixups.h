/*
 * Forced into every compile by be300-cc, ahead of the source.
 *
 * The SDK's STDLIB.H (which its stdarg.h includes) defines va_start for MIPS
 * as the address just past the last named parameter. That relies on
 * Microsoft's compiler homing the register arguments beside it; clang
 * spills them into the caller's argument area instead, so a variadic
 * function of the app's own read garbage. The builtins follow clang's frame.
 * clang's o32 __builtin_va_list is char *, the SDK's va_list, so prototypes
 * such as wvsprintfW's still match. STDLIB.H is guarded, so later includes
 * leave these alone.
 */
#pragma clang system_header
#include <stdlib.h>
#undef va_start
#undef va_arg
#undef va_end
#define va_start(ap, v) __builtin_va_start(ap, v)
#define va_arg(ap, t)   __builtin_va_arg(ap, t)
#define va_end(ap)      __builtin_va_end(ap)
#define va_copy(d, s)   __builtin_va_copy(d, s)
