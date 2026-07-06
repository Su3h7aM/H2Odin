void fill(int *out, const char *name, unsigned char buf[16], float m[2][2]);
int log_fmt(const char *fmt, ...);
void on_event(void (*cb)(int code, void *user), void *user);
double *make_row(long n);
int **indirect(int **pp);
