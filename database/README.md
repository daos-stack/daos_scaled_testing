# Storing and retrieving results in the database

## DB install
```
sudo mkdir /mnt/mariadb/
sudo mount -t tmpfs -o size=10g mariadb /mnt/mariadb
sudo mkdir /mnt/mariadb/lib
sudo mkdir /mnt/mariadb/log
sudo chown mysql:mysql /mnt/mariadb/
sudo chown mysql:mysql /mnt/mariadb/lib/
sudo chown mysql:mysql /mnt/mariadb/log/
sudo systemctl start mariadb
mysql_secure_installation --socket=/mnt/mariadb/lib/mysql.sock
```

## Initial Setup
### Schema
The initial schema is contained in [./src/sql](./src/sql).

!!! note
    If the database already exists, it will be dropped and re-created.
    This should only be ran a single time.

### Config
`db.cnf` should be updated with the server host and port, as well as the username and password used to connect.

!!! note
    This will be made more secure in the future.

## Database tools
`db.py` contains several tools for interacting with the database.
Run `db.py --help` for a list of these tools.

### Importing data
Import expects a CSV where the first row is column names, and the rest are treated as
data rows. To import some IOR results:
```
./db.py import results_ior my_ior_results.csv
```
To override existing rows with the data:
```
./db.py import --replace results_ior my_ior_results.csv
```
It is recommended to also store any data that should be persisted in the [./raw](./raw) directory:
```
./raw/
      frontera_performance/
                           results_ior/
                           results_mdtest/
```
During the instability phase, this will ensure the data can be re-imported if the database is rebuilt.

### Re-importing data
Re-importing data overwrites the existing rows in the database with the CSVs in the [./raw](./raw) directory.
However, this does not delete any other rows. To re-import all data in the [./raw](./raw) directory:
```
./db.py re-import
```
Or, to import for a specific table:
```
./db.py re-import --table_name results_ior
```

### Calling database procedures
Several database procedures exist for common queries. To see these, run:
```
./db.py call --list
```
To execute a procedure:
```
./db.py call compare_ior_1to4 "ior_easy%" SX RP_2GX NULL
```

### Canned Reports
A canned report is just a group of common database procedure calls. To see the available reports, run:
```
./db.py report --help
```

### Deleting Data
All data from a given CSV can be deleted by running:
```
./db.py delete results_ior my_ior_results.csv
```

### Logging into the Database
```
./db.py login
```
