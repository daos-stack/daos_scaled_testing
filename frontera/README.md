# daos_scaled_testing/frontera
This directory contains execution scripts for Frontera.

## Usage
See [DAOS on Frontera](https://daosio.atlassian.net/wiki/spaces/DC/pages/4866835913/DAOS+on+Frontera)
for documentation on how to use these scripts.

## Version Compatibility
Not all versions of these scripts are compatible with all versions of DAOS.
It may be necessary to use a specific commit when building or running tests
against an older version of DAOS.

| DAOS Commit   | Newest Compatible Script Commit          | Notes        |
| ------------- | ---------------------------------------- | ------------ |
| master        | master                                   |              |
| v2.0.2        | master                                   |              |
| v2.0.1        | master                                   |              |
| v2.0.0        | master                                   |              |
| v1.3.106-tb   | master                                   |              |
| v1.3.105-tb   | d4afa5fe2150a5a25ad0a1f78cbe685b78a7b4d1 | Need new IOR for label support |
| v1.3.104-tb   | d4afa5fe2150a5a25ad0a1f78cbe685b78a7b4d1 | Need new IOR for label support |
| v1.3.103-tb   | d4afa5fe2150a5a25ad0a1f78cbe685b78a7b4d1 | Need new IOR for label support |
| v1.3.102-tb   | 9dc82ffad5394ef0fac70bdc6563adbae58d522c |              |
| v1.3.101-tb   | 9dc82ffad5394ef0fac70bdc6563adbae58d522c |              |
| v1.2.0        | 9dc82ffad5394ef0fac70bdc6563adbae58d522c |              |
