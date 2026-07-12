typedef struct Data Data;

typedef enum Result {
	RESULT_OK = 0,
	RESULT_ERR = 1,
} Result;

/* Out-parameter + status return — wrapper lifts *out to a named result. */
Result parse(const void *data, int size, Data **out_data);

/* Pointer + count — wrapper folds into []int. */
void consume(int *items, int count);
