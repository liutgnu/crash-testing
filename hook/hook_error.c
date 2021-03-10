#include <stdio.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <errno.h>
#include <malloc.h>
#include <stdint.h>
#include "crash_constants.h"

#ifdef x86_64
#include "x86_64/arch_x64.h"
#elif defined i386
//#include "x86/arch_x86.h"
#endif

#define true 1
#define false 0

/*
 * The string we will be used for log filtering.
*/
const char *error_flag_string = "<<<-->>>";

static void print_line_within_buffer(char *buf)
{
        char *line = strtok(buf, "\n");
        while(line) {
                printf("%s %s\n", error_flag_string, line);
                line = strtok(NULL, "\n");
        }

}

char *get_log_type(int type)
{
        switch (type) {
                case INFO: return "INFO";
                case FATAL: return "FATAL";
                case FATAL_RESTART: return "FATAL_RESTART";
                case WARNING: return "WARNING";
                case NOTE: return "NOTE";
                case CONT: return "CONT";
                default: return "OTHER";
        }
}

/*
 * The less quantity of parameters, the better. IT'S HACKING...
 * 
 * Because we are called from wrapper_error, and will JUMP(not call) to 
 * __error later, thus we mustn't mess up the registers and stack 
 * which originally belongs to __error.
 * 
 * If all paramters passing to __error are through stack, then we
 * don't need to save any registers, custom_error will be free to access
 * all parameters. Eg: i386 arch.
 * 
 * But if some parameters are through stack, some are through registers, 
 * we must save these registers to stack, but it will CHANGED stack! 
 * So in custom_error we CANNOT have access to the paramters which are passed 
 * through stack, only passed through resigters. Eg: x86_64 arch.
 * 
 * For better arch compatibility, we cannot assume the how many parameters
 * we can have access to, just take the least.
*/
void custom_error(int type)
{
        printf("%s%s", get_log_type(type), error_flag_string);
}

/*
 * The main entry of .so 
*/
__attribute__((constructor))
static void ctor(void) {
        char path_buf[1024];
        char exe_path_buf[1024];
        FILE *fp = NULL;
        char *line = NULL;
        size_t len = 0;
        void *start = NULL;
        void *end = NULL;
        void *trampoline = NULL;
        void *__error_addr = NULL;
        void *main_program = NULL;
        int should_fail = false;
        int page_size = getpagesize();

        memset(exe_path_buf, 0, sizeof(exe_path_buf));
        main_program = dlopen(NULL, RTLD_NOW);
        if (!main_program) {
                fprintf(stderr, "dlopen main program error!\n");
                should_fail = true;
                goto out;
        }

        __error_addr = dlsym(main_program , "__error");
        if (!__error_addr) {
                should_fail = false;
                goto out;
        }

        pid_t pid = getpid();
        snprintf(path_buf, sizeof(path_buf), "/proc/%d/exe", pid);
        if (readlink(path_buf, exe_path_buf, sizeof(exe_path_buf)) < 0) {
                fprintf(stderr, "Readlink /proc/%d/exe error!\n", pid);
                should_fail = true;
                goto out;
        }

        snprintf(path_buf, sizeof(path_buf), "/proc/%d/maps", pid);
        fp = fopen(path_buf, "r");
        if (!fp) {
                fprintf(stderr, "Open /proc/%d/maps error!\n", pid);
                should_fail = true;
                goto out;
        }
        while (getline(&line, &len, fp) >= 0) {
                /* The lines relate to the main program will have substring of 
                 * its exe path.
                */
                if (strstr(line, exe_path_buf) > 0 &&
                   // The line about text segment will have r-xp.
                   strstr(line, "r-xp") > 0) {
                        break;
                }
        }
        /* Now we get the text segment's start and end address of the main
         * program.
        */ 
        sscanf(line, "%p-%p", &start, &end);

        if (!start || !end) {
                fprintf(stderr, "Read address error!\n");
                should_fail = true;
                goto out;
        }
        // Allocate a page from heap to hold the trampoline.
        trampoline = memalign(page_size, 1 * page_size);
        if (!trampoline) {
                fprintf(stderr, "Read address error!\n");
                should_fail = true;
                goto out;               
        }

        fill_trampoline_to_wrapper(trampoline);

        // Make the trampoline executable.
        if (mprotect(trampoline, 1 * page_size, PROT_READ|PROT_WRITE|PROT_EXEC)) {
                fprintf(stderr, "mprotect trampoline error: %s\n", strerror(errno));
                should_fail = true;
                goto out;
        }

        // Make the text segment of main program writable. 
        if (mprotect(start, end - start, PROT_READ|PROT_WRITE|PROT_EXEC)) {
                fprintf(stderr, "mprotect main program error: %s\n", strerror(errno));
                should_fail = true;
                goto out;
        }
        /* Make all calls to __error function redirect to trampoline.
         * The trampoline will then jump to the wapper_error later.
        */
        find_and_replace(start, end, __error_addr, trampoline);
        // Restore the attribute.
        if (mprotect(start, end - start, PROT_READ|PROT_EXEC)) {
                fprintf(stderr, "mprotect main program error: %s\n", strerror(errno));
                should_fail = true;
                goto out;
        }

out:    
        if (main_program)
                dlclose(main_program);
        if (fp)
                fclose(fp);
        if (line)
                free(line);
        if (should_fail)
                exit(1);
        else
                return;
}
