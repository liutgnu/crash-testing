#ifndef _ARCH_X86_H_
#define _ARCH_X86_H_
void find_and_replace(void *start, void *end, void *target, void *replacement);
void fill_trampoline_to_wrapper(void *reserved_trampoline_addr);
#endif