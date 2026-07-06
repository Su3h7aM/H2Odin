typedef struct Conn Conn;
typedef void (*Callback)(void *, int);

int close_conn(Conn *);
int config(int, ...);
void trace(Conn *, Callback callback, void *);
int bind_blob(Conn *, int, void *, int n, void (*destroy)(void *));
