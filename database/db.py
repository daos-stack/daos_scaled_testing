#!/usr/bin/env python3

'''
    Wrapper for database tools.
'''

import sys
from argparse import ArgumentParser, RawDescriptionHelpFormatter
from importlib import import_module

def main(args):
    '''Execute a database-related utility.'''

    description = [
        'Tools',
        '\timport    - import CSV files into the database',
        '\tre-import - re-import CSV files from the data directory',
        '\tdelete    - delete CSV files from the database',
        '\tcall      - call a database procedure',
        '\treport    - generate a canned report',
        '\tlogin     - login to the database',
        '\tinit      - initialize/rebuild the database',
    ]
    parser = ArgumentParser(
        formatter_class=RawDescriptionHelpFormatter,
        description="\n".join(description))
    parser.add_argument(
        'tool',
        type=str,
        choices=['import', 're-import', 'delete', 'call', 'report', 'login', 'init'])
    parser_args = parser.parse_args(args[:1])

    package_name = {
        'import': 'db_import',
        're-import': 'db_re_import',
        'delete': 'db_delete',
        'call': 'db_call',
        'report': 'db_report',
        'login': 'db_login',
        'init': 'db_init'
    }.get(parser_args.tool)
    package = import_module(f'.{package_name}', 'src.client')
    return package.main(args[1:])

if __name__ == '__main__':
    rc = main(sys.argv[1:])
    sys.exit(rc)
