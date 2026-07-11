#include <stdio.h>

/* FILE is a system type the built-in map does not know, used only behind a
 * pointer: it becomes an incomplete stub, never a copied system layout. */
struct log_sink {
	int level;
	FILE *stream;
};

int log_write(struct log_sink *sink, const char *msg);
