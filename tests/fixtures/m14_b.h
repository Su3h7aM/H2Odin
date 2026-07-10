/* Header B for multi-file emission e2e; may be included from A in other tests. */
typedef struct M14_B_Rec {
	int x;
} M14_B_Rec;

M14_B_Rec m14_from_b(void);

#define M14_B_FLAG 2
