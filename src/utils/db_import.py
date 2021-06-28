from argparse import ArgumentParser
from os.path import isfile
from csv import DictReader

from . import db_utils
from .io_utils import print_err

def import_csv(conn, csv_path, table_name, replace=False):
    '''Import a csv into the DB.

    Args:
        conn (connection): database connection object.
        csv_path (str): path the the csv file.
        table_name (str): table to insert into.
        replace (bool, optional): whether to replace existing rows
            when conflicting. Default is False.

    Returns:
        bool: True on success. False otherwise.

    '''
    valid_columns = db_utils.get_insertable_columns(conn, table_name)
    if not valid_columns:
        return False

    print(f'* Import {csv_path} -> {table_name}', flush=True)
    with open(csv_path, 'r', newline='') as csv_file:
        rows = list(DictReader(csv_file))

    # Get a list of columns in the csv that are also in the table
    csv_columns = list(rows[0].keys())
    inserted_columns = set(valid_columns) & set(csv_columns)
    discarded_columns = set(csv_columns) - set(inserted_columns)

    # Sanity check in case invalid columns are in the csv
    if discarded_columns:
        print(f'Warning: columns not found in {table_name}: {discarded_columns}')

    # Only keep the columns we are going to insert
    for row in rows:
        for key in discarded_columns:
            del row[key]

    with conn.cursor() as cur:
        if not db_utils.insert_rows(cur, rows, table_name, replace):
            conn.rollback()
            return False

    conn.commit()
    print(f'  {len(rows)} rows inserted\n', flush=True)
    return True

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        '--config',
        default='db.cnf',
        help='database config for connection')
    parser.add_argument(
        '--replace',
        action='store_true',
        default=False,
        help='whether to replace existing/conflicting rows')
    parser.add_argument(
        'table_name',
        type=str,
        help='table name to insert into')
    parser.add_argument(
        'csv_paths',
        nargs='+',
        type=str,
        help='path(s) to csv file(s) to import')
    args = parser.parse_args(args)

    csv_paths = args.csv_paths
    for csv_path in csv_paths:
        if not isfile(csv_path):
            print_err(f'CSV not found: {csv_path}')
            return 1

    with db_utils.connect(args.config) as conn:
        if not conn:
            return 1
        for csv_path in csv_paths:
            if not import_csv(conn, csv_path, args.table_name, args.replace):
                return 1

    return 0
