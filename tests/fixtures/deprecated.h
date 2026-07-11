/* Fixture for spec 0009 — deprecated C declarations. */

__attribute__((deprecated("use new_fn instead")))
void old_fn(void);

struct __attribute__((deprecated("use New_Type instead"))) Old_Type {
	int x;
};

__attribute__((deprecated("use new_var instead")))
extern int old_var;

/* Anonymous enum → Odin constants; attribute on the enum marks them. */
enum __attribute__((deprecated("use NEW_CONST instead"))) {
	OLD_CONST = 42
};

/* Attribute without a message → fixed fallback text. */
__attribute__((deprecated))
void bare_deprecated_fn(void);

void live_fn(void);
