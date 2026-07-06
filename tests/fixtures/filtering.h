/* Exercises the keep callback: internal_* declarations get dropped. */

#define VERSION 3
#define internal_BUILD 99

struct Point {
	int x;
	int y;
};

struct internal_state {
	int refcount;
};

int distance(struct Point a, struct Point b);
int internal_reset(void);

extern int visible_count;
extern int internal_count;
