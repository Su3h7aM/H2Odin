/* Spec 0007: incomplete tag typedef used as T* / T**. */

typedef struct Opaque_Tag Opaque_Tag;
typedef struct Complete_Tag Complete_Tag;

struct Complete_Tag {
	int x;
};

void take_tag(Opaque_Tag *t, Opaque_Tag **out, Complete_Tag *c);
