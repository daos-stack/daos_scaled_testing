from argparse import ArgumentParser
from os.path import isfile
import subprocess


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
        help='database to use')
    parser.add_argument(
        '-p', '--password',
        action='store_true',
        help='prompt for password')
    args = parser.parse_args(args)

    if args.config and not isfile(args.config):
        print(f'Config not found: {args.config}')
        return 1

    cmd = 'mysql'

    # This must be the first option
    if args.config:
        cmd += f' --defaults-extra-file={args.config}'
    if args.user:
        cmd += f' -u {args.user}'
    if args.database:
        cmd += f' -D {args.database}'
    if args.password:
        cmd += f' -p'

    cmd += ' --show-warnings'

    print(cmd)
    return subprocess.run(cmd, shell=True).returncode
