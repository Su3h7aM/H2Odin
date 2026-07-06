extern int global_counter;
extern const char *app_name;
extern float world_matrix[16];
extern int unknown_size[];

static int internal_state = 0;
static void helper(void) {}

struct Config { int verbosity; };
extern struct Config default_config;

int get_counter(void);
