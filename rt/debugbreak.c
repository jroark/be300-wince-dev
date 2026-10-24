/* kfuncs.h declares DebugBreak as an intrinsic; provide it out of line. */
void DebugBreak(void)
{
    __asm__ volatile("break 1");
}
