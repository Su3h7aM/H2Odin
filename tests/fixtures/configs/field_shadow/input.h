/* Field named like a package type, with a second use of that type → Odin cycle. */
typedef enum { FMT_A, FMT_B } ma_format;

struct ma_device {
	ma_format format;
	ma_format internalFormat;
};
