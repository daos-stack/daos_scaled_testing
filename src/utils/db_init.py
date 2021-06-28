from argparse import ArgumentParser
from os.path import isdir, isfile, join, dirname, realpath
import subprocess

from .io_utils import print_err, confirm
from . import db_import

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        '--config',
        default='db.cnf',
        help='database config for connection')
    parser.add_argument(
        '-u', '--user',
        help='user to login with')
    parser.add_argument(
        '-D', '--database',
        default='frontera_performance',
        help='database to use')
    parser.add_argument(
        '-p', '--password',
        action='store_true',
        help='prompt for password')
    parser.add_argument(
        'level',
        choices=('soft', 'hard'),
        default='soft',
        help='soft for functions and procedures, hard for tables, etc.')
    parser.add_argument(
        '-y', '--yes',
        action='store_true',
        help='default to Yes confirmation')
    args = parser.parse_args(args)

    if args.level != 'soft':
        print_err(f'level={args.level} is not yet supported.')
        return 1

    if args.config and not isfile(args.config):
        print_err(f'Config not found: {args.config}')
        return 1

    src_dir = join(realpath(join(dirname(__file__), '..', '..')), 'src')
    sql_dir = join(src_dir, 'sql')
    common_dir = join(sql_dir, 'common')
    db_dir = join(sql_dir, args.database)

    for d in (common_dir, db_dir):
        if not isdir(d):
            print_err(f'directory not found: {d}')
            return 1

    if not args.yes and not confirm('Rebuild functions and procedures?'):
        return 1

    sql_cmd = 'mysql'

    # This must be the first option
    if args.config:
        sql_cmd += f' --defaults-extra-file={args.config}'
    if args.user:
        sql_cmd += f' -u {args.user}'
    if args.database:
        sql_cmd += f' -D {args.database}'
    if args.password:
        sql_cmd += f' -p'

    sql_cmd += ' --show-warnings'

    sql_list = [
        join(common_dir, '*.sql'),
        join(db_dir, 'procedures.sql')
    ]
    sep = ' \\\n    '
    cat_cmd = f'cat {sep.join(sql_list)}'

    cmd = f'{cat_cmd} \\\n  | {sql_cmd}'
    print(cmd)

    return subprocess.run(cmd, shell=True).returncode
