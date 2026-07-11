/* Pure `typedef void Name` — a common C opaque-handle idiom (curl's CURL,
 * miniaudio's ma_data_source). The typedef itself names an incomplete type;
 * the API only ever passes `Name *`. */
typedef void CURL;
typedef void CURLM;

struct curl_wait;

/* Direct use: return and parameter. */
CURL *curl_easy_init(void);
void curl_easy_cleanup(CURL *handle);

/* Callback typedef references the opaque name. */
typedef int (*curl_callback)(CURL *handle, int data);

/* Field of record references the opaque name. */
struct curl_wait {
	CURL *easy;
	curl_callback cb;
	int reserved;
};
