struct BoneInfo {
	char name[32];
	int parent;
};

struct Mesh {
	int vertexCount;
	float *vertices;
};

typedef enum {
	FLAG_VSYNC = 1,
	FLAG_FULLSCREEN = 2,
} ConfigFlags;

void SetConfigFlags(unsigned int flags);
int GetKeyPressed(void);
void DrawTexturePro(int tint);
