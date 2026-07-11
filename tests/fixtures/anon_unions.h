/* Two C11 anonymous unions in one struct — libclang shares their USR. */
typedef struct Children {
	int a;
	int b;
} Children;

typedef struct Node {
	int x;
	union {
		Children children;
		unsigned long long userData;
	};
	union {
		int parent;
		int next;
	};
	short height;
} Node;
