def post_fork(server, worker):
    # --preload loads the app (and opens a DB connection) once in the master
    # process before forking; without this, every worker inherits and fights
    # over that single connection. Dispose it here so each worker gets its own.
    from ckan.model import meta
    meta.engine.dispose()
