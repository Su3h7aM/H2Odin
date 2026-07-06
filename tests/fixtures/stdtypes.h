#include <stdint.h>
#include <stddef.h>

typedef uint32_t Id;

struct Blob {
	uint8_t *data;
	size_t len;
	int64_t created_at;
};

size_t blob_size(const struct Blob *b);
uint64_t hash_bytes(const uint8_t *bytes, size_t n);
void set_id(Id id);
