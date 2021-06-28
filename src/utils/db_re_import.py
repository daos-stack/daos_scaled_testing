from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from os.path import isdir, join, dirname, basename, realpath
import glob

from .io_utils import print_err
from . import db_import

def main(args):
    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        '--config',
        default='db.cnf',
        help='database config for connection')
    parser.add_argument(
        '--data_dir',
        type=str,
        default=join(realpath(join(dirname(__file__), '..', '..')), 'data'),
        help='data directory to import')
    parser.add_argument(
        '--database',
        choices=['frontera_performance'],
        default='frontera_performance',
        help='database to re-import')
    parser.add_argument(
        '--table',
        type=str,
        default='*',
        help='re-import for only a specific table')
    args = parser.parse_args(args)

    if not isdir(args.data_dir):
        print_err(f'data directory not found: {args.data_dir}')
        return 1
    database_dir = join(args.data_dir, args.database)
    if not isdir(database_dir):
        print_err(f'database directory not found: {database_dir}')
        return 1

    if args.table == '*':
        table_dirs = glob.iglob(join(database_dir, '*'))
    else:
        table_dir = join(database_dir, args.table)
        if not isdir(table_dir):
            print_err(f'table directory not found: {table_dir}')
            return 1
        table_dirs = [table_dir]

    for table_dir in table_dirs:
        for csv_path in glob.iglob(join(table_dir, '*.csv')):
            table_name = basename(table_dir)
            rc = db_import.main(['--config', f'{args.config}', table_name, csv_path, '--replace'])
            if rc != 0:
                return rc

    return 0
