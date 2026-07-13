/* Calling-convention facts for Extraction and Emission. */

void plain_c(void);

/* Explicit C. On most targets this is what Default also resolves to. */
void explicit_c(void) __attribute__((cdecl));

/* Microsoft-style stdcall — reported by libclang when the attribute sticks. */
void stdcall_fn(void) __attribute__((stdcall));

/* Microsoft-style fastcall. */
void fastcall_fn(void) __attribute__((fastcall));

/* vectorcall is captured in the IR but has no Odin spelling (error diagnostic). */
void vectorcall_fn(void) __attribute__((vectorcall));

/* Callback typedefs: convention lives on the procedure type, not the pointer. */
typedef void (*Stdcall_Cb)(void) __attribute__((stdcall));
typedef void (*Fastcall_Cb)(void) __attribute__((fastcall));
typedef void (*C_Cb)(void);

void takes_stdcall_cb(Stdcall_Cb cb);
void takes_fastcall_cb(Fastcall_Cb cb);
void takes_c_cb(C_Cb cb);
