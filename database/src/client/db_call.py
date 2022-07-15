import sys
from argparse import ArgumentParser
import os
import csv
import tempfile

from .io_utils import csv_to_xlsx, print_err, print_arr_tabular
from . import io_utils
from . import db_utils

def main(args):
    '''Call a database procedure.'''
    parser = ArgumentParser()
    db_utils.add_config_args(parser)
    parser.add_argument(
        '--list-procs',
        action='store_true',
        help='list procedures and arguments and exit')
    parser.add_argument(
        '--format',
        type=str,
        choices=('table', 'csv', 'xlsx'),
        default='table',
        help='output format')
    parser.add_argument(
        '-o', '--output-file',
        type=str,
        help='output file')
    parser.add_argument(
        'proc_name',
        type=str,
        nargs='?',
        help='procedure name')
    parser.add_argument(
        'proc_args',
        nargs='*',
        help='procedure arguments')
    args = parser.parse_args(args)

    if args.format == 'xlsx' and not args.output_file:
        print('--output-file is required for --format xlsx')
        return 1

    if not args.proc_name and not args.list_procs:
        print('Either --list-procs or procedure name must be specified')
        parser.print_help()
        return 1

    with db_utils.connect(args) as conn:
        if args.list_procs:
            procs = db_utils.get_procedures(conn, args.proc_name)
            if not procs:
                return 1
            for proc_name, proc_args in procs.items():
                print(f'{proc_name}(')
                for proc_arg in proc_args:
                    print(f'{" "*len(proc_name)} {proc_arg}')
            return 0

        # Make sure the procedure exists and fill in missing arguments
        # with None/NULL
        procs = db_utils.get_procedures(conn, args.proc_name)
        if not procs:
            print_err(f'Procedure not found: {args.proc_name}')
            return 1
        # TODO fix this!!
        # for _ in range(len(args.proc_args), len(procs[args.proc_name])):
        #     args.proc_args.append(None)
        cur = db_utils.callproc(conn, args.proc_name, args.proc_args)
        if not cur:
            return 0

        rows = db_utils.cur_iter(cur)

        if args.format == 'table':
            if args.output_file:
                f = open(args.output_file, 'w')
            else:
                f = sys.stdout
            print_arr_tabular(rows, file=f)
        elif args.format == 'csv':
            if args.output_file:
                f = open(args.output_file, 'w')
            else:
                f = sys.stdout
            writer = csv.writer(f)
            writer.writerows(rows)
        elif args.format == 'xlsx':
            try:
                tmp = tempfile.mkstemp()
                os.close(tmp[0])
                io_utils.list_to_csv(rows, tmp[1])
                io_utils.csv_to_xlsx(tmp[1], args.output_file, group_by_csv=True)
            finally:
                os.remove(tmp[1])
    return 0
