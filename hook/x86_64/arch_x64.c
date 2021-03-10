#include <stdint.h>
#include <sys/types.h>
#include <string.h>
#include <stdarg.h>
#include "../crash_constants.h"
#include <stdio.h>

/*
 * This is the template of trampoline, we will copy it
 * to heap and execute there.
*/
asm (
        "trampoline_template:\n\t"
        "jmpq *(%rip)\n\t" 
        ".word 0x0\n\t"
        ".word 0x0\n\t"
        ".word 0x0\n\t"
        ".word 0x0\n\t"
);
#define JMPQ_SIZE 6
#define TRAMPOLINE_SIZE (JMPQ_SIZE + sizeof(void *))

/*
 * Each time when crash calls __error, it will first goto here.
 * Then we call our custom_error, finally jump to the original __error.
 * NOTE: we shouldn't mess up stack AND registers which holding arguments
 * before jmp __error.
*/
asm (
        "wrapper_error:\n\t"
        "pushq %rdi\n\t"
        "pushq %rsi\n\t"
        "pushq %rdx\n\t"
        "pushq %rcx\n\t"
        "pushq %r8\n\t"
        "pushq %r9\n\t"

        "call custom_error\n\t"

        "popq %r9\n\t"
        "popq %r8\n\t"
        "popq %rcx\n\t"
        "popq %rdx\n\t"
        "popq %rsi\n\t"
        "popq %rdi\n\t"
        "jmp __error\n\t"
);


/*
 * This function is used to find all target function call instructions
 * in the start-end range, then modify these instructions to call to the
 * replacement function.
 * 
 * In x86_64 systems, call function is 0xe8 xx xx xx xx.
 * 0xe8 represents the call opcode. xx xx xx xx represents the
 * offset of calling function. 5 is the call instruction length.
 * The formula: 
 * <current call instruction addr> + 5 + offset = <the called function addr>
*/
void find_and_replace(void *start, void *end, void *target, void *replacement)
{
        u_int8_t *p;
        for (p = start; (void *)p < end; p++) {
                if (*p == 0xe8) {
                        if (*(int32_t *)(p + 1) + p + 5 == target) {
                                *(int32_t *)(p + 1) = (int32_t)((u_int8_t *)replacement - 5 - p);
                        } else {
                                continue;
                        }
                }
        }
}

/*
 * This function copies the asm trampoline code to reserved_trampoline_addr,
 * then fill the wrapper_error address in trampoline.
*/
void fill_trampoline_to_wrapper(void *reserved_trampoline_addr)
{
        void *trampoline_addr;
        void *wrapper_error_addr;
        __asm__ volatile ("leaq trampoline_template(%%rip), %0\n\t":"=r"(trampoline_addr));
        __asm__ volatile ("leaq wrapper_error(%%rip), %0\n\t":"=r"(wrapper_error_addr));
        memcpy(reserved_trampoline_addr, trampoline_addr, TRAMPOLINE_SIZE);
        *(u_int64_t *)(reserved_trampoline_addr + JMPQ_SIZE) = (u_int64_t)wrapper_error_addr;
}