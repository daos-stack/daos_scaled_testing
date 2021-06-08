import sys
from argparse import ArgumentParser
import os
import csv
import tempfile

from .io_utils import csv_to_xlsx, print_err
from . import db_utils

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        "--config",
        default="db.cnf",
        help="database config for connection")
    parser.add_argument(
        "--list-procs",
        action="store_true",
        help="list procedures and arguments and exit")
    parser.add_argument(
        "--format",
        type=str,
        choices=("table", "csv", "xlsx"),
        default="table",
        help="output format")
    parser.add_argument(
        "-o", "--output-file",
        type=str,
        help="output file")
    parser.add_argument(
        "proc_name",
        type=str,
        nargs="?",
        help="procedure name")
    parser.add_argument(
        "proc_args",
        nargs="*",
        help="procedure arguments")
    args = parser.parse_args(args)

    if args.format == "xlsx" and not args.output_file:
        print("--output-file is required for --format xlsx")
        return 1

    if not args.proc_name and not args.list_procs:
        print("Either --list-procs or procedure name should be specified")
        parser.print_help()
        return 1

    conn = db_utils.connect(args.config)
    if not conn:
        return 1

    if args.list_procs:
        procs = db_utils.get_procedures(conn, args.proc_name)
        if not procs:
            return 1
        for proc_name in procs.keys():
            print(f"{proc_name}(")
            for proc_arg in procs[proc_name]:
                print(f"{' '*len(proc_name)} {list(proc_arg.values())}")
        return 0

    # Make sure the procedure exists and fill in missing arguments
    # with None/NULL
    procs = db_utils.get_procedures(conn, args.proc_name)
    if not procs:
        print_err(f"Procedure not found: {args.proc_name}")
        return 1
    for missing in range(len(args.proc_args), len(procs[args.proc_name])):
        args.proc_args.append(None)
    cur = db_utils.callproc(conn, args.proc_name, args.proc_args)
    if not cur:
        conn.close()
        return 0

    if args.format == "table":
        if args.output_file:
            f = open(args.output_file, 'w')
        else:
            f = sys.stdout
        # Print results to stdout in an aligned table format
        rows = [[details[0] for details in cur.description]]
        rows += list(cur)
        col_widths = [0] * len(rows[0])
        for row_idx, row in enumerate(rows):
            for col_idx, val in enumerate(row):
                col_len = len(str(val))
                if col_len > col_widths[col_idx]:
                    col_widths[col_idx] = col_len
        for row_idx, row in enumerate(rows):
            for col_idx, val in enumerate(row):
                print(f"{str(val).rjust(col_widths[col_idx])}  ", end="", file=f)
            print("", file=f)
    elif args.format == "csv":
        if args.output_file:
            f = open(args.output_file, 'w')
        else:
            f = sys.stdout
        writer = csv.writer(f)
        writer.writerow((details[0] for details in cur.description))
        for row in cur:
            writer.writerow(row)
    elif args.format == "xlsx":
        try:
            tmp = tempfile.mkstemp()
            os.close(tmp[0])
            with open(tmp[1], 'w') as f:
                writer = csv.writer(f)
                writer.writerow((details[0] for details in cur.description))
                for row in cur:
                    writer.writerow(row)
            csv_to_xlsx(tmp[1], args.output_file)
        finally:
            os.remove(tmp[1])
    conn.close()
    return 0
