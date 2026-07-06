/** Current API version. */
#define API_VERSION 1

/** A documented record. */
struct Documented {
	/** The record identifier. */
	int id;
};

/** State enum. */
enum State {
	/** Ready state. */
	STATE_READY = 0,
	/** Failed state. */
	STATE_FAILED = 1,
};

/** A typedef alias. */
typedef int DocInt;

/** A global count. */
extern DocInt doc_count;

/** Does documented work. */
DocInt documented(struct Documented value, enum State state);
