/* High-bit values force an unsigned enum backing on common ABIs.
 * Signed-only capture would store UF_ALL as -1 instead of 0xFFFFFFFF. */
enum Unsigned_Flags {
	UF_NONE = 0u,
	UF_HIGH = 0x80000000u,
	UF_ALL  = 0xFFFFFFFFu,
};

enum Signed_Flags {
	SF_NONE = 0,
	SF_NEG  = -1,
};
