from argparse import ArgumentParser
from os.path import isfile
from csv import DictReader

from . import db_utils
from .io_utils import print_err

def delete_csv(conn, table_name, key, csv_path):
    '''Import a csv into the DB.

    Args:
        conn (connection): database connection object.
        table_name (str): table to delete from.
        key (str): column name to match.
        csv_path (str): path the the csv file to extract key from.

    Returns:
        bool: True on success. False otherwise.

    '''
    valid_columns = db_utils.get_insertable_columns(conn, table_name)
    if not valid_columns:
        return False

    print(f'* Delete {csv_path} -> {table_name}', flush=True)
    with open(csv_path, 'r', newline='') as csv_file:
        rows = list(DictReader(csv_file))

    # Get a list of all key values to delete
    values = list((row[key] for row in rows))

    with conn.cursor() as cur:
        if not db_utils.delete_rows(cur, table_name, key, values):
            conn.rollback()
            return False

    conn.commit()
    print(f'  {len(rows)} rows deleted\n', flush=True)
    return True

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        '--config',
        default='db.cnf',
        help='database config for connection')
    parser.add_argument(
        'table_name',
        type=str,
        help='table name to delete from')
    parser.add_argument(
        '--key',
        type=str,
        default='slurm_job_id',
        help='column name to match on')
    parser.add_argument(
        'csv_paths',
        nargs='+',
        type=str,
        help='path(s) to csv file(s) to delete')
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
            if not delete_csv(conn, args.table_name, args.key, csv_path):
                return 1

    return 0
