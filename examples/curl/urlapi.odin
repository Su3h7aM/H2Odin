package curl

foreign import lib "system:curl"

/* the error codes for the URL API */
CURLUcode :: enum u32 {
	UE_OK,
	/* 1 */
	UE_BAD_HANDLE,
	/* 2 */
	UE_BAD_PARTPOINTER,
	/* 3 */
	UE_MALFORMED_INPUT,
	/* 4 */
	UE_BAD_PORT_NUMBER,
	/* 5 */
	UE_UNSUPPORTED_SCHEME,
	/* 6 */
	UE_URLDECODE,
	/* 7 */
	UE_OUT_OF_MEMORY,
	/* 8 */
	UE_USER_NOT_ALLOWED,
	/* 9 */
	UE_UNKNOWN_PART,
	/* 10 */
	UE_NO_SCHEME,
	/* 11 */
	UE_NO_USER,
	/* 12 */
	UE_NO_PASSWORD,
	/* 13 */
	UE_NO_OPTIONS,
	/* 14 */
	UE_NO_HOST,
	/* 15 */
	UE_NO_PORT,
	/* 16 */
	UE_NO_QUERY,
	/* 17 */
	UE_NO_FRAGMENT,
	/* 18 */
	UE_NO_ZONEID,
	/* 19 */
	UE_BAD_FILE_URL,
	/* 20 */
	UE_BAD_FRAGMENT,
	/* 21 */
	UE_BAD_HOSTNAME,
	/* 22 */
	UE_BAD_IPV6,
	/* 23 */
	UE_BAD_LOGIN,
	/* 24 */
	UE_BAD_PASSWORD,
	/* 25 */
	UE_BAD_PATH,
	/* 26 */
	UE_BAD_QUERY,
	/* 27 */
	UE_BAD_SCHEME,
	/* 28 */
	UE_BAD_SLASHES,
	/* 29 */
	UE_BAD_USER,
	/* 30 */
	UE_LACKS_IDN,
	/* 31 */
	UE_TOO_LARGE,
	UE_LAST,
}

CURLUPart :: enum u32 {
	UPART_URL,
	UPART_SCHEME,
	UPART_USER,
	UPART_PASSWORD,
	UPART_OPTIONS,
	UPART_HOST,
	UPART_PORT,
	UPART_PATH,
	UPART_QUERY,
	UPART_FRAGMENT,
	/* added in 7.65.0 */
	UPART_ZONEID,
}

Curl_URL :: distinct rawptr

CURLU :: Curl_URL

@(link_prefix = "curl_")
foreign lib {
	/*
	 * curl_url() creates a new CURLU handle and returns a pointer to it.
	 * Must be freed with curl_url_cleanup().
	 */
	url :: proc() -> Curl_URL ---
	/*
	 * curl_url_cleanup() frees the CURLU handle and related resources used for
	 * the URL parsing. It will not free strings previously returned with the URL
	 * API.
	 */
	url_cleanup :: proc(handle: Curl_URL) ---
	/*
	 * curl_url_dup() duplicates a CURLU handle and returns a new copy. The new
	 * handle must also be freed with curl_url_cleanup().
	 */
	url_dup :: proc(in_: Curl_URL) -> Curl_URL ---
	/*
	 * curl_url_get() extracts a specific part of the URL from a CURLU
	 * handle. Returns error code. The returned pointer MUST be freed with
	 * curl_free() afterwards.
	 */
	url_get :: proc(handle: Curl_URL, what: CURLUPart, part: ^^u8, flags: u32) -> CURLUcode ---
	/*
	 * curl_url_set() sets a specific part of the URL in a CURLU handle. Returns
	 * error code. The passed in string will be copied. Passing a NULL instead of
	 * a part string, clears that part.
	 */
	url_set :: proc(handle: Curl_URL, what: CURLUPart, part: cstring, flags: u32) -> CURLUcode ---
	/*
	 * curl_url_strerror() turns a CURLUcode value into the equivalent human
	 * readable error string. This is useful for printing meaningful error
	 * messages.
	 */
	url_strerror :: proc(_: CURLUcode) -> cstring ---
}
