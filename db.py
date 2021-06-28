#!/usr/bin/env python3

import sys
from argparse import ArgumentParser
from os.path import join, dirname, realpath

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        "sub_command",
        type=str,
        choices=["import", "call", "report"],
        help="sub command to execute")
    parser_args = parser.parse_args(args[:1])

    if parser_args.sub_command == "import":
        from utils import db_import
        db_import.main(args[1:])
    elif parser_args.sub_command == "call":
        from utils import db_call
        db_call.main(args[1:])
    elif parser_args.sub_command == "report":
        from utils import db_report
        db_report.main(args[1:])

if __name__ == "__main__":
    rc = main(sys.argv[1:])
    sys.exit(rc)
