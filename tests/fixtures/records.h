struct Node {
	struct Node *next;
	int value;
};

struct Point { float x, y; };

union Value { int i; float f; unsigned char bytes[4]; };

struct Opaque;

struct Packed { char tag; int payload; } __attribute__((packed));

struct HasBits { int a : 3; int b; };

struct WithAnon {
	union { int i; float f; };
	int tag;
};

struct Outer {
	struct Inner { int x; } inner;
};

void take(struct Node *n, struct Point p, struct Opaque *o);
