#!/usr/bin/env python3

'''
    Wrapper for database tools.
'''

import sys
from argparse import ArgumentParser
from os.path import join, dirname, realpath

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        'sub_command',
        type=str,
        choices=['import', 're-import', 'delete', 'call', 'report', 'login', 'init'],
        help='sub command to execute')
    parser_args = parser.parse_args(args[:1])

    if parser_args.sub_command == 'import':
        from src.utils import db_import
        return db_import.main(args[1:])
    elif parser_args.sub_command == 're-import':
        from src.utils import db_re_import
        return db_re_import.main(args[1:])
    elif parser_args.sub_command == 'delete':
        from src.utils import db_delete
        return db_delete.main(args[1:])
    elif parser_args.sub_command == 'call':
        from src.utils import db_call
        return db_call.main(args[1:])
    elif parser_args.sub_command == 'report':
        from src.utils import db_report
        return db_report.main(args[1:])
    elif parser_args.sub_command == 'login':
        from src.utils import db_login
        return db_login.main(args[1:])
    elif parser_args.sub_command == 'init':
        from src.utils import db_init
        return db_init.main(args[1:])

if __name__ == '__main__':
    rc = main(sys.argv[1:])
    sys.exit(rc)
