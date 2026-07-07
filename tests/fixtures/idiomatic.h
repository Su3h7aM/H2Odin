/* Exercises every rung of idiomatic mode's leaf-substitution ladder. */

#include <stdint.h>
#include <stddef.h>

/** Rung 1, table preference: fixed-width stdint typedefs substitute by a
 * table row confirmed against the measured size. */
uint32_t checksum(const void *data, uint64_t nbytes);

/** Rung 1, table preference: long/unsigned long substitute via their table
 * row where the measured size on this target (8 bytes) confirms it. */
long ticks(void);
unsigned long uticks(void);

/** Rung 1 for both: size_t prefers uint, and plain char prefers u8 to stay
 * ABI-compatible with core:c.char, regardless of the true per-target
 * signedness libclang measures for it. */
size_t payload_len(char tag);

/** Enum backing types substitute with the same ladder. */
enum Mode { MODE_OFF = 0, MODE_ON = 1 };
enum Mode get_mode(void);
