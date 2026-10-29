# cork-cache-n-queue in front of ckan and search

Two instances of
[`cork-cache-n-queue`](https://github.com/ucd-library/cork-cache-n-queue)
(image `us-west1-docker.pkg.dev/digital-ucdavis-edu/pub/cork-cache-n-queue`)
sit directly in front of the `ckan` and `search` containers in every
environment (local dev, dev, prod) - `ckan-cache` proxies to `ckan:5000`,
`search-cache` proxies to `search:8000`. Each publishes the same host port
its backend used to publish, so nothing downstream (Apache's `ProxyPass`
lines in `../apache/`, or a developer's bookmarked localhost URL) needs to
change - only the container answering that port does.

Each instance runs two independent gates:

- **Cache** - a local disk cache, keyed by full URL including query string.
- **Queue** - a Postgres-coordinated concurrency cap per client-IP /24 (or
  /64 for IPv6) group, rejecting bursts with `429 Retry-After: 5`.

Both gates are scoped by a JSON ruleset (see `rules/`) - a request is only
cached, or only subject to the queue, if it matches its ruleset. See the
tool's own README for the full rule-condition schema
(`target: path|header|cookie|query`, `matchType: regex|includes|startsWith|endsWith`,
`negate`).

## Why these rules

This replaces the Apache `mod_cache` mitigation previously deployed in
`../apache/mitigations/cache-data.conf` / `cache-search.conf` (see that
file's history for the original bot-mitigation incident). The cache rules in
`rules/cache-data-rules.json` and `rules/cache-search-rules.json` are a
direct port of those `.conf` files' `RewriteCond` chain: a response is
eligible to cache only if **all** of the following hold:

- path starts with one of the allowed prefixes (ckan: `/dataset/`,
  `/organization/`, `/group/`, `/webassets/`, `/base/`; search: `/search/`,
  `/package/`, `/webassets/`, `/base/`)
- no `ckan` session cookie is present (logged-in/personalized requests are
  never cached)
- no `q` query parameter is present (an actual search query, not a static
  listing page)
- the path does not contain `/user/`
- the path is not a write/management action (`new`, `edit`, `delete`,
  `member_new`, `member_delete`)

`CCNQ_CACHE_RESPECT_CACHE_CONTROL=false` on both instances - CKAN and the
search app send `Cache-Control: private` on every response, which would
otherwise make CCNQ refuse to cache anything (unlike Apache's
`CacheStorePrivate On`, CCNQ has no override for that header once
`respectCacheControl` is on). With it off, every matching response is
cached for a flat `CCNQ_CACHE_TTL_MS` (3600000 = 1 hour, matching Apache's
old `CacheDefaultExpire`/`CacheMaxExpire`). `ckan-cache` additionally sets
`CCNQ_CACHE_MAX_ITEM_SIZE_BYTES=5000000` to keep large
`/dataset/*/resource/*` downloads out of the disk cache, matching the old
`CacheMaxFileSize` in `cache-data.conf`.

The queue rules in `rules/queue-data-rules.json` / `queue-search-rules.json`
intentionally **exclude** `/webassets/` and `/base/` - those are static
CSS/JS/image paths; concurrency-limiting them would slow down every normal
page load (each page pulls many asset requests) without any bot-mitigation
benefit, since they're cheap to serve and already covered by the cache gate.

`CCNQ_QUEUE_ALLOWLIST` on both instances carries over the Googlebot ranges
already allowlisted in `../apache/mitigations/evasive.conf`'s
`DOSWhitelist`, so known-good crawlers aren't throttled by the queue either.

## Known behavior differences from the old Apache mitigation

- No `X-Cache` response header - CCNQ doesn't tag responses with hit/miss
  status. Verify via timing (a cached repeat GET returns much faster) or by
  inspecting the container's cache directory (see below).
- No admin/purge endpoint - the only way to evict the cache early is to
  restart the instance (`docker compose restart ckan-cache`) or lower
  `CCNQ_CACHE_TTL_MS`.
- Any response carrying `Set-Cookie` is never cached, unconditionally (a
  stricter version of Apache's `CacheIgnoreHeaders Set-Cookie`, which
  stripped the header but still cached the rest of the response).

## Verification

Cache - repeat a GET to an eligible path and confirm the second is faster
and a new file shows up on disk; confirm the excluded cases never populate
it:

```bash
docker compose exec ckan-cache sh -c "ls /data/cache | wc -l"
curl -sI http://localhost:${DATA_HOST_PORT:-3001}/organization/<a-real-org-slug>
curl -sI http://localhost:${DATA_HOST_PORT:-3001}/organization/<a-real-org-slug>   # should be faster
docker compose exec ckan-cache sh -c "ls /data/cache | wc -l"                      # should have grown by 1

curl -sI -b "ckan=faketoken" http://localhost:${DATA_HOST_PORT:-3001}/organization/<a-real-org-slug>
curl -sI "http://localhost:${DATA_HOST_PORT:-3001}/search/?q=grass" 2>/dev/null
curl -sI "http://localhost:${DATA_HOST_PORT:-3001}/dataset/new"
# none of the three above should move the cache file count
```

Queue - burst concurrent requests from one client against a protected path
and confirm throttling kicks in past `CCNQ_QUEUE_MAX_SERVED_PER_GROUP`
(default 1):

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:${DATA_HOST_PORT:-3001}/dataset/<a-real-dataset-slug> & done; wait
# expect some 429s once the per-IP-group cap is exceeded
```

Inspect live queue state directly in Postgres (schema name per instance,
see `CCNQ_PG_SCHEMA` in the compose file):

```sql
SELECT * FROM ckan_cache_queue.group_state;
SELECT * FROM search_cache_queue.group_state;
```

Set `CCNQ_LOG_LEVEL=debug` on either instance for verbose per-request
cache/queue decisions while debugging rule matches.
