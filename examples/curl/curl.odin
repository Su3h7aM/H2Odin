package curl

foreign import lib "system:curl"

PROGRESSFUNC_CONTINUE :: 0x10000001
MAX_WRITE_SIZE :: 16384
WRITEFUNC_PAUSE :: 0x10000001
CHUNK_BGN_FUNC_OK :: 0
CHUNK_BGN_FUNC_FAIL :: 1
CHUNK_BGN_FUNC_SKIP :: 2
CHUNK_END_FUNC_OK :: 0
CHUNK_END_FUNC_FAIL :: 1
FNMATCHFUNC_MATCH :: 0
FNMATCHFUNC_NOMATCH :: 1
FNMATCHFUNC_FAIL :: 2
SEEKFUNC_OK :: 0
SEEKFUNC_FAIL :: 1
SEEKFUNC_CANTSEEK :: 2
READFUNC_ABORT :: 0x10000000
READFUNC_PAUSE :: 0x10000001
TRAILERFUNC_OK :: 0
TRAILERFUNC_ABORT :: 1
SOCKOPT_OK :: 0
SOCKOPT_ERROR :: 1
SOCKOPT_ALREADY_CONNECTED :: 2
PREREQFUNC_OK :: 0
PREREQFUNC_ABORT :: 1
CURLE_ALREADY_COMPLETE :: 99999
CURLOPT_OBSOLETE72 :: 9999
CURLOPT_OBSOLETE40 :: 9999
ERROR_SIZE :: 256
CURLOPTTYPE_LONG :: 0
CURLOPTTYPE_OBJECTPOINT :: 10000
CURLOPTTYPE_FUNCTIONPOINT :: 20000
CURLOPTTYPE_OFF_T :: 30000
CURLOPTTYPE_BLOB :: 40000
CURLINFO_STRING :: 0x100000
CURLINFO_LONG :: 0x200000
CURLINFO_DOUBLE :: 0x300000
CURLINFO_SLIST :: 0x400000
CURLINFO_PTR :: 0x400000
CURLINFO_SOCKET :: 0x500000
CURLINFO_OFF_T :: 0x600000
CURLINFO_TYPEMASK :: 0xf00000
GLOBAL_NOTHING :: 0
socket_t :: i32

/* enum for the different supported SSL backends */
sslbackend :: enum u32 {
	SSLBACKEND_NONE,
	SSLBACKEND_OPENSSL,
	SSLBACKEND_GNUTLS,
	SSLBACKEND_NSS,
	/* Was QSOSSL. */
	SSLBACKEND_OBSOLETE4,
	SSLBACKEND_GSKIT,
	SSLBACKEND_POLARSSL,
	SSLBACKEND_WOLFSSL,
	SSLBACKEND_SCHANNEL,
	SSLBACKEND_SECURETRANSPORT,
	SSLBACKEND_AXTLS,
	SSLBACKEND_MBEDTLS,
	SSLBACKEND_MESALINK,
	SSLBACKEND_BEARSSL,
	SSLBACKEND_RUSTLS,
}

httppost :: struct {
	/* next entry in the list */
	next:           ^httppost,
	/* pointer to allocated name */
	name:           ^u8,
	/* length of name length */
	namelength:     i64,
	/* pointer to allocated data contents */
	contents:       ^u8,
	/* length of contents field, see also
	                                       CURL_HTTPPOST_LARGE */
	contentslength: i64,
	/* pointer to allocated buffer contents */
	buffer:         ^u8,
	/* length of buffer field */
	bufferlength:   i64,
	/* Content-Type */
	contenttype:    ^u8,
	/* list of extra headers for this form */
	contentheader:  ^slist,
	/* if one field name has more than one
	                                       file, this link should link to following
	                                       files */
	more:           ^httppost,
	/* as defined below */
	flags:          i64,
	/* The filename to show. If not set, the
	                                       actual filename will be used (if this
	                                       is a file part) */
	showfilename:   ^u8,
	/* custom pointer used for
	                                       HTTPPOST_CALLBACK posts */
	userp:          rawptr,
	/* alternative length of contents
	                                       field. Used if CURL_HTTPPOST_LARGE is
	                                       set. Added in 7.46.0 */
	contentlen:     i64,
}

/* linked-list structure for the CURLOPT_QUOTE option (and other) */
slist :: struct {
	data: ^u8,
	next: ^slist,
}

/* This is the CURLOPT_PROGRESSFUNCTION callback prototype. It is now
   considered deprecated but was the only choice up until 7.31.0 */
progress_callback :: proc "c" (_: rawptr, _: f64, _: f64, _: f64, _: f64) -> i32

/* This is the CURLOPT_XFERINFOFUNCTION callback prototype. It was introduced
   in 7.32.0, avoids the use of floating point numbers and provides more
   detailed information. */
xferinfo_callback :: proc "c" (_: rawptr, _: i64, _: i64, _: i64, _: i64) -> i32

write_callback :: proc "c" (_: ^u8, _: uint, _: uint, _: rawptr) -> uint

/* This callback will be called when a new resolver request is made */
resolver_start_callback :: proc "c" (_: rawptr, _: rawptr, _: rawptr) -> i32

/* enumeration of file types */
curlfiletype :: enum u32 {
	FILETYPE_FILE,
	FILETYPE_DIRECTORY,
	FILETYPE_SYMLINK,
	FILETYPE_DEVICE_BLOCK,
	FILETYPE_DEVICE_CHAR,
	FILETYPE_NAMEDPIPE,
	FILETYPE_SOCKET,
	/* is possible only on Sun Solaris now */
	FILETYPE_DOOR,
	/* should never occur */
	FILETYPE_UNKNOWN,
}

/* Information about a single file, used when doing FTP wildcard matching */
fileinfo :: struct {
	filename:  ^u8,
	filetype:  curlfiletype,
	/* always zero! */
	time:      i64,
	perm:      u32,
	uid:       i32,
	gid:       i32,
	size:      i64,
	hardlinks: i64,
	strings:   struct {
		/* If some of these fields is not NULL, it is a pointer to b_data. */
		time:   ^u8,
		perm:   ^u8,
		user:   ^u8,
		group:  ^u8,
		/* pointer to the target filename of a symlink */
		target: ^u8,
	},
	flags:     u32,
	/* These are libcurl private struct fields. Previously used by libcurl, so
	     they must never be interfered with. */
	b_data:    ^u8,
	b_size:    uint,
	b_used:    uint,
}

/* if splitting of data transfer is enabled, this callback is called before
   download of an individual chunk started. Note that parameter "remains" works
   only for FTP wildcard downloading (for now), otherwise is not used */
chunk_bgn_callback :: proc "c" (_: rawptr, _: rawptr, _: i32) -> i64

/* If splitting of data transfer is enabled this callback is called after
   download of an individual chunk finished.
   Note! After this callback was set then it have to be called FOR ALL chunks.
   Even if downloading of this chunk was skipped in CHUNK_BGN_FUNC.
   This is the reason why we do not need "transfer_info" parameter in this
   callback and we are not interested in "remains" parameter too. */
chunk_end_callback :: proc "c" (_: rawptr) -> i64

/* callback type for wildcard downloading pattern matching. If the
   string matches the pattern, return CURL_FNMATCHFUNC_MATCH value, etc. */
fnmatch_callback :: proc "c" (_: rawptr, _: cstring, _: cstring) -> i32

seek_callback :: proc "c" (_: rawptr, _: i64, _: i32) -> i32

read_callback :: proc "c" (_: ^u8, _: uint, _: uint, _: rawptr) -> uint

trailer_callback :: proc "c" (_: ^^slist, _: rawptr) -> i32

curlsocktype :: enum u32 {
	/* socket created for a specific IP connection */
	SOCKTYPE_IPCXN,
	/* socket created by accept() call */
	SOCKTYPE_ACCEPT,
	/* never use */
	SOCKTYPE_LAST,
}

sockopt_callback :: proc "c" (_: rawptr, _: socket_t, _: curlsocktype) -> i32

sockaddr :: struct {
	family:   i32,
	socktype: i32,
	protocol: i32,
	/* addrlen was a socklen_t type before 7.18.0 but it
	                           turned really ugly and painful on the systems that
	                           lack this type */
	addrlen:  u32,
	addr:     sockaddr,
}

sockaddr :: struct {
	sa_family: u16,
	sa_data:   [14]u8,
}

opensocket_callback :: proc "c" (_: rawptr, _: curlsocktype, _: ^sockaddr) -> socket_t

closesocket_callback :: proc "c" (_: rawptr, _: socket_t) -> i32

curlioerr :: enum u32 {
	/* I/O operation successful */
	IOE_OK,
	/* command was unknown to callback */
	IOE_UNKNOWNCMD,
	/* failed to restart the read */
	IOE_FAILRESTART,
	/* never use */
	IOE_LAST,
}

curliocmd :: enum u32 {
	/* no operation */
	IOCMD_NOP,
	/* restart the read stream from start */
	IOCMD_RESTARTREAD,
	/* never use */
	IOCMD_LAST,
}

ioctl_callback :: proc "c" (_: ^CURL, _: i32, _: rawptr) -> curlioerr

/*
 * The following typedef's are signatures of malloc, free, realloc, strdup and
 * calloc respectively. Function pointers of these types can be passed to the
 * curl_global_init_mem() function to set user defined memory management
 * callback routines.
 */
malloc_callback :: proc "c" (_: uint) -> rawptr

free_callback :: proc "c" (_: rawptr)

realloc_callback :: proc "c" (_: rawptr, _: uint) -> rawptr

strdup_callback :: proc "c" (_: cstring) -> ^u8

calloc_callback :: proc "c" (_: uint, _: uint) -> rawptr

/* the kind of data that is passed to information_callback */
infotype :: enum u32 {
	INFO_TEXT,
	/* 1 */
	INFO_HEADER_IN,
	/* 2 */
	INFO_HEADER_OUT,
	/* 3 */
	INFO_DATA_IN,
	/* 4 */
	INFO_DATA_OUT,
	/* 5 */
	INFO_SSL_DATA_IN,
	/* 6 */
	INFO_SSL_DATA_OUT,
	INFO_END,
}

debug_callback :: proc "c" (_: ^CURL, _: infotype, _: ^u8, _: uint, _: rawptr) -> i32

/* This is the CURLOPT_PREREQFUNCTION callback prototype. */
prereq_callback :: proc "c" (_: rawptr, _: ^u8, _: ^u8, _: i32, _: i32) -> i32

/* All possible error codes from all sorts of curl functions. Future versions
   may return other values, stay prepared.

   Always add new return codes last. Never *EVER* remove any. The return
   codes must remain the same!
 */
CURLcode :: enum u32 {
	E_OK,
	/* 1 */
	E_UNSUPPORTED_PROTOCOL,
	/* 2 */
	E_FAILED_INIT,
	/* 3 */
	E_URL_MALFORMAT,
	/* 4 - [was obsoleted in August 2007 for
	                                    7.17.0, reused in April 2011 for 7.21.5] */
	E_NOT_BUILT_IN,
	/* 5 */
	E_COULDNT_RESOLVE_PROXY,
	/* 6 */
	E_COULDNT_RESOLVE_HOST,
	/* 7 */
	E_COULDNT_CONNECT,
	/* 8 */
	E_WEIRD_SERVER_REPLY,
	/* 9 a service was denied by the server
	                                    due to lack of access - when login fails
	                                    this is not returned. */
	E_REMOTE_ACCESS_DENIED,
	/* 10 - [was obsoleted in April 2006 for
	                                    7.15.4, reused in Dec 2011 for 7.24.0]*/
	E_FTP_ACCEPT_FAILED,
	/* 11 */
	E_FTP_WEIRD_PASS_REPLY,
	/* 12 - timeout occurred accepting server
	                                    [was obsoleted in August 2007 for 7.17.0,
	                                    reused in Dec 2011 for 7.24.0]*/
	E_FTP_ACCEPT_TIMEOUT,
	/* 13 */
	E_FTP_WEIRD_PASV_REPLY,
	/* 14 */
	E_FTP_WEIRD_227_FORMAT,
	/* 15 */
	E_FTP_CANT_GET_HOST,
	/* 16 - A problem in the http2 framing layer.
	                                    [was obsoleted in August 2007 for 7.17.0,
	                                    reused in July 2014 for 7.38.0] */
	E_HTTP2,
	/* 17 */
	E_FTP_COULDNT_SET_TYPE,
	/* 18 */
	E_PARTIAL_FILE,
	/* 19 */
	E_FTP_COULDNT_RETR_FILE,
	/* 20 - NOT USED */
	E_OBSOLETE20,
	/* 21 - quote command failure */
	E_QUOTE_ERROR,
	/* 22 */
	E_HTTP_RETURNED_ERROR,
	/* 23 */
	E_WRITE_ERROR,
	/* 24 - NOT USED */
	E_OBSOLETE24,
	/* 25 - failed upload "command" */
	E_UPLOAD_FAILED,
	/* 26 - could not open/read from file */
	E_READ_ERROR,
	/* 27 */
	E_OUT_OF_MEMORY,
	/* 28 - the timeout time was reached */
	E_OPERATION_TIMEDOUT,
	/* 29 - NOT USED */
	E_OBSOLETE29,
	/* 30 - FTP PORT operation failed */
	E_FTP_PORT_FAILED,
	/* 31 - the REST command failed */
	E_FTP_COULDNT_USE_REST,
	/* 32 - NOT USED */
	E_OBSOLETE32,
	/* 33 - RANGE "command" did not work */
	E_RANGE_ERROR,
	/* 34 */
	E_OBSOLETE34,
	/* 35 - wrong when connecting with SSL */
	E_SSL_CONNECT_ERROR,
	/* 36 - could not resume download */
	E_BAD_DOWNLOAD_RESUME,
	/* 37 */
	E_FILE_COULDNT_READ_FILE,
	/* 38 */
	E_LDAP_CANNOT_BIND,
	/* 39 */
	E_LDAP_SEARCH_FAILED,
	/* 40 - NOT USED */
	E_OBSOLETE40,
	/* 41 - NOT USED starting with 7.53.0 */
	E_OBSOLETE41,
	/* 42 */
	E_ABORTED_BY_CALLBACK,
	/* 43 */
	E_BAD_FUNCTION_ARGUMENT,
	/* 44 - NOT USED */
	E_OBSOLETE44,
	/* 45 - CURLOPT_INTERFACE failed */
	E_INTERFACE_FAILED,
	/* 46 - NOT USED */
	E_OBSOLETE46,
	/* 47 - catch endless re-direct loops */
	E_TOO_MANY_REDIRECTS,
	/* 48 - User specified an unknown option */
	E_UNKNOWN_OPTION,
	/* 49 - Malformed setopt option */
	E_SETOPT_OPTION_SYNTAX,
	/* 50 - NOT USED */
	E_OBSOLETE50,
	/* 51 - NOT USED */
	E_OBSOLETE51,
	/* 52 - when this is a specific error */
	E_GOT_NOTHING,
	/* 53 - SSL crypto engine not found */
	E_SSL_ENGINE_NOTFOUND,
	/* 54 - can not set SSL crypto engine as
	                                    default */
	E_SSL_ENGINE_SETFAILED,
	/* 55 - failed sending network data */
	E_SEND_ERROR,
	/* 56 - failure in receiving network data */
	E_RECV_ERROR,
	/* 57 - NOT IN USE */
	E_OBSOLETE57,
	/* 58 - problem with the local certificate */
	E_SSL_CERTPROBLEM,
	/* 59 - could not use specified cipher */
	E_SSL_CIPHER,
	/* 60 - peer's certificate or fingerprint
	                                     was not verified fine */
	E_PEER_FAILED_VERIFICATION,
	/* 61 - Unrecognized/bad encoding */
	E_BAD_CONTENT_ENCODING,
	/* 62 - NOT IN USE since 7.82.0 */
	E_OBSOLETE62,
	/* 63 - Maximum file size exceeded */
	E_FILESIZE_EXCEEDED,
	/* 64 - Requested FTP SSL level failed */
	E_USE_SSL_FAILED,
	/* 65 - Sending the data requires a rewind
	                                    that failed */
	E_SEND_FAIL_REWIND,
	/* 66 - failed to initialise ENGINE */
	E_SSL_ENGINE_INITFAILED,
	/* 67 - user, password or similar was not
	                                    accepted and we failed to login */
	E_LOGIN_DENIED,
	/* 68 - file not found on server */
	E_TFTP_NOTFOUND,
	/* 69 - permission problem on server */
	E_TFTP_PERM,
	/* 70 - out of disk space on server */
	E_REMOTE_DISK_FULL,
	/* 71 - Illegal TFTP operation */
	E_TFTP_ILLEGAL,
	/* 72 - Unknown transfer ID */
	E_TFTP_UNKNOWNID,
	/* 73 - File already exists */
	E_REMOTE_FILE_EXISTS,
	/* 74 - No such user */
	E_TFTP_NOSUCHUSER,
	/* 75 - NOT IN USE since 7.82.0 */
	E_OBSOLETE75,
	/* 76 - NOT IN USE since 7.82.0 */
	E_OBSOLETE76,
	/* 77 - could not load CACERT file, missing
	                                    or wrong format */
	E_SSL_CACERT_BADFILE,
	/* 78 - remote file not found */
	E_REMOTE_FILE_NOT_FOUND,
	/* 79 - error from the SSH layer, somewhat
	                                    generic so the error message will be of
	                                    interest when this has happened */
	E_SSH,
	/* 80 - Failed to shut down the SSL
	                                    connection */
	E_SSL_SHUTDOWN_FAILED,
	/* 81 - socket is not ready for send/recv,
	                                    wait till it is ready and try again (Added
	                                    in 7.18.2) */
	E_AGAIN,
	/* 82 - could not load CRL file, missing or
	                                    wrong format (Added in 7.19.0) */
	E_SSL_CRL_BADFILE,
	/* 83 - Issuer check failed.  (Added in
	                                    7.19.0) */
	E_SSL_ISSUER_ERROR,
	/* 84 - a PRET command failed */
	E_FTP_PRET_FAILED,
	/* 85 - mismatch of RTSP CSeq numbers */
	E_RTSP_CSEQ_ERROR,
	/* 86 - mismatch of RTSP Session Ids */
	E_RTSP_SESSION_ERROR,
	/* 87 - unable to parse FTP file list */
	E_FTP_BAD_FILE_LIST,
	/* 88 - chunk callback reported error */
	E_CHUNK_FAILED,
	/* 89 - No connection available, the
	                                    session will be queued */
	E_NO_CONNECTION_AVAILABLE,
	/* 90 - specified pinned public key did not
	                                     match */
	E_SSL_PINNEDPUBKEYNOTMATCH,
	/* 91 - invalid certificate status */
	E_SSL_INVALIDCERTSTATUS,
	/* 92 - stream error in HTTP/2 framing layer
	                                    */
	E_HTTP2_STREAM,
	/* 93 - an api function was called from
	                                    inside a callback */
	E_RECURSIVE_API_CALL,
	/* 94 - an authentication function returned an
	                                    error */
	E_AUTH_ERROR,
	/* 95 - An HTTP/3 layer problem */
	E_HTTP3,
	/* 96 - QUIC connection error */
	E_QUIC_CONNECT_ERROR,
	/* 97 - proxy handshake error */
	E_PROXY,
	/* 98 - client-side certificate required */
	E_SSL_CLIENTCERT,
	/* 99 - poll/select returned fatal error */
	E_UNRECOVERABLE_POLL,
	/* 100 - a value/data met its maximum */
	E_TOO_LARGE,
	/* 101 - ECH tried but failed */
	E_ECH_REQUIRED,
	/* never use! */
	_LAST,
}

/*
 * Proxy error codes. Returned in CURLINFO_PROXY_ERROR if CURLE_PROXY was
 * return for the transfers.
 */
CURLproxycode :: enum u32 {
	PX_OK,
	PX_BAD_ADDRESS_TYPE,
	PX_BAD_VERSION,
	PX_CLOSED,
	PX_GSSAPI,
	PX_GSSAPI_PERMSG,
	PX_GSSAPI_PROTECTION,
	PX_IDENTD,
	PX_IDENTD_DIFFER,
	PX_LONG_HOSTNAME,
	PX_LONG_PASSWD,
	PX_LONG_USER,
	PX_NO_AUTH,
	PX_RECV_ADDRESS,
	PX_RECV_AUTH,
	PX_RECV_CONNECT,
	PX_RECV_REQACK,
	PX_REPLY_ADDRESS_TYPE_NOT_SUPPORTED,
	PX_REPLY_COMMAND_NOT_SUPPORTED,
	PX_REPLY_CONNECTION_REFUSED,
	PX_REPLY_GENERAL_SERVER_FAILURE,
	PX_REPLY_HOST_UNREACHABLE,
	PX_REPLY_NETWORK_UNREACHABLE,
	PX_REPLY_NOT_ALLOWED,
	PX_REPLY_TTL_EXPIRED,
	PX_REPLY_UNASSIGNED,
	PX_REQUEST_FAILED,
	PX_RESOLVE_HOST,
	PX_SEND_AUTH,
	PX_SEND_CONNECT,
	PX_SEND_REQUEST,
	PX_UNKNOWN_FAIL,
	PX_UNKNOWN_MODE,
	PX_USER_REJECTED,
	/* never use */
	PX_LAST,
}

/* This prototype applies to all conversion callbacks */
conv_callback :: proc "c" (_: ^u8, _: uint) -> CURLcode

ssl_ctx_callback :: proc "c" (_: ^CURL, _: rawptr, _: rawptr) -> CURLcode

proxytype :: enum u32 {
	/* never use */
	PROXY_LAST = 8,
}

khtype :: enum u32 {
	KHTYPE_UNKNOWN,
	KHTYPE_RSA1,
	KHTYPE_RSA,
	KHTYPE_DSS,
	KHTYPE_ECDSA,
	KHTYPE_ED25519,
}

khkey :: struct {
	/* points to a null-terminated string encoded with base64
	                      if len is zero, otherwise to the "raw" data */
	key:     cstring,
	len:     uint,
	keytype: khtype,
}

/* this is the set of return values expected from the curl_sshkeycallback
   callback */
khstat :: enum u32 {
	KHSTAT_FINE_ADD_TO_FILE,
	KHSTAT_FINE,
	/* reject the connection, return an error */
	KHSTAT_REJECT,
	/* do not accept it, but we cannot answer right now.
	                        Causes a CURLE_PEER_FAILED_VERIFICATION error but the
	                        connection will be left intact etc */
	KHSTAT_DEFER,
	/* accept and replace the wrong key */
	KHSTAT_FINE_REPLACE,
	/* not for use, only a marker for last-in-list */
	KHSTAT_LAST,
}

/* this is the set of status codes pass in to the callback */
khmatch :: enum u32 {
	/* match */
	KHMATCH_OK,
	/* host found, key mismatch! */
	KHMATCH_MISMATCH,
	/* no matching host/key found */
	KHMATCH_MISSING,
	/* not for use, only a marker for last-in-list */
	KHMATCH_LAST,
}

sshkeycallback :: proc "c" (_: ^CURL, _: ^khkey, _: ^khkey, _: khmatch, _: rawptr) -> i32

sshhostkeycallback :: proc "c" (_: rawptr, _: i32, _: cstring, _: uint) -> i32

usessl :: enum u32 {
	/* not an option, never use */
	USESSL_LAST = 4,
}

ftpccc :: enum u32 {
	/* not an option, never use */
	FTPSSL_CCC_LAST = 3,
}

ftpauth :: enum u32 {
	/* not an option, never use */
	FTPAUTH_LAST = 3,
}

ftpcreatedir :: enum u32 {
	/* not an option, never use */
	FTP_CREATE_DIR_LAST = 3,
}

ftpmethod :: enum u32 {
	/* not an option, never use */
	FTPMETHOD_LAST = 4,
}

hstsentry :: struct {
	name:    ^u8,
	namelen: uint,
	using _: bit_field u8 {
		includeSubDomains: u8 | 1,
		_:                 u8 | 7,
	},
	/* YYYYMMDD HH:MM:SS [null-terminated] */
	expire:  [18]u8,
}

index :: struct {
	/* the provided entry's "index" or count */
	index: uint,
	/* total number of entries to save */
	total: uint,
}

CURLSTScode :: enum u32 {
	STS_OK,
	STS_DONE,
	STS_FAIL,
}

hstsread_callback :: proc "c" (_: ^CURL, _: ^hstsentry, _: rawptr) -> CURLSTScode

hstswrite_callback :: proc "c" (_: ^CURL, _: ^hstsentry, _: ^index, _: rawptr) -> CURLSTScode

/*
 * All CURLOPT_* values.
 */
CURLoption :: enum u32 {
	/* This is the FILE * or void * the regular output should be written to. */
	OPT_WRITEDATA = 10001,
	/* The full URL to get/put */
	OPT_URL,
	/* Port number to connect to, if other than default. */
	OPT_PORT = 3,
	/* Name of proxy to use. */
	OPT_PROXY = 10004,
	/* "user:password;options" to use when fetching. */
	OPT_USERPWD,
	/* "user:password" to use with proxy. */
	OPT_PROXYUSERPWD,
	/* Range to get, specified as an ASCII string. */
	OPT_RANGE,
	/* Specified file stream to upload from (use as input): */
	OPT_READDATA = 10009,
	/* Buffer to receive error messages in, must be at least CURL_ERROR_SIZE
	   * bytes big. */
	OPT_ERRORBUFFER,
	/* Function that will be called to store the output (instead of fwrite). The
	   * parameters will use fwrite() syntax, make sure to follow them. */
	OPT_WRITEFUNCTION = 20011,
	/* Function that will be called to read the input (instead of fread). The
	   * parameters will use fread() syntax, make sure to follow them. */
	OPT_READFUNCTION,
	/* Time-out the read operation after this amount of seconds */
	OPT_TIMEOUT = 13,
	/* If CURLOPT_READDATA is used, this can be used to inform libcurl about
	   * how large the file being sent really is. That allows better error
	   * checking and better verifies that the upload was successful. -1 means
	   * unknown size.
	   *
	   * For large file support, there is also a _LARGE version of the key
	   * which takes an off_t type, allowing platforms with larger off_t
	   * sizes to handle larger files. See below for INFILESIZE_LARGE.
	   */
	OPT_INFILESIZE,
	/* POST static input fields. */
	OPT_POSTFIELDS = 10015,
	/* Set the referrer page (needed by some CGIs) */
	OPT_REFERER,
	/* Set the FTP PORT string (interface name, named or numerical IP address)
	     Use i.e '-' to use default address. */
	OPT_FTPPORT,
	/* Set the User-Agent string (examined by some CGIs) */
	OPT_USERAGENT,
	/* Set the "low speed limit" */
	OPT_LOW_SPEED_LIMIT = 19,
	/* Set the "low speed time" */
	OPT_LOW_SPEED_TIME,
	/* Set the continuation offset.
	   *
	   * Note there is also a _LARGE version of this key which uses
	   * off_t types, allowing for large file offsets on platforms which
	   * use larger-than-32-bit off_t's. Look below for RESUME_FROM_LARGE.
	   */
	OPT_RESUME_FROM,
	/* Set cookie in request: */
	OPT_COOKIE = 10022,
	/* This points to a linked list of headers, struct curl_slist kind. This
	     list is also used for RTSP (in spite of its name) */
	OPT_HTTPHEADER,
	/* This points to a linked list of post entries, struct curl_httppost */
	OPT_HTTPPOST,
	/* name of the file keeping your private SSL-certificate */
	OPT_SSLCERT,
	/* password for the SSL or SSH private key */
	OPT_KEYPASSWD,
	/* send TYPE parameter? */
	OPT_CRLF = 27,
	/* send linked-list of QUOTE commands */
	OPT_QUOTE = 10028,
	/* send FILE * or void * to store headers to, if you use a callback it
	     is simply passed to the callback unmodified */
	OPT_HEADERDATA,
	/* point to a file to read the initial cookies from, also enables
	     "cookie awareness" */
	OPT_COOKIEFILE = 10031,
	/* What version to specifically try to use.
	     See CURL_SSLVERSION defines below. */
	OPT_SSLVERSION = 32,
	/* What kind of HTTP time condition to use, see defines */
	OPT_TIMECONDITION,
	/* Time to use with the above condition. Specified in number of seconds
	     since 1 Jan 1970 */
	OPT_TIMEVALUE,
	/* Custom request, for customizing the get command like
	     HTTP: DELETE, TRACE and others
	     FTP: to use a different list command
	     */
	OPT_CUSTOMREQUEST = 10036,
	/* FILE handle to use instead of stderr */
	OPT_STDERR,
	/* send linked-list of post-transfer QUOTE commands */
	OPT_POSTQUOTE = 10039,
	/* talk a lot */
	OPT_VERBOSE = 41,
	/* throw the header out too */
	OPT_HEADER,
	/* shut off the progress meter */
	OPT_NOPROGRESS,
	/* use HEAD to get http document */
	OPT_NOBODY,
	/* no output on http error codes >= 400 */
	OPT_FAILONERROR,
	/* this is an upload */
	OPT_UPLOAD,
	/* HTTP POST method */
	OPT_POST,
	/* bare names when listing directories */
	OPT_DIRLISTONLY,
	/* Append instead of overwrite on upload! */
	OPT_APPEND = 50,
	/* Specify whether to read the user+password from the .netrc or the URL.
	   * This must be one of the CURL_NETRC_* enums below. */
	OPT_NETRC,
	/* use Location: Luke! */
	OPT_FOLLOWLOCATION,
	/* transfer data in text/ASCII format */
	OPT_TRANSFERTEXT,
	/* HTTP PUT */
	OPT_PUT,
	/* DEPRECATED
	   * Function that will be called instead of the internal progress display
	   * function. This function should be defined as the curl_progress_callback
	   * prototype defines. */
	OPT_PROGRESSFUNCTION = 20056,
	/* Data passed to the CURLOPT_PROGRESSFUNCTION and CURLOPT_XFERINFOFUNCTION
	     callbacks */
	OPT_XFERINFODATA = 10057,
	/* We want the referrer field set automatically when following locations */
	OPT_AUTOREFERER = 58,
	/* Port of the proxy, can be set in the proxy string as well with:
	     "[host]:[port]" */
	OPT_PROXYPORT,
	/* size of the POST input data, if strlen() is not good to use */
	OPT_POSTFIELDSIZE,
	/* tunnel non-http operations through an HTTP proxy */
	OPT_HTTPPROXYTUNNEL,
	/* Set the interface string to use as outgoing network interface */
	OPT_INTERFACE = 10062,
	/* Set the krb4/5 security level, this also enables krb4/5 awareness. This
	   * is a string, 'clear', 'safe', 'confidential' or 'private'. If the string
	   * is set but does not match one of these, 'private' will be used.  */
	OPT_KRBLEVEL,
	/* Set if we should verify the peer in ssl handshake, set 1 to verify. */
	OPT_SSL_VERIFYPEER = 64,
	/* The CApath or CAfile used to validate the peer certificate
	     this option is used only if SSL_VERIFYPEER is true */
	OPT_CAINFO = 10065,
	/* Maximum number of http redirects to follow */
	OPT_MAXREDIRS = 68,
	/* Pass a long set to 1 to get the date of the requested document (if
	     possible)! Pass a zero to shut it off. */
	OPT_FILETIME,
	/* This points to a linked list of telnet options */
	OPT_TELNETOPTIONS = 10070,
	/* Max amount of cached alive connections */
	OPT_MAXCONNECTS = 71,
	/* Set to explicitly use a new connection for the upcoming transfer.
	     Do not use this unless you are absolutely sure of this, as it makes the
	     operation slower and is less friendly for the network. */
	OPT_FRESH_CONNECT = 74,
	/* Set to explicitly forbid the upcoming transfer's connection to be reused
	     when done. Do not use this unless you are absolutely sure of this, as it
	     makes the operation slower and is less friendly for the network. */
	OPT_FORBID_REUSE,
	/* Set to a filename that contains random data for libcurl to use to
	     seed the random engine when doing SSL connects. */
	OPT_RANDOM_FILE = 10076,
	/* Set to the Entropy Gathering Daemon socket pathname */
	OPT_EGDSOCKET,
	/* Time-out connect operations after this amount of seconds, if connects are
	     OK within this time, then fine... This only aborts the connect phase. */
	OPT_CONNECTTIMEOUT = 78,
	/* Function that will be called to store headers (instead of fwrite). The
	   * parameters will use fwrite() syntax, make sure to follow them. */
	OPT_HEADERFUNCTION = 20079,
	/* Set this to force the HTTP request to get back to GET. Only really usable
	     if POST, PUT or a custom request have been used first.
	   */
	OPT_HTTPGET = 80,
	/* Set if we should verify the Common name from the peer certificate in ssl
	   * handshake, set 1 to check existence, 2 to ensure that it matches the
	   * provided hostname. */
	OPT_SSL_VERIFYHOST,
	/* Specify which filename to write all known cookies in after completed
	     operation. Set filename to "-" (dash) to make it go to stdout. */
	OPT_COOKIEJAR = 10082,
	/* Specify which TLS 1.2 (1.1, 1.0) ciphers to use */
	OPT_SSL_CIPHER_LIST,
	/* Specify which HTTP version to use! This must be set to one of the
	     CURL_HTTP_VERSION* enums set below. */
	OPT_HTTP_VERSION = 84,
	/* Specifically switch on or off the FTP engine's use of the EPSV command. By
	     default, that one will always be attempted before the more traditional
	     PASV command. */
	OPT_FTP_USE_EPSV,
	/* type of the file keeping your SSL-certificate ("DER", "PEM", "ENG") */
	OPT_SSLCERTTYPE = 10086,
	/* name of the file keeping your private SSL-key */
	OPT_SSLKEY,
	/* type of the file keeping your private SSL-key ("DER", "PEM", "ENG") */
	OPT_SSLKEYTYPE,
	/* crypto engine for the SSL-sub system */
	OPT_SSLENGINE,
	/* set the crypto engine for the SSL-sub system as default
	     the param has no meaning...
	   */
	OPT_SSLENGINE_DEFAULT = 90,
	/* Non-zero value means to use the global dns cache */
	/* DEPRECATED, do not use! */
	OPT_DNS_USE_GLOBAL_CACHE,
	/* DNS cache timeout */
	OPT_DNS_CACHE_TIMEOUT,
	/* send linked-list of pre-transfer QUOTE commands */
	OPT_PREQUOTE = 10093,
	/* set the debug function */
	OPT_DEBUGFUNCTION = 20094,
	/* set the data for the debug function */
	OPT_DEBUGDATA = 10095,
	/* mark this as start of a cookie session */
	OPT_COOKIESESSION = 96,
	/* The CApath directory used to validate the peer certificate
	     this option is used only if SSL_VERIFYPEER is true */
	OPT_CAPATH = 10097,
	/* Instruct libcurl to use a smaller receive buffer */
	OPT_BUFFERSIZE = 98,
	/* Instruct libcurl to not use any signal/alarm handlers, even when using
	     timeouts. This option is useful for multi-threaded applications.
	     See libcurl-the-guide for more background information. */
	OPT_NOSIGNAL,
	/* Provide a CURLShare for mutexing non-ts data */
	OPT_SHARE = 10100,
	/* indicates type of proxy. accepted values are CURLPROXY_HTTP (default),
	     CURLPROXY_HTTPS, CURLPROXY_SOCKS4, CURLPROXY_SOCKS4A and
	     CURLPROXY_SOCKS5. */
	OPT_PROXYTYPE = 101,
	/* Set the Accept-Encoding string. Use this to tell a server you would like
	     the response to be compressed. Before 7.21.6, this was known as
	     CURLOPT_ENCODING */
	OPT_ACCEPT_ENCODING = 10102,
	/* Set pointer to private data */
	OPT_PRIVATE,
	/* Set aliases for HTTP 200 in the HTTP Response header */
	OPT_HTTP200ALIASES,
	/* Continue to send authentication (user+password) when following locations,
	     even when hostname changed. This can potentially send off the name
	     and password to whatever host the server decides. */
	OPT_UNRESTRICTED_AUTH = 105,
	/* Specifically switch on or off the FTP engine's use of the EPRT command (
	     it also disables the LPRT attempt). By default, those ones will always be
	     attempted before the good old traditional PORT command. */
	OPT_FTP_USE_EPRT,
	/* Set this to a bitmask value to enable the particular authentications
	     methods you like. Use this in combination with CURLOPT_USERPWD.
	     Note that setting multiple bits may cause extra network round-trips. */
	OPT_HTTPAUTH,
	/* Set the ssl context callback function, currently only for OpenSSL or
	     wolfSSL ssl_ctx, or mbedTLS mbedtls_ssl_config in the second argument.
	     The function must match the curl_ssl_ctx_callback prototype. */
	OPT_SSL_CTX_FUNCTION = 20108,
	/* Set the userdata for the ssl context callback function's third
	     argument */
	OPT_SSL_CTX_DATA = 10109,
	/* FTP Option that causes missing dirs to be created on the remote server.
	     In 7.19.4 we introduced the convenience enums for this option using the
	     CURLFTP_CREATE_DIR prefix.
	  */
	OPT_FTP_CREATE_MISSING_DIRS = 110,
	/* Set this to a bitmask value to enable the particular authentications
	     methods you like. Use this in combination with CURLOPT_PROXYUSERPWD.
	     Note that setting multiple bits may cause extra network round-trips. */
	OPT_PROXYAUTH,
	/* Option that changes the timeout, in seconds, associated with getting a
	     response. This is different from transfer timeout time and essentially
	     places a demand on the server to acknowledge commands in a timely
	     manner. For FTP, SMTP, IMAP and POP3. */
	OPT_SERVER_RESPONSE_TIMEOUT,
	/* Set this option to one of the CURL_IPRESOLVE_* defines (see below) to
	     tell libcurl to use those IP versions only. This only has effect on
	     systems with support for more than one, i.e IPv4 _and_ IPv6. */
	OPT_IPRESOLVE,
	/* Set this option to limit the size of a file that will be downloaded from
	     an HTTP or FTP server.
	
	     Note there is also _LARGE version which adds large file support for
	     platforms which have larger off_t sizes. See MAXFILESIZE_LARGE below. */
	OPT_MAXFILESIZE,
	/* See the comment for INFILESIZE above, but in short, specifies
	   * the size of the file being uploaded.  -1 means unknown.
	   */
	OPT_INFILESIZE_LARGE = 30115,
	/* Sets the continuation offset. There is also a CURLOPTTYPE_LONG version
	   * of this; look above for RESUME_FROM.
	   */
	OPT_RESUME_FROM_LARGE,
	/* Sets the maximum size of data that will be downloaded from
	   * an HTTP or FTP server. See MAXFILESIZE above for the LONG version.
	   */
	OPT_MAXFILESIZE_LARGE,
	/* Set this option to the filename of your .netrc file you want libcurl
	     to parse (using the CURLOPT_NETRC option). If not set, libcurl will do
	     a poor attempt to find the user's home directory and check for a .netrc
	     file in there. */
	OPT_NETRC_FILE = 10118,
	/* Enable SSL/TLS for FTP, pick one of:
	     CURLUSESSL_TRY     - try using SSL, proceed anyway otherwise
	     CURLUSESSL_CONTROL - SSL for the control connection or fail
	     CURLUSESSL_ALL     - SSL for all communication or fail
	  */
	OPT_USE_SSL = 119,
	/* The _LARGE version of the standard POSTFIELDSIZE option */
	OPT_POSTFIELDSIZE_LARGE = 30120,
	/* Enable/disable the TCP Nagle algorithm */
	OPT_TCP_NODELAY = 121,
	/* When FTP over SSL/TLS is selected (with CURLOPT_USE_SSL), this option
	     can be used to change libcurl's default action which is to first try
	     "AUTH SSL" and then "AUTH TLS" in this order, and proceed when a OK
	     response has been received.
	
	     Available parameters are:
	     CURLFTPAUTH_DEFAULT - let libcurl decide
	     CURLFTPAUTH_SSL     - try "AUTH SSL" first, then TLS
	     CURLFTPAUTH_TLS     - try "AUTH TLS" first, then SSL
	  */
	OPT_FTPSSLAUTH = 129,
	/* When FTP over SSL/TLS is selected (with CURLOPT_USE_SSL), this option
	     can be used to change libcurl's default action which is to first try
	     "AUTH SSL" and then "AUTH TLS" in this order, and proceed when a OK
	     response has been received.
	
	     Available parameters are:
	     CURLFTPAUTH_DEFAULT - let libcurl decide
	     CURLFTPAUTH_SSL     - try "AUTH SSL" first, then TLS
	     CURLFTPAUTH_TLS     - try "AUTH TLS" first, then SSL
	  */
	OPT_IOCTLFUNCTION = 20130,
	/* When FTP over SSL/TLS is selected (with CURLOPT_USE_SSL), this option
	     can be used to change libcurl's default action which is to first try
	     "AUTH SSL" and then "AUTH TLS" in this order, and proceed when a OK
	     response has been received.
	
	     Available parameters are:
	     CURLFTPAUTH_DEFAULT - let libcurl decide
	     CURLFTPAUTH_SSL     - try "AUTH SSL" first, then TLS
	     CURLFTPAUTH_TLS     - try "AUTH TLS" first, then SSL
	  */
	OPT_IOCTLDATA = 10131,
	/* null-terminated string for pass on to the FTP server when asked for
	     "account" info */
	OPT_FTP_ACCOUNT = 10134,
	/* feed cookie into cookie engine */
	OPT_COOKIELIST,
	/* ignore Content-Length */
	OPT_IGNORE_CONTENT_LENGTH = 136,
	/* Set to non-zero to skip the IP address received in a 227 PASV FTP server
	     response. Typically used for FTP-SSL purposes but is not restricted to
	     that. libcurl will then instead use the same IP address it used for the
	     control connection. */
	OPT_FTP_SKIP_PASV_IP,
	/* Select "file method" to use when doing FTP, see the curl_ftpmethod
	     above. */
	OPT_FTP_FILEMETHOD,
	/* Local port number to bind the socket to */
	OPT_LOCALPORT,
	/* Number of ports to try, including the first one set with LOCALPORT.
	     Thus, setting it to 1 will make no additional attempts but the first.
	  */
	OPT_LOCALPORTRANGE,
	/* no transfer, set up connection and let application use the socket by
	     extracting it with CURLINFO_LASTSOCKET */
	OPT_CONNECT_ONLY,
	/* Function that will be called to convert from the
	     network encoding (instead of using the iconv calls in libcurl) */
	OPT_CONV_FROM_NETWORK_FUNCTION = 20142,
	/* Function that will be called to convert to the
	     network encoding (instead of using the iconv calls in libcurl) */
	OPT_CONV_TO_NETWORK_FUNCTION,
	/* Function that will be called to convert from UTF8
	     (instead of using the iconv calls in libcurl)
	     Note that this is used only for SSL certificate processing */
	OPT_CONV_FROM_UTF8_FUNCTION,
	/* if the connection proceeds too quickly then need to slow it down */
	/* limit-rate: maximum number of bytes per second to send or receive */
	OPT_MAX_SEND_SPEED_LARGE = 30145,
	/* if the connection proceeds too quickly then need to slow it down */
	/* limit-rate: maximum number of bytes per second to send or receive */
	OPT_MAX_RECV_SPEED_LARGE,
	/* Pointer to command string to send if USER/PASS fails. */
	OPT_FTP_ALTERNATIVE_TO_USER = 10147,
	/* callback function for setting socket options */
	OPT_SOCKOPTFUNCTION = 20148,
	/* callback function for setting socket options */
	OPT_SOCKOPTDATA = 10149,
	/* set to 0 to disable session ID reuse for this transfer, default is
	     enabled (== 1) */
	OPT_SSL_SESSIONID_CACHE = 150,
	/* allowed SSH authentication methods */
	OPT_SSH_AUTH_TYPES,
	/* Used by scp/sftp to do public/private key authentication */
	OPT_SSH_PUBLIC_KEYFILE = 10152,
	/* Used by scp/sftp to do public/private key authentication */
	OPT_SSH_PRIVATE_KEYFILE,
	/* Send CCC (Clear Command Channel) after authentication */
	OPT_FTP_SSL_CCC = 154,
	/* Same as TIMEOUT and CONNECTTIMEOUT, but with ms resolution */
	OPT_TIMEOUT_MS,
	/* Same as TIMEOUT and CONNECTTIMEOUT, but with ms resolution */
	OPT_CONNECTTIMEOUT_MS,
	/* set to zero to disable the libcurl's decoding and thus pass the raw body
	     data to the application even when it is encoded/compressed */
	OPT_HTTP_TRANSFER_DECODING,
	/* set to zero to disable the libcurl's decoding and thus pass the raw body
	     data to the application even when it is encoded/compressed */
	OPT_HTTP_CONTENT_DECODING,
	/* Permission used when creating new files and directories on the remote
	     server for protocols that support it, SFTP/SCP/FILE */
	OPT_NEW_FILE_PERMS,
	/* Permission used when creating new files and directories on the remote
	     server for protocols that support it, SFTP/SCP/FILE */
	OPT_NEW_DIRECTORY_PERMS,
	/* Set the behavior of POST when redirecting. Values must be set to one
	     of CURL_REDIR* defines below. This used to be called CURLOPT_POST301 */
	OPT_POSTREDIR,
	/* used by scp/sftp to verify the host's public key */
	OPT_SSH_HOST_PUBLIC_KEY_MD5 = 10162,
	/* Callback function for opening socket (instead of socket(2)). Optionally,
	     callback is able change the address or refuse to connect returning
	     CURL_SOCKET_BAD. The callback should have type
	     curl_opensocket_callback */
	OPT_OPENSOCKETFUNCTION = 20163,
	/* Callback function for opening socket (instead of socket(2)). Optionally,
	     callback is able change the address or refuse to connect returning
	     CURL_SOCKET_BAD. The callback should have type
	     curl_opensocket_callback */
	OPT_OPENSOCKETDATA = 10164,
	/* POST volatile input fields. */
	OPT_COPYPOSTFIELDS,
	/* set transfer mode (;type=<a|i>) when doing FTP via an HTTP proxy */
	OPT_PROXY_TRANSFER_MODE = 166,
	/* Callback function for seeking in the input stream */
	OPT_SEEKFUNCTION = 20167,
	/* Callback function for seeking in the input stream */
	OPT_SEEKDATA = 10168,
	/* CRL file */
	OPT_CRLFILE,
	/* Issuer certificate */
	OPT_ISSUERCERT,
	/* (IPv6) Address scope */
	OPT_ADDRESS_SCOPE = 171,
	/* Collect certificate chain info and allow it to get retrievable with
	     CURLINFO_CERTINFO after the transfer is complete. */
	OPT_CERTINFO,
	/* "name" and "pwd" to use when fetching. */
	OPT_USERNAME = 10173,
	/* "name" and "pwd" to use when fetching. */
	OPT_PASSWORD,
	/* "name" and "pwd" to use with Proxy when fetching. */
	OPT_PROXYUSERNAME,
	/* "name" and "pwd" to use with Proxy when fetching. */
	OPT_PROXYPASSWORD,
	/* Comma separated list of hostnames defining no-proxy zones. These should
	     match both hostnames directly, and hostnames within a domain. For
	     example, local.com will match local.com and www.local.com, but NOT
	     notlocal.com or www.notlocal.com. For compatibility with other
	     implementations of this, .local.com will be considered to be the same as
	     local.com. A single * is the only valid wildcard, and effectively
	     disables the use of proxy. */
	OPT_NOPROXY,
	/* block size for TFTP transfers */
	OPT_TFTP_BLKSIZE = 178,
	/* Socks Service */
	/* DEPRECATED, do not use! */
	OPT_SOCKS5_GSSAPI_SERVICE = 10179,
	/* Socks Service */
	OPT_SOCKS5_GSSAPI_NEC = 180,
	/* set the bitmask for the protocols that are allowed to be used for the
	     transfer, which thus helps the app which takes URLs from users or other
	     external inputs and want to restrict what protocol(s) to deal
	     with. Defaults to CURLPROTO_ALL. */
	OPT_PROTOCOLS,
	/* set the bitmask for the protocols that libcurl is allowed to follow to,
	     as a subset of the CURLOPT_PROTOCOLS ones. That means the protocol needs
	     to be set in both bitmasks to be allowed to get redirected to. */
	OPT_REDIR_PROTOCOLS,
	/* set the SSH knownhost filename to use */
	OPT_SSH_KNOWNHOSTS = 10183,
	/* set the SSH host key callback, must point to a curl_sshkeycallback
	     function */
	OPT_SSH_KEYFUNCTION = 20184,
	/* set the SSH host key callback custom pointer */
	OPT_SSH_KEYDATA = 10185,
	/* set the SMTP mail originator */
	OPT_MAIL_FROM,
	/* set the list of SMTP mail receiver(s) */
	OPT_MAIL_RCPT,
	/* FTP: send PRET before PASV */
	OPT_FTP_USE_PRET = 188,
	/* RTSP request method (OPTIONS, SETUP, PLAY, etc...) */
	OPT_RTSP_REQUEST,
	/* The RTSP session identifier */
	OPT_RTSP_SESSION_ID = 10190,
	/* The RTSP stream URI */
	OPT_RTSP_STREAM_URI,
	/* The Transport: header to use in RTSP requests */
	OPT_RTSP_TRANSPORT,
	/* Manually initialize the client RTSP CSeq for this handle */
	OPT_RTSP_CLIENT_CSEQ = 193,
	/* Manually initialize the server RTSP CSeq for this handle */
	OPT_RTSP_SERVER_CSEQ,
	/* The stream to pass to INTERLEAVEFUNCTION. */
	OPT_INTERLEAVEDATA = 10195,
	/* Let the application define a custom write method for RTP data */
	OPT_INTERLEAVEFUNCTION = 20196,
	/* Turn on wildcard matching */
	OPT_WILDCARDMATCH = 197,
	/* Directory matching callback called before downloading of an
	     individual file (chunk) started */
	OPT_CHUNK_BGN_FUNCTION = 20198,
	/* Directory matching callback called after the file (chunk)
	     was downloaded, or skipped */
	OPT_CHUNK_END_FUNCTION,
	/* Change match (fnmatch-like) callback for wildcard matching */
	OPT_FNMATCH_FUNCTION,
	/* Let the application define custom chunk data pointer */
	OPT_CHUNK_DATA = 10201,
	/* FNMATCH_FUNCTION user pointer */
	OPT_FNMATCH_DATA,
	/* send linked-list of name:port:address sets */
	OPT_RESOLVE,
	/* Set a username for authenticated TLS */
	OPT_TLSAUTH_USERNAME,
	/* Set a password for authenticated TLS */
	OPT_TLSAUTH_PASSWORD,
	/* Set authentication type for authenticated TLS */
	OPT_TLSAUTH_TYPE,
	/* Set to 1 to enable the "TE:" header in HTTP requests to ask for
	     compressed transfer-encoded responses. Set to 0 to disable the use of TE:
	     in outgoing requests. The current default is 0, but it might change in a
	     future libcurl release.
	
	     libcurl will ask for the compressed methods it knows of, and if that
	     is not any, it will not ask for transfer-encoding at all even if this
	     option is set to 1.
	
	  */
	OPT_TRANSFER_ENCODING = 207,
	/* Callback function for closing socket (instead of close(2)). The callback
	     should have type curl_closesocket_callback */
	OPT_CLOSESOCKETFUNCTION = 20208,
	/* Callback function for closing socket (instead of close(2)). The callback
	     should have type curl_closesocket_callback */
	OPT_CLOSESOCKETDATA = 10209,
	/* allow GSSAPI credential delegation */
	OPT_GSSAPI_DELEGATION = 210,
	/* Set the name servers to use for DNS resolution.
	   * Only supported by the c-ares DNS backend */
	OPT_DNS_SERVERS = 10211,
	/* Time-out accept operations (currently for FTP only) after this amount
	     of milliseconds. */
	OPT_ACCEPTTIMEOUT_MS = 212,
	/* Set TCP keepalive */
	OPT_TCP_KEEPALIVE,
	/* non-universal keepalive knobs (Linux, AIX, HP-UX, more) */
	OPT_TCP_KEEPIDLE,
	/* non-universal keepalive knobs (Linux, AIX, HP-UX, more) */
	OPT_TCP_KEEPINTVL,
	/* Enable/disable specific SSL features with a bitmask, see CURLSSLOPT_* */
	OPT_SSL_OPTIONS,
	/* Set the SMTP auth originator */
	OPT_MAIL_AUTH = 10217,
	/* Enable/disable SASL initial response */
	OPT_SASL_IR = 218,
	/* Function that will be called instead of the internal progress display
	   * function. This function should be defined as the curl_xferinfo_callback
	   * prototype defines. (Deprecates CURLOPT_PROGRESSFUNCTION) */
	OPT_XFERINFOFUNCTION = 20219,
	/* The XOAUTH2 bearer token */
	OPT_XOAUTH2_BEARER = 10220,
	/* Set the interface string to use as outgoing network
	   * interface for DNS requests.
	   * Only supported by the c-ares DNS backend */
	OPT_DNS_INTERFACE,
	/* Set the local IPv4 address to use for outgoing DNS requests.
	   * Only supported by the c-ares DNS backend */
	OPT_DNS_LOCAL_IP4,
	/* Set the local IPv6 address to use for outgoing DNS requests.
	   * Only supported by the c-ares DNS backend */
	OPT_DNS_LOCAL_IP6,
	/* Set authentication options directly */
	OPT_LOGIN_OPTIONS,
	/* Enable/disable TLS NPN extension (http2 over ssl might fail without) */
	OPT_SSL_ENABLE_NPN = 225,
	/* Enable/disable TLS ALPN extension (http2 over ssl might fail without) */
	OPT_SSL_ENABLE_ALPN,
	/* Time to wait for a response to an HTTP request containing an
	   * Expect: 100-continue header before sending the data anyway. */
	OPT_EXPECT_100_TIMEOUT_MS,
	/* This points to a linked list of headers used for proxy requests only,
	     struct curl_slist kind */
	OPT_PROXYHEADER = 10228,
	/* Pass in a bitmask of "header options" */
	OPT_HEADEROPT = 229,
	/* The public key used to validate the peer public key */
	OPT_PINNEDPUBLICKEY = 10230,
	/* Path to Unix domain socket */
	OPT_UNIX_SOCKET_PATH,
	/* Set if we should verify the certificate status. */
	OPT_SSL_VERIFYSTATUS = 232,
	/* Set if we should enable TLS false start. */
	OPT_SSL_FALSESTART,
	/* Do not squash dot-dot sequences */
	OPT_PATH_AS_IS,
	/* Proxy Service Name */
	OPT_PROXY_SERVICE_NAME = 10235,
	/* Service Name */
	OPT_SERVICE_NAME,
	/* Wait/do not wait for pipe/mutex to clarify */
	OPT_PIPEWAIT = 237,
	/* Set the protocol used when curl is given a URL without a protocol */
	OPT_DEFAULT_PROTOCOL = 10238,
	/* Set stream weight, 1 - 256 (default is 16) */
	OPT_STREAM_WEIGHT = 239,
	/* Set stream dependency on another curl handle */
	OPT_STREAM_DEPENDS = 10240,
	/* Set E-xclusive stream dependency on another curl handle */
	OPT_STREAM_DEPENDS_E,
	/* Do not send any tftp option requests to the server */
	OPT_TFTP_NO_OPTIONS = 242,
	/* Linked-list of host:port:connect-to-host:connect-to-port,
	     overrides the URL's host:port (only for the network layer) */
	OPT_CONNECT_TO = 10243,
	/* Set TCP Fast Open */
	OPT_TCP_FASTOPEN = 244,
	/* Continue to send data if the server responds early with an
	   * HTTP status code >= 300 */
	OPT_KEEP_SENDING_ON_ERROR,
	/* The CApath or CAfile used to validate the proxy certificate
	     this option is used only if PROXY_SSL_VERIFYPEER is true */
	OPT_PROXY_CAINFO = 10246,
	/* The CApath directory used to validate the proxy certificate
	     this option is used only if PROXY_SSL_VERIFYPEER is true */
	OPT_PROXY_CAPATH,
	/* Set if we should verify the proxy in ssl handshake,
	     set 1 to verify. */
	OPT_PROXY_SSL_VERIFYPEER = 248,
	/* Set if we should verify the Common name from the proxy certificate in ssl
	   * handshake, set 1 to check existence, 2 to ensure that it matches
	   * the provided hostname. */
	OPT_PROXY_SSL_VERIFYHOST,
	/* What version to specifically try to use for proxy.
	     See CURL_SSLVERSION defines below. */
	OPT_PROXY_SSLVERSION,
	/* Set a username for authenticated TLS for proxy */
	OPT_PROXY_TLSAUTH_USERNAME = 10251,
	/* Set a password for authenticated TLS for proxy */
	OPT_PROXY_TLSAUTH_PASSWORD,
	/* Set authentication type for authenticated TLS for proxy */
	OPT_PROXY_TLSAUTH_TYPE,
	/* name of the file keeping your private SSL-certificate for proxy */
	OPT_PROXY_SSLCERT,
	/* type of the file keeping your SSL-certificate ("DER", "PEM", "ENG") for
	     proxy */
	OPT_PROXY_SSLCERTTYPE,
	/* name of the file keeping your private SSL-key for proxy */
	OPT_PROXY_SSLKEY,
	/* type of the file keeping your private SSL-key ("DER", "PEM", "ENG") for
	     proxy */
	OPT_PROXY_SSLKEYTYPE,
	/* password for the SSL private key for proxy */
	OPT_PROXY_KEYPASSWD,
	/* Specify which TLS 1.2 (1.1, 1.0) ciphers to use for proxy */
	OPT_PROXY_SSL_CIPHER_LIST,
	/* CRL file for proxy */
	OPT_PROXY_CRLFILE,
	/* Enable/disable specific SSL features with a bitmask for proxy, see
	     CURLSSLOPT_* */
	OPT_PROXY_SSL_OPTIONS = 261,
	/* Name of pre proxy to use. */
	OPT_PRE_PROXY = 10262,
	/* The public key in DER form used to validate the proxy public key
	     this option is used only if PROXY_SSL_VERIFYPEER is true */
	OPT_PROXY_PINNEDPUBLICKEY,
	/* Path to an abstract Unix domain socket */
	OPT_ABSTRACT_UNIX_SOCKET,
	/* Suppress proxy CONNECT response headers from user callbacks */
	OPT_SUPPRESS_CONNECT_HEADERS = 265,
	/* The request target, instead of extracted from the URL */
	OPT_REQUEST_TARGET = 10266,
	/* bitmask of allowed auth methods for connections to SOCKS5 proxies */
	OPT_SOCKS5_AUTH = 267,
	/* Enable/disable SSH compression */
	OPT_SSH_COMPRESSION,
	/* Post MIME data. */
	OPT_MIMEPOST = 10269,
	/* Time to use with the CURLOPT_TIMECONDITION. Specified in number of
	     seconds since 1 Jan 1970. */
	OPT_TIMEVALUE_LARGE = 30270,
	/* Head start in milliseconds to give happy eyeballs. */
	OPT_HAPPY_EYEBALLS_TIMEOUT_MS = 271,
	/* Function that will be called before a resolver request is made */
	OPT_RESOLVER_START_FUNCTION = 20272,
	/* User data to pass to the resolver start callback. */
	OPT_RESOLVER_START_DATA = 10273,
	/* send HAProxy PROXY protocol header? */
	OPT_HAPROXYPROTOCOL = 274,
	/* shuffle addresses before use when DNS returns multiple */
	OPT_DNS_SHUFFLE_ADDRESSES,
	/* Specify which TLS 1.3 ciphers suites to use */
	OPT_TLS13_CIPHERS = 10276,
	/* Specify which TLS 1.3 ciphers suites to use */
	OPT_PROXY_TLS13_CIPHERS,
	/* Disallow specifying username/login in URL. */
	OPT_DISALLOW_USERNAME_IN_URL = 278,
	/* DNS-over-HTTPS URL */
	OPT_DOH_URL = 10279,
	/* Preferred buffer size to use for uploads */
	OPT_UPLOAD_BUFFERSIZE = 280,
	/* Time in ms between connection upkeep calls for long-lived connections. */
	OPT_UPKEEP_INTERVAL_MS,
	/* Specify URL using CURL URL API. */
	OPT_CURLU = 10282,
	/* add trailing data just after no more data is available */
	OPT_TRAILERFUNCTION = 20283,
	/* pointer to be passed to HTTP_TRAILER_FUNCTION */
	OPT_TRAILERDATA = 10284,
	/* set this to 1L to allow HTTP/0.9 responses or 0L to disallow */
	OPT_HTTP09_ALLOWED = 285,
	/* alt-svc control bitmask */
	OPT_ALTSVC_CTRL,
	/* alt-svc cache filename to possibly read from/write to */
	OPT_ALTSVC = 10287,
	/* maximum age (idle time) of a connection to consider it for reuse
	   * (in seconds) */
	OPT_MAXAGE_CONN = 288,
	/* SASL authorization identity */
	OPT_SASL_AUTHZID = 10289,
	/* allow RCPT TO command to fail for some recipients */
	OPT_MAIL_RCPT_ALLOWFAILS = 290,
	/* the private SSL-certificate as a "blob" */
	OPT_SSLCERT_BLOB = 40291,
	/* the private SSL-certificate as a "blob" */
	OPT_SSLKEY_BLOB,
	/* the private SSL-certificate as a "blob" */
	OPT_PROXY_SSLCERT_BLOB,
	/* the private SSL-certificate as a "blob" */
	OPT_PROXY_SSLKEY_BLOB,
	/* the private SSL-certificate as a "blob" */
	OPT_ISSUERCERT_BLOB,
	/* Issuer certificate for proxy */
	OPT_PROXY_ISSUERCERT = 10296,
	/* Issuer certificate for proxy */
	OPT_PROXY_ISSUERCERT_BLOB = 40297,
	/* the EC curves requested by the TLS client (RFC 8422, 5.1);
	   * OpenSSL support via 'set_groups'/'set_curves':
	   * https://docs.openssl.org/master/man3/SSL_CTX_set1_curves/
	   */
	OPT_SSL_EC_CURVES = 10298,
	/* HSTS bitmask */
	OPT_HSTS_CTRL = 299,
	/* HSTS filename */
	OPT_HSTS = 10300,
	/* HSTS read callback */
	OPT_HSTSREADFUNCTION = 20301,
	/* HSTS read callback */
	OPT_HSTSREADDATA = 10302,
	/* HSTS write callback */
	OPT_HSTSWRITEFUNCTION = 20303,
	/* HSTS write callback */
	OPT_HSTSWRITEDATA = 10304,
	/* Parameters for V4 signature */
	OPT_AWS_SIGV4,
	/* Same as CURLOPT_SSL_VERIFYPEER but for DoH (DNS-over-HTTPS) servers. */
	OPT_DOH_SSL_VERIFYPEER = 306,
	/* Same as CURLOPT_SSL_VERIFYHOST but for DoH (DNS-over-HTTPS) servers. */
	OPT_DOH_SSL_VERIFYHOST,
	/* Same as CURLOPT_SSL_VERIFYSTATUS but for DoH (DNS-over-HTTPS) servers. */
	OPT_DOH_SSL_VERIFYSTATUS,
	/* The CA certificates as "blob" used to validate the peer certificate
	     this option is used only if SSL_VERIFYPEER is true */
	OPT_CAINFO_BLOB = 40309,
	/* The CA certificates as "blob" used to validate the proxy certificate
	     this option is used only if PROXY_SSL_VERIFYPEER is true */
	OPT_PROXY_CAINFO_BLOB,
	/* used by scp/sftp to verify the host's public key */
	OPT_SSH_HOST_PUBLIC_KEY_SHA256 = 10311,
	/* Function that will be called immediately before the initial request
	     is made on a connection (after any protocol negotiation step).  */
	OPT_PREREQFUNCTION = 20312,
	/* Data passed to the CURLOPT_PREREQFUNCTION callback */
	OPT_PREREQDATA = 10313,
	/* maximum age (since creation) of a connection to consider it for reuse
	   * (in seconds) */
	OPT_MAXLIFETIME_CONN = 314,
	/* Set MIME option flags. */
	OPT_MIME_OPTIONS,
	/* set the SSH host key callback, must point to a curl_sshkeycallback
	     function */
	OPT_SSH_HOSTKEYFUNCTION = 20316,
	/* set the SSH host key callback custom pointer */
	OPT_SSH_HOSTKEYDATA = 10317,
	/* specify which protocols that are allowed to be used for the transfer,
	     which thus helps the app which takes URLs from users or other external
	     inputs and want to restrict what protocol(s) to deal with. Defaults to
	     all built-in protocols. */
	OPT_PROTOCOLS_STR,
	/* specify which protocols that libcurl is allowed to follow directs to */
	OPT_REDIR_PROTOCOLS_STR,
	/* WebSockets options */
	OPT_WS_OPTIONS = 320,
	/* CA cache timeout */
	OPT_CA_CACHE_TIMEOUT,
	/* Can leak things, gonna exit() soon */
	OPT_QUICK_EXIT,
	/* set a specific client IP for HAProxy PROXY protocol header? */
	OPT_HAPROXY_CLIENT_IP = 10323,
	/* millisecond version */
	OPT_SERVER_RESPONSE_TIMEOUT_MS = 324,
	/* set ECH configuration */
	OPT_ECH = 10325,
	/* maximum number of keepalive probes (Linux, *BSD, macOS, etc.) */
	OPT_TCP_KEEPCNT = 326,
	/* maximum number of keepalive probes (Linux, *BSD, macOS, etc.) */
	OPT_UPLOAD_FLAGS,
	/* set TLS supported signature algorithms */
	OPT_SSL_SIGNATURE_ALGORITHMS = 10328,
	/* the last unused */
	OPT_LASTENTRY,
}

CURL_NETRC_OPTION :: enum u32 {
	/* we set a single member here, just to make sure we still provide the enum,
	     but the values to use are defined above with L suffixes */
	_NETRC_LAST = 3,
}

CURL_TLSAUTH :: enum u32 {
	/* we set a single member here, just to make sure we still provide the enum,
	     but the values to use are defined above with L suffixes */
	_TLSAUTH_LAST = 2,
}

TimeCond :: enum u32 {
	/* we set a single member here, just to make sure we still provide
	     the enum typedef, but the values to use are defined above with L
	     suffixes */
	_TIMECOND_LAST = 4,
}

mime :: distinct rawptr

mimepart :: distinct rawptr

CURLformoption :: enum u32 {
	/********* the first one is unused ************/
	FORM_NOTHING,
	/********* the first one is unused ************/
	FORM_COPYNAME,
	/********* the first one is unused ************/
	FORM_PTRNAME,
	/********* the first one is unused ************/
	FORM_NAMELENGTH,
	/********* the first one is unused ************/
	FORM_COPYCONTENTS,
	/********* the first one is unused ************/
	FORM_PTRCONTENTS,
	/********* the first one is unused ************/
	FORM_CONTENTSLENGTH,
	/********* the first one is unused ************/
	FORM_FILECONTENT,
	/********* the first one is unused ************/
	FORM_ARRAY,
	/********* the first one is unused ************/
	FORM_OBSOLETE,
	/********* the first one is unused ************/
	FORM_FILE,
	/********* the first one is unused ************/
	FORM_BUFFER,
	/********* the first one is unused ************/
	FORM_BUFFERPTR,
	/********* the first one is unused ************/
	FORM_BUFFERLENGTH,
	/********* the first one is unused ************/
	FORM_CONTENTTYPE,
	/********* the first one is unused ************/
	FORM_CONTENTHEADER,
	/********* the first one is unused ************/
	FORM_FILENAME,
	/********* the first one is unused ************/
	FORM_END,
	/********* the first one is unused ************/
	FORM_OBSOLETE2,
	/********* the first one is unused ************/
	FORM_STREAM,
	/* added in 7.46.0, provide a curl_off_t length */
	FORM_CONTENTLEN,
	/* the last unused */
	FORM_LASTENTRY,
}

/* structure to be used as parameter for CURLFORM_ARRAY */
forms :: struct {
	option: CURLformoption,
	value:  cstring,
}

/* use this for multipart formpost building */
/* Returns code for curl_formadd()
 *
 * Returns:
 * CURL_FORMADD_OK             on success
 * CURL_FORMADD_MEMORY         if the FormInfo allocation fails
 * CURL_FORMADD_OPTION_TWICE   if one option is given twice for one Form
 * CURL_FORMADD_NULL           if a null pointer was given for a char
 * CURL_FORMADD_MEMORY         if the allocation of a FormInfo struct failed
 * CURL_FORMADD_UNKNOWN_OPTION if an unknown option was used
 * CURL_FORMADD_INCOMPLETE     if the some FormInfo is not complete (or error)
 * CURL_FORMADD_MEMORY         if a curl_httppost struct cannot be allocated
 * CURL_FORMADD_MEMORY         if some allocation for string copying failed.
 * CURL_FORMADD_ILLEGAL_ARRAY  if an illegal option is used in an array
 *
 ***************************************************************************/
CURLFORMcode :: enum u32 {
	/* 1st, no error */
	_FORMADD_OK,
	_FORMADD_MEMORY,
	_FORMADD_OPTION_TWICE,
	_FORMADD_NULL,
	_FORMADD_UNKNOWN_OPTION,
	_FORMADD_INCOMPLETE,
	_FORMADD_ILLEGAL_ARRAY,
	/* libcurl was built with form api disabled */
	_FORMADD_DISABLED,
	/* last */
	_FORMADD_LAST,
}

/*
 * callback function for curl_formget()
 * The void *arg pointer will be the one passed as second argument to
 *   curl_formget().
 * The character buffer passed to it must not be freed.
 * Should return the buffer length passed to it as the argument "len" on
 *   success.
 */
formget_callback :: proc "c" (_: rawptr, _: cstring, _: uint) -> uint

/*
 * NAME curl_global_sslset()
 *
 * DESCRIPTION
 *
 * When built with multiple SSL backends, curl_global_sslset() allows to
 * choose one. This function can only be called once, and it must be called
 * *before* curl_global_init().
 *
 * The backend can be identified by the id (e.g. CURLSSLBACKEND_OPENSSL). The
 * backend can also be specified via the name parameter (passing -1 as id). If
 * both id and name are specified, the name will be ignored. If neither id nor
 * name are specified, the function will fail with CURLSSLSET_UNKNOWN_BACKEND
 * and set the "avail" pointer to the NULL-terminated list of available
 * backends.
 *
 * Upon success, the function returns CURLSSLSET_OK.
 *
 * If the specified SSL backend is not available, the function returns
 * CURLSSLSET_UNKNOWN_BACKEND and sets the "avail" pointer to a
 * NULL-terminated list of available SSL backends.
 *
 * The SSL backend can be set only once. If it has already been set, a
 * subsequent attempt to change it will result in a CURLSSLSET_TOO_LATE.
 */
ssl_backend :: struct {
	id:   sslbackend,
	name: cstring,
}

CURLsslset :: enum u32 {
	SSLSET_OK,
	SSLSET_UNKNOWN_BACKEND,
	SSLSET_TOO_LATE,
	/* libcurl was built without any SSL support */
	SSLSET_NO_BACKENDS,
}

/* info about the certificate chain, for SSL backends that support it. Asked
   for with CURLOPT_CERTINFO / CURLINFO_CERTINFO */
certinfo :: struct {
	/* number of certificates with information */
	num_of_certs: i32,
	/* for each index in this array, there is a
	                                   linked list with textual information for a
	                                   certificate in the format "name:content".
	                                   eg "Subject:foo", "Issuer:bar", etc. */
	certinfo:     ^^slist,
}

/* Information about the SSL library used and the respective internal SSL
   handle, which can be used to obtain further information regarding the
   connection. Asked for with CURLINFO_TLS_SSL_PTR or CURLINFO_TLS_SESSION. */
tlssessioninfo :: struct {
	backend:   sslbackend,
	internals: rawptr,
}

CURLINFO :: enum u32 {
	/* first, never use this */
	INFO_NONE,
	INFO_EFFECTIVE_URL = 1048577,
	INFO_RESPONSE_CODE = 2097154,
	INFO_TOTAL_TIME = 3145731,
	INFO_NAMELOOKUP_TIME,
	INFO_CONNECT_TIME,
	INFO_PRETRANSFER_TIME,
	INFO_SIZE_UPLOAD,
	INFO_SIZE_UPLOAD_T = 6291463,
	INFO_SIZE_DOWNLOAD = 3145736,
	INFO_SIZE_DOWNLOAD_T = 6291464,
	INFO_SPEED_DOWNLOAD = 3145737,
	INFO_SPEED_DOWNLOAD_T = 6291465,
	INFO_SPEED_UPLOAD = 3145738,
	INFO_SPEED_UPLOAD_T = 6291466,
	INFO_HEADER_SIZE = 2097163,
	INFO_REQUEST_SIZE,
	INFO_SSL_VERIFYRESULT,
	INFO_FILETIME,
	INFO_FILETIME_T = 6291470,
	INFO_CONTENT_LENGTH_DOWNLOAD = 3145743,
	INFO_CONTENT_LENGTH_DOWNLOAD_T = 6291471,
	INFO_CONTENT_LENGTH_UPLOAD = 3145744,
	INFO_CONTENT_LENGTH_UPLOAD_T = 6291472,
	INFO_STARTTRANSFER_TIME = 3145745,
	INFO_CONTENT_TYPE = 1048594,
	INFO_REDIRECT_TIME = 3145747,
	INFO_REDIRECT_COUNT = 2097172,
	INFO_PRIVATE = 1048597,
	INFO_HTTP_CONNECTCODE = 2097174,
	INFO_HTTPAUTH_AVAIL,
	INFO_PROXYAUTH_AVAIL,
	INFO_OS_ERRNO,
	INFO_NUM_CONNECTS,
	INFO_SSL_ENGINES = 4194331,
	INFO_COOKIELIST,
	INFO_LASTSOCKET = 2097181,
	INFO_FTP_ENTRY_PATH = 1048606,
	INFO_REDIRECT_URL,
	INFO_PRIMARY_IP,
	INFO_APPCONNECT_TIME = 3145761,
	INFO_CERTINFO = 4194338,
	INFO_CONDITION_UNMET = 2097187,
	INFO_RTSP_SESSION_ID = 1048612,
	INFO_RTSP_CLIENT_CSEQ = 2097189,
	INFO_RTSP_SERVER_CSEQ,
	INFO_RTSP_CSEQ_RECV,
	INFO_PRIMARY_PORT,
	INFO_LOCAL_IP = 1048617,
	INFO_LOCAL_PORT = 2097194,
	INFO_TLS_SESSION = 4194347,
	INFO_ACTIVESOCKET = 5242924,
	INFO_TLS_SSL_PTR = 4194349,
	INFO_HTTP_VERSION = 2097198,
	INFO_PROXY_SSL_VERIFYRESULT,
	INFO_PROTOCOL,
	INFO_SCHEME = 1048625,
	INFO_TOTAL_TIME_T = 6291506,
	INFO_NAMELOOKUP_TIME_T,
	INFO_CONNECT_TIME_T,
	INFO_PRETRANSFER_TIME_T,
	INFO_STARTTRANSFER_TIME_T,
	INFO_REDIRECT_TIME_T,
	INFO_APPCONNECT_TIME_T,
	INFO_RETRY_AFTER,
	INFO_EFFECTIVE_METHOD = 1048634,
	INFO_PROXY_ERROR = 2097211,
	INFO_REFERER = 1048636,
	INFO_CAINFO,
	INFO_CAPATH,
	INFO_XFER_ID = 6291519,
	INFO_CONN_ID,
	INFO_QUEUE_TIME_T,
	INFO_USED_PROXY = 2097218,
	INFO_POSTTRANSFER_TIME_T = 6291523,
	INFO_EARLYDATA_SENT_T,
	INFO_HTTPAUTH_USED = 2097221,
	INFO_PROXYAUTH_USED,
	INFO_LASTONE = 70,
}

closepolicy :: enum u32 {
	/* first, never use this */
	CLOSEPOLICY_NONE,
	CLOSEPOLICY_OLDEST,
	CLOSEPOLICY_LEAST_RECENTLY_USED,
	CLOSEPOLICY_LEAST_TRAFFIC,
	CLOSEPOLICY_SLOWEST,
	CLOSEPOLICY_CALLBACK,
	/* last, never use this */
	CLOSEPOLICY_LAST,
}

/* Different data locks for a single share */
lock_data :: enum u32 {
	_LOCK_DATA_NONE,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_SHARE,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_COOKIE,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_DNS,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_SSL_SESSION,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_CONNECT,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_PSL,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_HSTS,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
	   *  the locking is just made to change the internal state of the share
	   *  itself.
	   */
	_LOCK_DATA_LAST,
}

/* Different lock access types */
lock_access :: enum u32 {
	/* unspecified action */
	_LOCK_ACCESS_NONE,
	/* for read perhaps */
	_LOCK_ACCESS_SHARED,
	/* for write perhaps */
	_LOCK_ACCESS_SINGLE,
	/* never use */
	_LOCK_ACCESS_LAST,
}

lock_function :: proc "c" (_: ^CURL, _: lock_data, _: lock_access, _: rawptr)

unlock_function :: proc "c" (_: ^CURL, _: lock_data, _: rawptr)

CURLSHcode :: enum u32 {
	/* all is fine */
	SHE_OK,
	/* 1 */
	SHE_BAD_OPTION,
	/* 2 */
	SHE_IN_USE,
	/* 3 */
	SHE_INVALID,
	/* 4 out of memory */
	SHE_NOMEM,
	/* 5 feature not present in lib */
	SHE_NOT_BUILT_IN,
	/* never use */
	SHE_LAST,
}

CURLSHoption :: enum u32 {
	/* do not use */
	SHOPT_NONE,
	/* specify a data type to share */
	SHOPT_SHARE,
	/* specify which data type to stop sharing */
	SHOPT_UNSHARE,
	/* pass in a 'curl_lock_function' pointer */
	SHOPT_LOCKFUNC,
	/* pass in a 'curl_unlock_function' pointer */
	SHOPT_UNLOCKFUNC,
	/* pass in a user data pointer used in the lock/unlock
	                           callback functions */
	SHOPT_USERDATA,
	/* never use */
	SHOPT_LAST,
}

/****************************************************************************
 * Structures for querying information about the curl library at runtime.
 */
CURLversion :: enum u32 {
	/* 7.10 */
	VERSION_FIRST,
	/* 7.11.1 */
	VERSION_SECOND,
	/* 7.12.0 */
	VERSION_THIRD,
	/* 7.16.1 */
	VERSION_FOURTH,
	/* 7.57.0 */
	VERSION_FIFTH,
	/* 7.66.0 */
	VERSION_SIXTH,
	/* 7.70.0 */
	VERSION_SEVENTH,
	/* 7.72.0 */
	VERSION_EIGHTH,
	/* 7.75.0 */
	VERSION_NINTH,
	/* 7.77.0 */
	VERSION_TENTH,
	/* 7.87.0 */
	VERSION_ELEVENTH,
	/* 8.8.0 */
	VERSION_TWELFTH,
	/* never actually use this */
	VERSION_LAST,
}

version_info_data :: struct {
	/* age of the returned struct */
	age:             CURLversion,
	/* LIBCURL_VERSION */
	version:         cstring,
	/* LIBCURL_VERSION_NUM */
	version_num:     u32,
	/* OS/host/cpu/machine when configured */
	host:            cstring,
	/* bitmask, see defines below */
	features:        i32,
	/* human readable string */
	ssl_version:     cstring,
	/* not used anymore, always 0 */
	ssl_version_num: i64,
	/* human readable string */
	libz_version:    cstring,
	/* protocols is terminated by an entry with a NULL protoname */
	protocols:       ^cstring,
	/* The fields below this were added in CURLVERSION_SECOND */
	ares:            cstring,
	ares_num:        i32,
	/* This field was added in CURLVERSION_THIRD */
	libidn:          cstring,
	/* Same as '_libiconv_version' if built with HAVE_ICONV */
	iconv_ver_num:   i32,
	/* human readable string */
	libssh_version:  cstring,
	/* Numeric Brotli version
	                                  (MAJOR << 24) | (MINOR << 12) | PATCH */
	brotli_ver_num:  u32,
	/* human readable string. */
	brotli_version:  cstring,
	/* Numeric nghttp2 version
	                                   (MAJOR << 16) | (MINOR << 8) | PATCH */
	nghttp2_ver_num: u32,
	/* human readable string. */
	nghttp2_version: cstring,
	/* human readable quic (+ HTTP/3) library +
	                                  version or NULL */
	quic_version:    cstring,
	/* the built-in default CURLOPT_CAINFO, might
	                                  be NULL */
	cainfo:          cstring,
	/* the built-in default CURLOPT_CAPATH, might
	                                  be NULL */
	capath:          cstring,
	/* Numeric Zstd version
	                                  (MAJOR << 24) | (MINOR << 12) | PATCH */
	zstd_ver_num:    u32,
	/* human readable string. */
	zstd_version:    cstring,
	/* human readable string. */
	hyper_version:   cstring,
	/* human readable string. */
	gsasl_version:   cstring,
	/* These fields were added in CURLVERSION_ELEVENTH */
	/* feature_names is terminated by an entry with a NULL feature name */
	feature_names:   ^cstring,
	/* human readable string. */
	rtmp_version:    cstring,
}

/* This is the curl_ssls_export_cb callback prototype. It
 * is passed to curl_easy_ssls_export() to extract SSL sessions/tickets. */
ssls_export_cb :: proc "c" (_: ^CURL, _: rawptr, _: cstring, _: ^u8, _: uint, _: ^u8, _: uint, _: i64, _: i32, _: cstring, _: uint) -> CURLcode

@(link_prefix = "curl_")
foreign lib {
	/* curl_strequal() and curl_strnequal() are subject for removal in a future
	   release */
	strequal :: proc(s1: cstring, s2: cstring) -> i32 ---
	strnequal :: proc(s1: cstring, s2: cstring, n: uint) -> i32 ---
	/*
	 * NAME curl_mime_init()
	 *
	 * DESCRIPTION
	 *
	 * Create a mime context and return its handle. The easy parameter is the
	 * target handle.
	 */
	mime_init :: proc(easy: ^CURL) -> mime ---
	/*
	 * NAME curl_mime_free()
	 *
	 * DESCRIPTION
	 *
	 * release a mime handle and its substructures.
	 */
	mime_free :: proc(mime: mime) ---
	/*
	 * NAME curl_mime_addpart()
	 *
	 * DESCRIPTION
	 *
	 * Append a new empty part to the given mime context and return a handle to
	 * the created part.
	 */
	mime_addpart :: proc(mime: mime) -> mimepart ---
	/*
	 * NAME curl_mime_name()
	 *
	 * DESCRIPTION
	 *
	 * Set mime/form part name.
	 */
	mime_name :: proc(part: mimepart, name: cstring) -> CURLcode ---
	/*
	 * NAME curl_mime_filename()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part remote filename.
	 */
	mime_filename :: proc(part: mimepart, filename: cstring) -> CURLcode ---
	/*
	 * NAME curl_mime_type()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part type.
	 */
	mime_type :: proc(part: mimepart, mimetype: cstring) -> CURLcode ---
	/*
	 * NAME curl_mime_encoder()
	 *
	 * DESCRIPTION
	 *
	 * Set mime data transfer encoder.
	 */
	mime_encoder :: proc(part: mimepart, encoding: cstring) -> CURLcode ---
	/*
	 * NAME curl_mime_data()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part data source from memory data,
	 */
	mime_data :: proc(part: mimepart, data: cstring, datasize: uint) -> CURLcode ---
	/*
	 * NAME curl_mime_filedata()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part data source from named file.
	 */
	mime_filedata :: proc(part: mimepart, filename: cstring) -> CURLcode ---
	/*
	 * NAME curl_mime_data_cb()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part data source from callback function.
	 */
	mime_data_cb :: proc(part: mimepart, datasize: i64, readfunc: read_callback, seekfunc: seek_callback, freefunc: free_callback, arg: rawptr) -> CURLcode ---
	/*
	 * NAME curl_mime_subparts()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part data source from subparts.
	 */
	mime_subparts :: proc(part: mimepart, subparts: mime) -> CURLcode ---
	/*
	 * NAME curl_mime_headers()
	 *
	 * DESCRIPTION
	 *
	 * Set mime part headers.
	 */
	mime_headers :: proc(part: mimepart, headers: ^slist, take_ownership: i32) -> CURLcode ---
	/*
	 * NAME curl_formadd()
	 *
	 * DESCRIPTION
	 *
	 * Pretty advanced function for building multi-part formposts. Each invoke
	 * adds one part that together construct a full post. Then use
	 * CURLOPT_HTTPPOST to send it off to libcurl.
	 */
	@(deprecated = "since 7.56.0. Use curl_mime_init()")
	formadd :: proc(httppost: ^^httppost, last_post: ^^httppost, #c_vararg _: ..any) -> CURLFORMcode ---
	/*
	 * NAME curl_formget()
	 *
	 * DESCRIPTION
	 *
	 * Serialize a curl_httppost struct built with curl_formadd().
	 * Accepts a void pointer as second argument which will be passed to
	 * the curl_formget_callback function.
	 * Returns 0 on success.
	 */
	@(deprecated = "since 7.56.0. ")
	formget :: proc(form: ^httppost, arg: rawptr, append: formget_callback) -> i32 ---
	/*
	 * NAME curl_formfree()
	 *
	 * DESCRIPTION
	 *
	 * Free a multipart formpost previously built with curl_formadd().
	 */
	@(deprecated = "since 7.56.0. Use curl_mime_free()")
	formfree :: proc(form: ^httppost) ---
	/*
	 * NAME curl_getenv()
	 *
	 * DESCRIPTION
	 *
	 * Returns a malloc()'ed string that MUST be curl_free()ed after usage is
	 * complete. DEPRECATED - see lib/README.curlx
	 */
	getenv :: proc(variable: cstring) -> ^u8 ---
	/*
	 * NAME curl_version()
	 *
	 * DESCRIPTION
	 *
	 * Returns a static ASCII string of the libcurl version.
	 */
	version :: proc() -> ^u8 ---
	/*
	 * NAME curl_easy_escape()
	 *
	 * DESCRIPTION
	 *
	 * Escapes URL strings (converts all letters consider illegal in URLs to their
	 * %XX versions). This function returns a new allocated string or NULL if an
	 * error occurred.
	 */
	easy_escape :: proc(handle: ^CURL, string: cstring, length: i32) -> ^u8 ---
	/* the previous version: */
	escape :: proc(string: cstring, length: i32) -> ^u8 ---
	/*
	 * NAME curl_easy_unescape()
	 *
	 * DESCRIPTION
	 *
	 * Unescapes URL encoding in strings (converts all %XX codes to their 8bit
	 * versions). This function returns a new allocated string or NULL if an error
	 * occurred.
	 * Conversion Note: On non-ASCII platforms the ASCII %XX codes are
	 * converted into the host encoding.
	 */
	easy_unescape :: proc(handle: ^CURL, string: cstring, length: i32, outlength: ^i32) -> ^u8 ---
	/* the previous version */
	unescape :: proc(string: cstring, length: i32) -> ^u8 ---
	/*
	 * NAME curl_free()
	 *
	 * DESCRIPTION
	 *
	 * Provided for de-allocation in the same translation unit that did the
	 * allocation. Added in libcurl 7.10
	 */
	free :: proc(p: rawptr) ---
	/*
	 * NAME curl_global_init()
	 *
	 * DESCRIPTION
	 *
	 * curl_global_init() should be invoked exactly once for each application that
	 * uses libcurl and before any call of other libcurl functions.
	
	 * This function is thread-safe if CURL_VERSION_THREADSAFE is set in the
	 * curl_version_info_data.features flag (fetch by curl_version_info()).
	
	 */
	global_init :: proc(flags: i64) -> CURLcode ---
	/*
	 * NAME curl_global_init_mem()
	 *
	 * DESCRIPTION
	 *
	 * curl_global_init() or curl_global_init_mem() should be invoked exactly once
	 * for each application that uses libcurl. This function can be used to
	 * initialize libcurl and set user defined memory management callback
	 * functions. Users can implement memory management routines to check for
	 * memory leaks, check for misuse of the curl library etc. User registered
	 * callback routines will be invoked by this library instead of the system
	 * memory management routines like malloc, free etc.
	 */
	global_init_mem :: proc(flags: i64, m: malloc_callback, f: free_callback, r: realloc_callback, s: strdup_callback, c: calloc_callback) -> CURLcode ---
	/*
	 * NAME curl_global_cleanup()
	 *
	 * DESCRIPTION
	 *
	 * curl_global_cleanup() should be invoked exactly once for each application
	 * that uses libcurl
	 */
	global_cleanup :: proc() ---
	/*
	 * NAME curl_global_trace()
	 *
	 * DESCRIPTION
	 *
	 * curl_global_trace() can be invoked at application start to
	 * configure which components in curl should participate in tracing.
	
	 * This function is thread-safe if CURL_VERSION_THREADSAFE is set in the
	 * curl_version_info_data.features flag (fetch by curl_version_info()).
	
	 */
	global_trace :: proc(config: cstring) -> CURLcode ---
	global_sslset :: proc(id: sslbackend, name: cstring, avail: ^^^ssl_backend) -> CURLsslset ---
	/*
	 * NAME curl_slist_append()
	 *
	 * DESCRIPTION
	 *
	 * Appends a string to a linked list. If no list exists, it will be created
	 * first. Returns the new list, after appending.
	 */
	slist_append :: proc(list: ^slist, data: cstring) -> ^slist ---
	/*
	 * NAME curl_slist_free_all()
	 *
	 * DESCRIPTION
	 *
	 * free a previously built curl_slist.
	 */
	slist_free_all :: proc(list: ^slist) ---
	/*
	 * NAME curl_getdate()
	 *
	 * DESCRIPTION
	 *
	 * Returns the time, in seconds since 1 Jan 1970 of the time string given in
	 * the first argument. The time argument in the second parameter is unused
	 * and should be set to NULL.
	 */
	getdate :: proc(p: cstring, unused: ^i64) -> i64 ---
	share_init :: proc() -> ^CURLSH ---
	share_setopt :: proc(share: ^CURLSH, option: CURLSHoption, #c_vararg _: ..any) -> CURLSHcode ---
	share_cleanup :: proc(share: ^CURLSH) -> CURLSHcode ---
	/*
	 * NAME curl_version_info()
	 *
	 * DESCRIPTION
	 *
	 * This function returns a pointer to a static copy of the version info
	 * struct. See above.
	 */
	version_info :: proc(_: CURLversion) -> ^version_info_data ---
	/*
	 * NAME curl_easy_strerror()
	 *
	 * DESCRIPTION
	 *
	 * The curl_easy_strerror function may be used to turn a CURLcode value
	 * into the equivalent human readable error string. This is useful
	 * for printing meaningful error messages.
	 */
	easy_strerror :: proc(_: CURLcode) -> cstring ---
	/*
	 * NAME curl_share_strerror()
	 *
	 * DESCRIPTION
	 *
	 * The curl_share_strerror function may be used to turn a CURLSHcode value
	 * into the equivalent human readable error string. This is useful
	 * for printing meaningful error messages.
	 */
	share_strerror :: proc(_: CURLSHcode) -> cstring ---
	/*
	 * NAME curl_easy_pause()
	 *
	 * DESCRIPTION
	 *
	 * The curl_easy_pause function pauses or unpauses transfers. Select the new
	 * state by setting the bitmask, use the convenience defines below.
	 *
	 */
	easy_pause :: proc(handle: ^CURL, bitmask: i32) -> CURLcode ---
	/*
	 * NAME curl_easy_ssls_import()
	 *
	 * DESCRIPTION
	 *
	 * The curl_easy_ssls_import function adds a previously exported SSL session
	 * to the SSL session cache of the easy handle (or the underlying share).
	 */
	easy_ssls_import :: proc(handle: ^CURL, session_key: cstring, shmac: ^u8, shmac_len: uint, sdata: ^u8, sdata_len: uint) -> CURLcode ---
	/*
	 * NAME curl_easy_ssls_export()
	 *
	 * DESCRIPTION
	 *
	 * The curl_easy_ssls_export function iterates over all SSL sessions stored
	 * in the easy handle (or underlying share) and invokes the passed
	 * callback.
	 *
	 */
	easy_ssls_export :: proc(handle: ^CURL, export_fn: ^ssls_export_cb, userptr: rawptr) -> CURLcode ---
}
