/* Exercises every leaf-substitution proof path in idiomatic mode. */

#include <stdint.h>
#include <stddef.h>

/** Target-independent rows: substitute by construction. */
uint32_t checksum(const void *data, uint64_t nbytes);

/** Size-proven rows: long substitutes only where libclang measured it
 * at the Odin type's size (8 bytes on this target). */
long ticks(void);
unsigned long uticks(void);

/** Unproven rows keep the ABI spelling: size_t is pointer-width, and
 * plain char has no idiomatic form (implementation-defined signedness). */
size_t payload_len(char tag);

/** Enum backing types substitute with the same proof. */
enum Mode { MODE_OFF = 0, MODE_ON = 1 };
enum Mode get_mode(void);
