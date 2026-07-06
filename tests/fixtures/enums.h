enum Color { RED, GREEN = 5, BLUE };

enum Flags { F_READ = 1, F_WRITE = 2, F_RW = 3 };

enum { ANON_A = 10, ANON_B };

enum Level { L_DEBUG = -1, L_INFO = 0 };

void paint(enum Color color, int strength);
enum Color next_color(enum Color current);
