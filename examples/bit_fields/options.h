typedef struct Example_Options {
	unsigned Size;
	unsigned char IndexPriority;
	unsigned char EditPriority;
	unsigned Enabled : 1;
	unsigned Verbose : 1;
	unsigned InMemory : 1;
	unsigned : 13;
	void *UserData;
} Example_Options;
