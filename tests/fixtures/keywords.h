/* C names that collide with Odin keywords: every one is legal C, none is
 * legal Odin. Each gets the deterministic underscore-suffix default; the
 * functions and variables keep their C symbol via link_name. */

extern float matrix[16];

struct map {
	int context;
	int in;
};

int distinct(struct map *ptr, int in);

enum defer {
	when = 1,
	force = 2,
};

#define transmute 7
