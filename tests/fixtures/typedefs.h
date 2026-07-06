typedef int MyInt;
typedef unsigned long size_type;

typedef struct Vec2 { float x, y; } Vec2;

typedef struct { int id; } Handle;

typedef enum { OK, ERR } Status;

typedef struct Big Big;

typedef MyInt *IntPtr;

typedef void (*Callback)(int event, void *user);

typedef struct Vec2 Position;

void use(Vec2 v, Handle h, Status s, IntPtr p, Callback cb, Big *big, Position pos, MyInt m, size_type n);
