/* Header B for per-header emission tests. */
typedef struct Second_Header_Record {
	int x;
} Second_Header_Record;

Second_Header_Record from_header_b(void);

#define SECOND_HEADER_FLAG 2
