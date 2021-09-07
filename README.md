# daos_scaled_testing
This repo contains execution scripts for Frontera.

## Usage
See [DAOS on Frontera](https://daosio.atlassian.net/wiki/spaces/DC/pages/4866835913/DAOS+on+Frontera)
for documentation on how to use these scripts.

## Database
View the [Database README](README_database.md) for database usage.

## Version Compatibility
Not all versions of this repo are compatible with all versions of DAOS.
It may be necessary to use a specific commit when building or running tests
against an older version of DAOS.

| DAOS Commit   | Newest Compatible Script Commit |
| ------------- | ------------------------------- |
| master        | master |
| v1.3.105-tb   | master |
| v1.3.104-tb   | master |
| v1.3.103-tb   | master |
| v1.3.102-tb   | 9dc82ffad5394ef0fac70bdc6563adbae58d522c  |
| v1.3.101-tb   | 9dc82ffad5394ef0fac70bdc6563adbae58d522c  |
| v1.2.0        | 9dc82ffad5394ef0fac70bdc6563adbae58d522c  |
