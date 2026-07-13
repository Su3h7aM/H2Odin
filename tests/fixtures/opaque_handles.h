/* Incomplete-record handles vs void* vs a shared record. */

typedef struct Opaque_A_Impl *Opaque_A;
typedef struct Opaque_B_Impl *Opaque_B;

/* Two typedefs of the same incomplete record — mutually assignable in C. */
typedef struct Shared_Impl *Shared_Handle;
typedef struct Shared_Impl *Shared_Alias;

/* void* stays plain rawptr unless types.distinct opts in. */
typedef void *Void_Handle;
typedef void *Void_Plain;

/* Complete record: pointer typedef stays a true pointer, not distinct rawptr. */
typedef struct Complete_Rec {
	int x;
} *Complete_Ptr;

void take_handles(Opaque_A a, Opaque_B b, Shared_Handle s, Shared_Alias sa,
                  Void_Handle vh, Void_Plain vp, Complete_Ptr cp);
