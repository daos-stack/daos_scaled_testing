from argparse import ArgumentParser
from os.path import isfile
import subprocess

from . import db_utils


def main(args):
    parser = ArgumentParser()
    db_utils.add_config_args(parser)
    parser.add_argument(
        '-u', '--user',
        help='user to login with')
    parser.add_argument(
        '-D', '--database',
        help='database to use')
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
