# Runbook: upgrading CKAN 2.10.1 to 2.12.1

This upgrade ships three things together:
- CKAN 2.12.1
- the matching `ckanext-ecosis` changes
- the matching `ecosis-deployment` changes

The production database, MongoDB and the file store are upgraded in place.

## What the database upgrade does

`ckan db upgrade` runs CKAN core migrations 105 through 109. Container start runs it automatically (`containers/ckan/run.sh`), and so does `containers/ckan/restore_backup.sh`.

| Migration | Effect on existing data |
|---|---|
| 105 | Schema sync only. |
| 106 faster_extras | Copies each dataset's and group's **active** extras into a new JSONB column (`package.extras` / `group.extras`), then **drops `package_extra` and `group_extra`**. This includes the EcoSIS metadata and DOI status. |
| 107 remove_revision_data | Drops the old `*_revision` history tables. Nothing on the site uses them, because the activity plugin is not enabled. |
| 108 | Adds a unique, case-insensitive index on active users' emails. **It fails if two active users share an email**, for example `Bob@x.org` and `bob@x.org`. |
| 109 | Creates the new file-storage tables. They start empty. |

Unchanged:
- users and password hashes, so logins keep working
- API tokens, provided `JWT_SECRET` does not change
- the `user_github_info` table
- MongoDB
- uploaded files

Reset:
- **Sessions.** They move from Beaker (Redis db 1) to Flask-Session (Redis db 0, `session:` prefix), so everyone is logged out once.
- **The Solr index.** It is rebuilt from Postgres.

## 1. Rehearse locally with production data

Do this until it runs clean. Time the reindex, because that sets the length of the maintenance window.

1. Put a recent production backup zip at `ecosis-local-dev/io/ecosis_backup.zip`.
2. Regenerate the local compose file so it uses the 2.12 Solr image: `./cmds/generate-deployment-files.sh`.
3. Start with a **fresh Solr volume**. Remove the existing local `solr-data` volume first (see step 4 of the deployment below).
4. Build and start the 2.12.1 stack. Then, inside the ckan container, run:
   ```bash
   /etc/ckan/restore_backup.sh
   ```
   This cleans the DB, loads the 2.10 dump, runs `db upgrade` and `search-index rebuild`, restores Mongo, and copies the files back. That is the same sequence production goes through.
5. Check that extras migrated. Compare these counts with production:
   ```sql
   select count(*) from package where extras is not null;
   select count(*) from package where extras ? 'EcoSIS DOI Status';
   ```
6. Run the smoke tests (section 4).

## 2. Before deployment day

1. **Check for duplicate emails on current production.** The command already exists in 2.10:
   ```bash
   docker compose exec ckan ckan -c /etc/ckan/docker.ini db duplicate_emails
   ```
   Fix every duplicate it lists, by changing or deactivating one of the accounts. Otherwise migration 108 fails.
2. Build and push the images: `./cmds/build.sh`, then `./cmds/push.sh`.
3. Announce the maintenance window. Everyone will need to log in again afterwards.

## 3. Deploy

Run these on the production host, in `/opt/ecosis-deployment`.

1. **Stop writes.** Keep the databases running.
   ```bash
   docker compose stop ckan-cache ckan
   ```
2. **Back up**, then copy the zip off the server.
   ```bash
   docker compose run --rm ckan /etc/ckan/create_backup.sh
   ```
   The zip is written to `/backup/ecosis_backup.zip`, which is the `ckan-backup-data` volume.
3. **Update the deployment files.** Pull the new `ecosis-deployment`: `config.sh`, `docker-compose.yaml` and `containers/ckan/*`.
4. **Reset Solr.** The Solr data volume keeps the old core and schema, so changing the image alone is not enough. The index is fully rebuilt from Postgres, so dropping it is safe.
   ```bash
   docker compose rm -sf solr
   ```
   ```bash
   docker volume ls | grep solr-data
   ```
   ```bash
   docker volume rm ecosis-deployment_solr-data
   ```
   Use the volume name printed by the `ls` command.
5. **Start the stack.**
   ```bash
   sudo service ecosis start
   ```
   On boot, `run.sh` runs `ckan db upgrade`. If a migration fails, the ckan container exits rather than serving a half-migrated database. Check the logs:
   ```bash
   docker compose logs ckan
   ```
6. **Rebuild the search index** and confirm the DB is at the latest migration:
   ```bash
   docker compose exec ckan ckan -c /etc/ckan/docker.ini search-index rebuild
   ```
   ```bash
   docker compose exec ckan ckan -c /etc/ckan/docker.ini db version
   ```
7. **Optional: clear the old Beaker sessions.** CKAN 2.12 no longer reads them.
   ```bash
   docker compose exec redis redis-cli -n 1 FLUSHDB
   ```

## 4. Smoke tests

Watch `docker compose logs -f ckan` for tracebacks while you go through these.

- **Login.** Log in and out. Log in from the search app (`/ecosis/user/remoteLogin`). While logged out, a protected page should redirect to the login page.
- **Datasets.** Open a dataset: the notes render and the "Published / Not available in search" box shows.
- **DOI.** The DOI admin list (`/doi-admin`) shows the pending requests. A dataset with an applied DOI is viewable while logged out.
- **Workflow.** Create a dataset in `/import`. Upload and process a resource. Push it to search and confirm it appears in the search app.
- **Search.** Dataset search returns results.
- **API.** An API token in the `Authorization` header works.
- **No cookie for anonymous visitors.** None of these should return a `Set-Cookie` header:
  ```bash
  curl -s -o /dev/null -D - https://<site>/user/login | grep -i set-cookie
  ```
  ```bash
  curl -s -o /dev/null -D - https://<site>/api/3/action/status_show | grep -i set-cookie
  ```
  After logging in, the browser should have the `ckan` cookie.

## 5. Rollback

1. Stop the stack.
2. Put back the previous `config.sh` and `docker-compose.yaml`. That means CKAN 2.10.1 images and Solr `ckan/ckan-solr:2.10`.
3. Drop the Solr volume again.
4. Start the stack, then restore the pre-upgrade backup zip with `restore_backup.sh`. Put the zip at `/io/ecosis_backup.zip`, or set `ZIP_FILE`.

The migrations can technically be reversed, but restoring the backup is the supported path. Anything written after the upgrade is lost when you roll back, so make the go/no-go call quickly.
