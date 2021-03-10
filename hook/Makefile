CC = gcc

ARCH := $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

CFLAGS =-O2 -D${ARCH} -fpic -shared
LDFLAGS = -ldl
OUTPUT = hook_error.so

SOURCES := hook_error.c
ifeq (${ARCH}, x86_64)
SOURCES += x86_64/arch_x64.c
else ifeq (${ARCH}, i386)
SOURCES += x86/arch_x86.c
endif


all: ${SOURCES}
	@${CC} ${CFLAGS} -o ${OUTPUT} ${SOURCES} ${LDFLAGS}
clean:
	find ./ -regextype posix-extended -regex ".*\.(o|so|out)" | xargs rm -f
