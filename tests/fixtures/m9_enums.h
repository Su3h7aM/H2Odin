enum Config_Flag {
	FLAG_VSYNC = 1,
	FLAG_FULLSCREEN = 2,
	FLAG_MSAA = 4,
	FLAG_COUNT = 8,
};

enum {
	KEY_NULL = 0,
	KEY_A = 1,
	KEY_B = 2,
};

void set_flags(enum Config_Flag flags);
