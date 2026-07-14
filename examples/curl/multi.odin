package curl

import "core:sys/posix"

foreign import lib "system:curl"

CURLPIPE_NOTHING :: 0
CURLPIPE_HTTP1 :: 1
CURLPIPE_MULTIPLEX :: 2
WAIT_POLLIN :: 0x0001
WAIT_POLLPRI :: 0x0002
WAIT_POLLOUT :: 0x0004
POLL_NONE :: 0
POLL_IN :: 1
POLL_OUT :: 2
POLL_INOUT :: 3
POLL_REMOVE :: 4
CSELECT_IN :: 0x01
CSELECT_OUT :: 0x02
CSELECT_ERR :: 0x04
PUSH_OK :: 0
PUSH_DENY :: 1
PUSH_ERROROUT :: 2
CURLMNOTIFY_INFO_READ :: 0
CURLMNOTIFY_EASY_DONE :: 1
CURLM :: distinct rawptr

CURLMcode :: enum i32 {
	/* please call curl_multi_perform() or
	                                    curl_multi_socket*() soon */
	M_CALL_MULTI_PERFORM = -1,
	M_OK,
	/* the passed-in handle is not a valid CURLM handle */
	M_BAD_HANDLE,
	/* an easy handle was not good/valid */
	M_BAD_EASY_HANDLE,
	/* if you ever get this, you are in deep sh*t */
	M_OUT_OF_MEMORY,
	/* this is a libcurl bug */
	M_INTERNAL_ERROR,
	/* the passed in socket argument did not match */
	M_BAD_SOCKET,
	/* curl_multi_setopt() with unsupported option */
	M_UNKNOWN_OPTION,
	/* an easy handle already added to a multi handle was
	                            attempted to get added - again */
	M_ADDED_ALREADY,
	/* an api function was called from inside a
	                               callback */
	M_RECURSIVE_API_CALL,
	/* wakeup is unavailable or failed */
	M_WAKEUP_FAILURE,
	/* function called with a bad parameter */
	M_BAD_FUNCTION_ARGUMENT,
	M_ABORTED_BY_CALLBACK,
	M_UNRECOVERABLE_POLL,
	M_LAST,
}

CURLMSG :: enum u32 {
	/* first, not used */
	MSG_NONE,
	/* This easy handle has completed. 'result' contains
	                   the CURLcode of the transfer */
	MSG_DONE,
	/* last, not used */
	MSG_LAST,
}

CURLMsg :: struct {
	/* what this message means */
	msg:         CURLMSG,
	/* the handle it concerns */
	easy_handle: ^CURL,
	data:        struct #raw_union {
		/* message-specific data */
		whatever: rawptr,
		/* return code for transfer */
		result:   CURLcode,
	},
}

waitfd :: struct {
	fd:      socket_t,
	events:  i16,
	revents: i16,
}

socket_callback :: proc "c" (_: ^CURL, _: socket_t, _: i32, _: rawptr, _: rawptr) -> i32

/*
 * Name:    curl_multi_timer_callback
 *
 * Desc:    Called by libcurl whenever the library detects a change in the
 *          maximum number of milliseconds the app is allowed to wait before
 *          curl_multi_socket() or curl_multi_perform() must be called
 *          (to allow libcurl's timed events to take place).
 *
 * Returns: The callback should return zero.
 */
multi_timer_callback :: proc "c" (_: ^CURLM, _: i64, _: rawptr) -> i32

CURLMoption :: enum u32 {
	/* This is the socket callback function pointer */
	MOPT_SOCKETFUNCTION = 20001,
	/* This is the argument passed to the socket callback */
	MOPT_SOCKETDATA = 10002,
	/* set to 1 to enable pipelining for this multi handle */
	MOPT_PIPELINING = 3,
	/* This is the timer callback function pointer */
	MOPT_TIMERFUNCTION = 20004,
	/* This is the argument passed to the timer callback */
	MOPT_TIMERDATA = 10005,
	/* maximum number of entries in the connection cache */
	MOPT_MAXCONNECTS = 6,
	/* maximum number of (pipelining) connections to one host */
	MOPT_MAX_HOST_CONNECTIONS,
	/* maximum number of requests in a pipeline */
	MOPT_MAX_PIPELINE_LENGTH,
	/* a connection with a content-length longer than this
	     will not be considered for pipelining */
	MOPT_CONTENT_LENGTH_PENALTY_SIZE = 30009,
	/* a connection with a chunk length longer than this
	     will not be considered for pipelining */
	MOPT_CHUNK_LENGTH_PENALTY_SIZE,
	/* a list of site names(+port) that are blocked from pipelining */
	MOPT_PIPELINING_SITE_BL = 10011,
	/* a list of server types that are blocked from pipelining */
	MOPT_PIPELINING_SERVER_BL,
	/* maximum number of open connections in total */
	MOPT_MAX_TOTAL_CONNECTIONS = 13,
	/* This is the server push callback function pointer */
	MOPT_PUSHFUNCTION = 20014,
	/* This is the argument passed to the server push callback */
	MOPT_PUSHDATA = 10015,
	/* maximum number of concurrent streams to support on a connection */
	MOPT_MAX_CONCURRENT_STREAMS = 16,
	/* network has changed, adjust caches/connection reuse */
	MOPT_NETWORK_CHANGED,
	/* This is the notify callback function pointer */
	MOPT_NOTIFYFUNCTION = 20018,
	/* This is the argument passed to the notify callback */
	MOPT_NOTIFYDATA = 10019,
	/* the last unused */
	MOPT_LASTENTRY,
}

CURLMinfo_offt :: enum u32 {
	/* first, never use this */
	MINFO_NONE,
	/* The number of easy handles currently managed by the multi handle,
	   * e.g. have been added but not yet removed. */
	MINFO_XFERS_CURRENT,
	/* The number of easy handles running, e.g. not done and not queueing. */
	MINFO_XFERS_RUNNING,
	/* The number of easy handles waiting to start, e.g. for a connection
	   * to become available due to limits on parallelism, max connections
	   * or other factors. */
	MINFO_XFERS_PENDING,
	/* The number of easy handles finished, waiting for their results to
	   * be read via `curl_multi_info_read()`. */
	MINFO_XFERS_DONE,
	/* The total number of easy handles added to the multi handle, ever. */
	MINFO_XFERS_ADDED,
	/* the last unused */
	MINFO_LASTENTRY,
}

pushheaders :: distinct rawptr

push_callback :: proc "c" (_: ^CURL, _: ^CURL, _: uint, _: pushheaders, _: rawptr) -> i32

/*
 * Callback to install via CURLMOPT_NOTIFYFUNCTION.
 */
notify_callback :: proc "c" (_: ^CURLM, _: u32, _: ^CURL, _: rawptr)

@(link_prefix = "curl_")
foreign lib {
	/*
	 * Name:    curl_multi_init()
	 *
	 * Desc:    initialize multi-style curl usage
	 *
	 * Returns: a new CURLM handle to use in all 'curl_multi' functions.
	 */
	multi_init :: proc() -> ^CURLM ---
	/*
	 * Name:    curl_multi_add_handle()
	 *
	 * Desc:    add a standard curl handle to the multi stack
	 *
	 * Returns: CURLMcode type, general multi error code.
	 */
	multi_add_handle :: proc(multi_handle: ^CURLM, handle: ^CURL) -> CURLMcode ---
	/*
	  * Name:    curl_multi_remove_handle()
	  *
	  * Desc:    removes a curl handle from the multi stack again
	  *
	  * Returns: CURLMcode type, general multi error code.
	  */
	multi_remove_handle :: proc(multi_handle: ^CURLM, handle: ^CURL) -> CURLMcode ---
	/*
	  * Name:    curl_multi_fdset()
	  *
	  * Desc:    Ask curl for its fd_set sets. The app can use these to select() or
	  *          poll() on. We want curl_multi_perform() called as soon as one of
	  *          them are ready.
	  *
	  * Returns: CURLMcode type, general multi error code.
	  */
	multi_fdset :: proc(multi_handle: ^CURLM, read_fd_set: posix.fd_set, write_fd_set: posix.fd_set, exc_fd_set: posix.fd_set, max_fd: ^i32) -> CURLMcode ---
	/*
	 * Name:     curl_multi_wait()
	 *
	 * Desc:     Poll on all fds within a CURLM set as well as any
	 *           additional fds passed to the function.
	 *
	 * Returns:  CURLMcode type, general multi error code.
	 */
	multi_wait :: proc(multi_handle: ^CURLM, extra_fds: [^]waitfd, extra_nfds: u32, timeout_ms: i32, ret: ^i32) -> CURLMcode ---
	/*
	 * Name:     curl_multi_poll()
	 *
	 * Desc:     Poll on all fds within a CURLM set as well as any
	 *           additional fds passed to the function.
	 *
	 * Returns:  CURLMcode type, general multi error code.
	 */
	multi_poll :: proc(multi_handle: ^CURLM, extra_fds: [^]waitfd, extra_nfds: u32, timeout_ms: i32, ret: ^i32) -> CURLMcode ---
	/*
	 * Name:     curl_multi_wakeup()
	 *
	 * Desc:     wakes up a sleeping curl_multi_poll call.
	 *
	 * Returns:  CURLMcode type, general multi error code.
	 */
	multi_wakeup :: proc(multi_handle: ^CURLM) -> CURLMcode ---
	/*
	  * Name:    curl_multi_perform()
	  *
	  * Desc:    When the app thinks there is data available for curl it calls this
	  *          function to read/write whatever there is right now. This returns
	  *          as soon as the reads and writes are done. This function does not
	  *          require that there actually is data available for reading or that
	  *          data can be written, it can be called just in case. It returns
	  *          the number of handles that still transfer data in the second
	  *          argument's integer-pointer.
	  *
	  * Returns: CURLMcode type, general multi error code. *NOTE* that this only
	  *          returns errors etc regarding the whole multi stack. There might
	  *          still have occurred problems on individual transfers even when
	  *          this returns OK.
	  */
	multi_perform :: proc(multi_handle: ^CURLM, running_handles: ^i32) -> CURLMcode ---
	/*
	  * Name:    curl_multi_cleanup()
	  *
	  * Desc:    Cleans up and removes a whole multi stack. It does not free or
	  *          touch any individual easy handles in any way. We need to define
	  *          in what state those handles will be if this function is called
	  *          in the middle of a transfer.
	  *
	  * Returns: CURLMcode type, general multi error code.
	  */
	multi_cleanup :: proc(multi_handle: ^CURLM) -> CURLMcode ---
	/*
	 * Name:    curl_multi_info_read()
	 *
	 * Desc:    Ask the multi handle if there is any messages/informationals from
	 *          the individual transfers. Messages include informationals such as
	 *          error code from the transfer or just the fact that a transfer is
	 *          completed. More details on these should be written down as well.
	 *
	 *          Repeated calls to this function will return a new struct each
	 *          time, until a special "end of msgs" struct is returned as a signal
	 *          that there is no more to get at this point.
	 *
	 *          The data the returned pointer points to will not survive calling
	 *          curl_multi_cleanup().
	 *
	 *          The 'CURLMsg' struct is meant to be simple and only contain basic
	 *          information. If more involved information is wanted, we will
	 *          provide the particular "transfer handle" in that struct and that
	 *          should/could/would be used in subsequent curl_easy_getinfo() calls
	 *          (or similar). The point being that we must never expose complex
	 *          structs to applications, as then we will undoubtably get backwards
	 *          compatibility problems in the future.
	 *
	 * Returns: A pointer to a filled-in struct, or NULL if it failed or ran out
	 *          of structs. It also writes the number of messages left in the
	 *          queue (after this read) in the integer the second argument points
	 *          to.
	 */
	multi_info_read :: proc(multi_handle: ^CURLM, msgs_in_queue: ^i32) -> ^CURLMsg ---
	/*
	 * Name:    curl_multi_strerror()
	 *
	 * Desc:    The curl_multi_strerror function may be used to turn a CURLMcode
	 *          value into the equivalent human readable error string. This is
	 *          useful for printing meaningful error messages.
	 *
	 * Returns: A pointer to a null-terminated error message.
	 */
	multi_strerror :: proc(_: CURLMcode) -> cstring ---
	@(deprecated = "since 7.19.5. Use curl_multi_socket_action()")
	multi_socket :: proc(multi_handle: ^CURLM, s: socket_t, running_handles: ^i32) -> CURLMcode ---
	multi_socket_action :: proc(multi_handle: ^CURLM, s: socket_t, ev_bitmask: i32, running_handles: ^i32) -> CURLMcode ---
	@(deprecated = "since 7.19.5. Use curl_multi_socket_action()")
	multi_socket_all :: proc(multi_handle: ^CURLM, running_handles: ^i32) -> CURLMcode ---
	/*
	 * Name:    curl_multi_timeout()
	 *
	 * Desc:    Returns the maximum number of milliseconds the app is allowed to
	 *          wait before curl_multi_socket() or curl_multi_perform() must be
	 *          called (to allow libcurl's timed events to take place).
	 *
	 * Returns: CURLM error code.
	 */
	multi_timeout :: proc(multi_handle: ^CURLM, milliseconds: ^i64) -> CURLMcode ---
	/*
	 * Name:    curl_multi_setopt()
	 *
	 * Desc:    Sets options for the multi handle.
	 *
	 * Returns: CURLM error code.
	 */
	multi_setopt :: proc(multi_handle: ^CURLM, option: CURLMoption, #c_vararg _: ..any) -> CURLMcode ---
	/*
	 * Name:    curl_multi_assign()
	 *
	 * Desc:    This function sets an association in the multi handle between the
	 *          given socket and a private pointer of the application. This is
	 *          (only) useful for curl_multi_socket uses.
	 *
	 * Returns: CURLM error code.
	 */
	multi_assign :: proc(multi_handle: ^CURLM, sockfd: socket_t, sockp: rawptr) -> CURLMcode ---
	/*
	 * Name:    curl_multi_get_handles()
	 *
	 * Desc:    Returns an allocated array holding all handles currently added to
	 *          the multi handle. Marks the final entry with a NULL pointer. If
	 *          there is no easy handle added to the multi handle, this function
	 *          returns an array with the first entry as a NULL pointer.
	 *
	 * Returns: NULL on failure, otherwise a CURL **array pointer
	 */
	multi_get_handles :: proc(multi_handle: ^CURLM) -> ^^CURL ---
	/*
	 * Name:    curl_multi_get_offt()
	 *
	 * Desc:    Retrieves a numeric value for the `CURLMINFO_*` enums.
	 *
	 * Returns: CULRM_OK or error when value could not be obtained.
	 */
	multi_get_offt :: proc(multi_handle: ^CURLM, info: CURLMinfo_offt, pvalue: ^off_t) -> CURLMcode ---
	pushheader_bynum :: proc(h: pushheaders, num: uint) -> ^u8 ---
	pushheader_byname :: proc(h: pushheaders, name: cstring) -> ^u8 ---
	/*
	 * Name:    curl_multi_waitfds()
	 *
	 * Desc:    Ask curl for fds for polling. The app can use these to poll on.
	 *          We want curl_multi_perform() called as soon as one of them are
	 *          ready. Passing zero size allows to get just a number of fds.
	 *
	 * Returns: CURLMcode type, general multi error code.
	 */
	multi_waitfds :: proc(multi: ^CURLM, ufds: ^waitfd, size: u32, fd_count: ^u32) -> CURLMcode ---
	multi_notify_disable :: proc(multi: ^CURLM, notification: u32) -> CURLMcode ---
	multi_notify_enable :: proc(multi: ^CURLM, notification: u32) -> CURLMcode ---
}
