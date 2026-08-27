# Client_API_VN - GODS Fork

> [!NOTE]
> This is a fork of [dthonon/Client_API_VN](https://github.com/dthonon/Client_API_VN).
>
>  - Custom changes are made in the `custom/main` branch.
>  - The `main` branch is kept synchronized with the upstream repository.
>  - For upstream documentation, see <https://dthonon.github.io/Client_API_VN/>.

## Overview

Python applications and API client for working with Biolovision/VisioNature (VN) databases.

This fork provides custom implementations and improvements for internal use by the *Groupe Ornithologique des Deux-Sèvres* ([GODS](https://www.ornitho79.org)).

## Features

### Base features

- **Download and Synchronize**: Transfer observation data from VN sites to PostgreSQL databases
- **Update Sightings**: Modify or delete observations directly in VN databases
- **Validate Data**: Validate downloaded data against JSON schemas
- **Python API**: Thin Python layer for direct interaction with Biolovision API
- **Scheduled Updates**: Automatic incremental updates with configurable schedules
- **Docker Support**: Pre-built Docker images available

### Custom features

#### Database & Data Model

- **INSEE Code Support**: Added `insee` field to observations tables with indexing and filtering capabilities
- **Territorial Units**: `places` and `local_admin_units` now use `territorial_units_id` short_name instead of numeric IDs
- **Case Normalization**: Standardized all keys to lowercase for consistency
- **Nullable Fields**: INSEE field properly handles `None` values by default

#### API & Transfer Enhancements

- **Territorial Unit Filtering**: Added `territorial_unit_id` parameter to update option for `observations/diff` API requests
- **SSL Mode Configuration**: Added PostgreSQL SSL connection mode support
- **Improved Error Handling**: All optional parameters properly handled with `.get()` defaults

#### Docker Improvements

- **Security**: Non-root user configuration with proper file permissions
- **Localization**: Pre-configured timezone (Europe/Paris) and French locale
- **Optimized Build**: Multi-stage build storing Python modules in `/app` folder
- **Database Tools**: PostgreSQL client and process monitoring tools (`procps`) included
- **Volume Management**: Persistent config folder with proper bind mounts

#### Configuration

- **Enhanced TOML Templates**: Fix site section with name and URL fields
- **Additional Controllers**: Added fields and species controllers in configuration files 

## Applications

This package provides three main command-line applications:

### `transfer_vn`
Download and synchronize observation data from VisioNature sites to a local PostgreSQL database. Supports both full historical downloads and incremental updates.

### `update_vn`
Bulk update or delete observations in VisioNature databases using CSV files. Handles attribute modifications and complete observation deletions.

### `validate_vn`
Validate downloaded data against JSON schemas to ensure data integrity.

## Installation

> [!NOTE]
> The Docker container requires an external PostgreSQL database.

### Docker Production Installation

The production container uses an external PostgreSQL/PostGIS database. The
database is not managed by Docker Compose. Install the site-management CLI
with `pipx`, then build the application image from the repository root:

```bash
git clone https://github.com/alexmerot/client_api_vn_gods
cd client_api_vn_gods
pipx install ./tools/vnsite
docker build -t client_api:latest .
```

Create one self-contained Compose deployment per site:

```bash
vnsite create ~/sites/faune79
```

This creates `docker-compose.yml`, `.env`, `data/`, `logs/`, and `config/` in
the selected directory. Edit `.env` and configure the external database in the
generated TOML file. Initialize that configuration with:

```bash
docker compose -f ~/sites/faune79/docker-compose.yml \
  --env-file ~/sites/faune79/.env \
  run --rm app transfer_vn --init /app/config/.env_faune79.toml
```

After editing the generated TOML file, start the site:

```bash
vnsite start ~/sites/faune79
```

The site directory's `data/`, `logs/`, and `config/` folders are bind-mounted
to `/app/VN_files`, `/app/tmp`, and `/app/config`. Daily management commands are:

```bash
vnsite stop ~/sites/faune79
vnsite restart ~/sites/faune79
vnsite logs ~/sites/faune79
```

On Windows, run `vnsite` from the Poetry environment or use the command
installed by `pipx`; no Bash, executable permission, or symlink is required.

## Documentation

- **Upstream Documentation**: <https://dthonon.github.io/Client_API_VN/>
- **Upstream Repository**: <https://github.com/dthonon/Client_API_VN>
- **API Reference**: See [biolovision.api](https://dthonon.github.io/Client_API_VN/modules/)

## Docker (development)

A `docker-compose.yml` provides a ready-to-use development stack: the CLI
(`transfer_vn`) plus a PostGIS database. On first startup, `docker/init-db.sql`
enables the PostGIS extensions and creates the `xfer38` application superuser,
mirroring the [server install guide](https://dthonon.github.io/Client_API_VN/apps/server_install/).
The postgresql container binds to port 5432. Any native postgresql service must run on different ports.

If needed, install docker, as described here : https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository.

Start the stack (add user to docker group to avoid using sudo) and create the database and tables:

```bash
docker compose up -d --build
docker compose exec app transfer_vn --db_create --json_tables_create --col_tables_create $HOME/evn.toml
```

Then run a download (requires real VN credentials, see below) or open a shell:

```bash
docker compose exec app transfer_vn --full $HOME/evn.toml   # full download
docker compose exec app transfer_vn --status $HOME/evn.toml # scheduling / status
docker compose exec app bash                          # interactive shell
```

The configuration lives in `docker/evn.toml`; its `[database]` section already
points at the `db` service. Replace the `[site.tff]` values with real Biolovision
credentials before running `--full` / `--update`. The project source is mounted
at `/code` and installed in editable mode, so host edits apply live; run
`cd /code` inside the container for `poetry` tasks. Do **not** run `pytest` from
`/code`: the tests look for their configuration upward from the current
directory, so run `pytest /code/tests` from `/root` instead — or use `make
test-integration-docker` from the host (see below).

Stop the stack with `docker compose down`, or `docker compose down -v` to also
drop the database volume (which re-runs `init-db.sql` on the next start).

## Tests

Unit tests (no external dependency) run with `make test`.

The **integration tests** exercise the live VisioNature API and a PostGIS
database. They need a running Postgres/PostGIS (the `db` service above works) and
VisioNature credentials exported in the environment:

```bash
export VN_SITE_URL=https://www.faune-xxx.org/
export VN_USER_EMAIL=... VN_USER_PW=... VN_CLIENT_KEY=... VN_CLIENT_SECRET=...
make test-integration        # renders the config, sets up the DB, runs pytest
```

`make test-integration` renders `$HOME/.evn_test.toml` from the templates in
`tests/data/*.tmpl`, creates the database and tables, then runs the suite.

To run the same suite inside the Docker dev stack instead (no local Poetry,
`psql` or `envsubst` needed — only the `VN_*` variables exported), use:

```bash
make test-integration-docker
```

It starts the stack, renders the config and prepares the database inside the
`app` container, then runs pytest from `/root` (the tests search for
`~/.evn_test.*` upward from the working directory, so they cannot be launched
from `/code`).

Most tests are site-independent (they assert only well-formed responses, or data
that is identical across VN sites such as the national list of territorial
units). Two markers control the rest:

- **`write`** — tests that create/update/delete data on the *live* site. They are
  skipped unless `VN_ENABLE_WRITE_TESTS=1` is explicitly set, so they can never run
  by accident.
- **`privileged`** — tests that need a privileged VisioNature account (full
  access to observations, observers, places — unavailable to a standard
  account). Deselected by default (`PYTEST_MARKERS="not slow and not
  privileged"`); run them with a privileged account using `make
  test-integration PYTEST_MARKERS="not slow"`.

In CI, the `Integration tests` workflow runs the standard-account suite on
every PR using the `VN_STD_*` secrets. The `privileged` tests are never run in
CI: run them locally with a privileged account.
