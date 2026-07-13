#include <sys/socket.h>

/* Mirrors curl's curl_sockaddr: embeds the system sockaddr by value, so an
 * incomplete struct {} stub would have the wrong size. */
struct curl_sockaddr {
	int family;
	int socktype;
	int protocol;
	unsigned int addrlen;
	struct sockaddr addr;
};
