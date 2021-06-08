# Storing and retrieving results in the database

## Initial Setup
### Schema
The initial schema is created with `utils/init_db.sql`. This will create the database, tables, and procedures.

!!! note
    If the database already exists, it will be dropped and re-created.
    This should only be ran a single time.

### Config
`db.cnf` should be updated with the server host and port, as well as the username and password used to connect.

!!! note
    This will be made more secure in the future.

### Utilities
Database utilities are defined in `utils/db_*.py`. `db.py` is a wrapper to interact with these tools.

## Importing a CSV
`db_import.py` will allow you to generically import a CSV file into a table.
The CSV header (first row) should be the column names in the table, and all other rows are the
VALUES to be inserted.
For example:
```
./db.py import <table_name> <csv_name1> [<csv_name2> ...]
```

## Calling Procedures
`db_call.py` is a wrapper for calling database procedures, which exist for common queries.
To get a list of these procedures:
```
./db.py call --list
```
To execute a procedure:
```
./db.py call compare_ior_1to4 "ior_easy%" SX RP_2GX NULL
```
