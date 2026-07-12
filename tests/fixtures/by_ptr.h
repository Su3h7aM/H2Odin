typedef struct Options {
	int flags;
} Options;

/* Call-borrowed const pointer — candidates for #by_ptr under explicit policy. */
int create(const Options *options);
void bare(int *p);
