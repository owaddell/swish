# Apt Archive

## Overview and Caveats

This example is a trivial HTTP proxy for use with APT's `HTTP::proxy` configuration.
The intent is to cache the requested data for later use offline. Therefore, the proxy:

1. *ignores cache expiration*,
2. ignores the client's `If-Modified-Since` header, and
3. accumulates a growing archive of requested files.

The proxy does not evict files from the cache, and it assumes that a file present in the cache satisfies the request as long as the path matches.

**Note** this means that `apt update` will continue to return the original
package lists. It will not show package updates unless one explicitly clears
that part of the cache. In theory one might delete the dist directories
identified by `find <archive> -type d -name dists` so that `apt update`
might fetch fresh package lists when run against the proxy.

In theory one might use the `timestamp` and `path` from the `http_request` table
in data/Log.db3 to determine how recently a client has requested a particular
path and use that in some way to prune stale entries from the cache. For now,
this remains out of scope.

If the client's apt sources specify HTTPS URIs, apt may try to tunnel through
the HTTP proxy via CONNECT, which prevents caching. In some cases, changing the
scheme to HTTP in /etc/apt/sources.list and /etc/apt/sources.list.d may convince
apt to call GET on the proxy which can then handle a redirect to HTTPS via curl
yet cache the resulting file.

## Building

1. install [Swish](https://github.com/becls/swish)
2. `make`

For help using the proxy, see the output of `./apt-archive --help`.

