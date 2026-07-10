typedef struct H2O_IndexOptions {
	unsigned Size;
	unsigned char ThreadBackgroundPriorityForIndexing;
	unsigned char ThreadBackgroundPriorityForEditing;
	unsigned ExcludeDeclarationsFromPCH : 1;
	unsigned DisplayDiagnostics : 1;
	unsigned StorePreamblesInMemory : 1;
	unsigned : 13;
	const char *PreambleStoragePath;
	const char *InvocationEmissionPath;
} H2O_IndexOptions;

typedef struct H2O_Plain {
	int x;
	unsigned char y;
} H2O_Plain;

typedef union H2O_Overlapping {
	int *pointer;
	unsigned flag : 1;
} H2O_Overlapping;
