/* First param name equals the type; second param also needs that type. */
struct curl_httppost {
	int x;
};

int curl_formadd(struct curl_httppost **httppost, struct curl_httppost **last_post);
