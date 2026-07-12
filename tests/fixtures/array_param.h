/* Array-form parameters decay to pointers; H2Odin should emit [^]T. */

void fill_buf(int buf[16], int n);
void flex(int items[], int count);
/* Bare pointer stays ^T unless configured multi. */
void bare(int *p);
