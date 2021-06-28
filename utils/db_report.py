import sys
from argparse import ArgumentParser
import os
from os.path import join, isdir
from os import mkdir
import csv

from .io_utils import csv_to_xlsx, print_err, list_to_csv
from . import db_utils

def main(args):
    parser = ArgumentParser()
    parser.add_argument(
        "--config",
        default="db.cnf",
        help="database config for connection")
    parser.add_argument(
        "--tests",
        type=str,
        default="all",
        help="comma-separated list of tests (all,ior,mdtest)")
    parser.add_argument(
        "--baseline-oclass",
        type=str,
        help="baseline commit for comparison")
    parser.add_argument(
        "--oclass",
        type=str,
        required=True,
        help="oclass to report on")
    parser.add_argument(
        "--baseline-commit",
        type=str,
        help="baseline commit for comparison")
    parser.add_argument(
        "--commit",
        type=str,
        required=True,
        help="commit to report on")
    parser.add_argument(
        "-o", "--output-dir",
        type=str,
        required=True,
        help="output directory")
    args = parser.parse_args(args)

    all_tests = ["ior", "mdtest"]
    tests = args.tests.split(",")
    if "all" in tests:
        tests = all_tests
    else:
        for test in tests:
            if test not in all_tests:
                print_err(f"invalid test: {test}")
                return 1

    if isdir(args.output_dir):
        print_err(f"output directory already exists: {args.output_dir}")
        return 1
    mkdir(args.output_dir)

    conn = db_utils.connect(args.config)
    if not conn:
        return 1

    csv_list = []

    if "ior" in tests:
        cur = db_utils.callproc(conn, "compare_ior_1to4", ["ior_easy%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "ior_easy_1to4.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_ior_c16", ["ior_easy%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "ior_easy_c16.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_ior_1to4", ["ior_hard%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "ior_hard_1to4.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_ior_c16", ["ior_hard%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "ior_hard_c16.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

    if "mdtest" in tests:
        cur = db_utils.callproc(conn, "compare_mdtest_1to4", ["mdtest_easy%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "mdtest_easy_1to4.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_mdtest_c16", ["mdtest_easy%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "mdtest_easy_c16.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_mdtest_1to4", ["mdtest_hard%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "mdtest_hard_1to4.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

        cur = db_utils.callproc(conn, "compare_mdtest_c16", ["mdtest_hard%", args.baseline_oclass, args.oclass, args.baseline_commit, args.commit])
        if not cur:
            return 1
        csv_path = join(args.output_dir, "mdtest_hard_c16.csv")
        if not list_to_csv(db_utils.cur_iter(cur), csv_path):
            return 1
        csv_list.append(csv_path)
        cur.close()

    conn.close()

    if not csv_to_xlsx(csv_list, join(args.output_dir, "report.xlsx"), group_by_csv=True):
        return 1

    return 0
