#include <sys/types.h>
#include <stddef.h>
#include <time.h>

/* POSIX/libc named types keep one spelling in both type modes;
 * ISO C size_t stays on the c.size_t / uint ladder. */
off_t  lib_seek(int fd, off_t offset);
pid_t  lib_owner(void);
time_t lib_mtime(time_t *out);
size_t lib_len(const char *s);
