/* Calling-convention facts for Extraction (Milestone 15 P1). */

void plain_c(void);

/* Explicit C. On most targets this is what Default also resolves to. */
void explicit_c(void) __attribute__((cdecl));

/* Microsoft-style stdcall — reported by libclang when the attribute sticks. */
void stdcall_fn(void) __attribute__((stdcall));
