#include <stdint.h>
#include <sys/types.h>
#include <string.h>

/*
 * This is the template of trampoline, we will copy it
 * to heap and execute there.
 * The trampoline code:
 *       push $addr   # 5 bytes
 *       ret          # 1 byte
*/
asm (
        "trampoline_template:\n\t"
        ".byte 0x68\n\t"
        ".word 0x0\n\t"
        ".word 0x0\n\t"
        ".byte 0xc3\n\t"
);
#define TRAMPOLINE_SIZE (2 + sizeof(void *))

/*
 * Each time when crash calls __error, it will first goto here.
 * Then we call our custom_error, finally jump to the original __error.
 * NOTE: we shouldn't mess up stack before jmp __error.
*/
asm (
        "wrapper_error:\n\t"
        "call custom_error\n\t"
        "jmp __error\n\t"
);

/*
 * This function is used to find all target function call instructions
 * in the start-end range, then modify these instructions to call to the
 * replacement function.
 * 
 * In x86 systems, call function is 0xe8 xx xx xx xx.
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
        /*
         * The following code is to position-indepentently get the address
         * of trampoline template and wrapper_error.
        */
        __asm__ volatile (
                "call _get_pc_\n\t"
                "addl $_GLOBAL_OFFSET_TABLE_, %1\n\t"
                "leal trampoline_template@GOTOFF(%1), %0\n\t"
                "call _get_pc_\n\t"
                "addl $_GLOBAL_OFFSET_TABLE_, %1\n\t"
                "leal wrapper_error@GOTOFF(%1), %1\n\t"
                "jmp 1f\n\t"
                "_get_pc_: movl (%%esp), %1\n\t"
                "ret\n\t"
                "1:\n\t"
                :"=r"(trampoline_addr), "=r"(wrapper_error_addr));
        memcpy(reserved_trampoline_addr, trampoline_addr, TRAMPOLINE_SIZE);
        *(u_int32_t *)(reserved_trampoline_addr + 1) = (u_int32_t)wrapper_error_addr;
}