import sys
from argparse import ArgumentParser, RawDescriptionHelpFormatter
import os
from os.path import join, isdir
from os import mkdir
import csv

from .io_utils import csv_to_xlsx, print_err, list_to_csv
from . import db_utils

def check_required(args, *check_args):
    for required_arg in check_args:
        if not getattr(args, required_arg):
            print_err(f'--{required_arg.replace("_", "-")} is required for report {args.report}')
            return False
    return True


def main(args):
    description = [
        'Generate canned database reports.',
        '',
        '\tbasic      - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared for two commits',
        '\tbasic_repl - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared to RP_*GX/RP_*G1',
        '\tbasic_rf   - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared to RF1+ oclasses',
        '',
        '\trebuild    - Rebuild for a specific commit'
    ]
    parser = ArgumentParser(
        formatter_class=RawDescriptionHelpFormatter,
        description='\n'.join(description))
    parser.add_argument(
        '--config',
        default='db.cnf',
        help='database config for connection')
    parser.add_argument(
        'report',
        choices=['basic', 'basic_repl', 'basic_rf', 'rebuild'],
        help='the report to generate')
    parser.add_argument(
        '-o', '--output-dir',
        type=str,
        required=True,
        help='output directory')
    parser.add_argument(
        '--base-commit',
        type=str,
        help='baseline commit for comparison')
    parser.add_argument(
        '--commit',
        type=str,
        help='commit to report on')
    parser.add_argument(
        '--rf',
        type=str,
        help='redundancy/replication factor')
    args = parser.parse_args(args)

    if isdir(args.output_dir):
        print_err(f'output directory already exists: {args.output_dir}')
        return 1

    if args.report == 'basic':
        if not check_required(args, 'base_commit', 'commit'):
            return 1

        calls = [
            ['ior_easy_1to4_SX.csv',    'compare_ior_1to4',    ['ior_easy%', 'SX', 'SX', args.base_commit, args.commit]],
            ['ior_easy_c16_SX.csv',     'compare_ior_c16',     ['ior_easy%', 'SX', 'SX', args.base_commit, args.commit]],
            ['ior_hard_1to4_SX.csv',    'compare_ior_1to4',    ['ior_hard%', 'SX', 'SX', args.base_commit, args.commit]],
            ['ior_hard_c16_SX.csv',     'compare_ior_c16',     ['ior_hard%', 'SX', 'SX', args.base_commit, args.commit]],
            ['mdtest_easy_1to4_S1.csv', 'compare_mdtest_1to4', ['mdtest_easy%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_easy_c16_S1.csv',  'compare_mdtest_c16',  ['mdtest_easy%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_hard_1to4_S1.csv', 'compare_mdtest_1to4', ['mdtest_hard%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_hard_1to4_S1.csv', 'compare_mdtest_1to4', ['mdtest_hard%', 'S1', 'S1', args.base_commit, args.commit]]]

    elif args.report == 'basic_repl':
        if not check_required(args, 'commit', 'rf'):
            return 1

        if not args.base_commit:
            args.base_commit = args.commit

        r = args.rf
        calls = [
            [f'ior_easy_1to4_RP_{r}GX.csv',    'compare_ior_1to4',    ['ior_easy%', 'SX', f'RP_{r}GX', args.base_commit, args.commit]],
            [f'ior_easy_c16_RP_{r}GX.csv',     'compare_ior_c16',     ['ior_easy%', 'SX', f'RP_{r}GX', args.base_commit, args.commit]],
            [f'ior_hard_1to4_RP_{r}GX.csv',    'compare_ior_1to4',    ['ior_hard%', 'SX', f'RP_{r}GX', args.base_commit, args.commit]],
            [f'ior_hard_c16_RP_{r}GX.csv',     'compare_ior_c16',     ['ior_hard%', 'SX', f'RP_{r}GX', args.base_commit, args.commit]],
            [f'mdtest_easy_1to4_RP_{r}GX.csv', 'compare_mdtest_1to4', ['mdtest_easy%', 'S1', f'RP_{r}G1', args.base_commit, args.commit]],
            [f'mdtest_easy_c16_RP_{r}GX.csv',  'compare_mdtest_c16',  ['mdtest_easy%', 'S1', f'RP_{r}G1', args.base_commit, args.commit]],
            [f'mdtest_hard_1to4_RP_{r}GX.csv', 'compare_mdtest_1to4', ['mdtest_hard%', 'S1', f'RP_{r}G1', args.base_commit, args.commit]],
            [f'mdtest_hard_c16_RP_{r}GX.csv',  'compare_mdtest_c16',  ['mdtest_hard%', 'S1', f'RP_{r}G1', args.base_commit, args.commit]]]

    elif args.report == 'basic_rf':
        if not check_required(args, 'commit', 'rf'):
            return 1

        if not args.base_commit:
            args.base_commit = args.commit

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        calls = []
        for rf in rfs:
            repl = str(int(rf) + 1)
            calls += [
                [f'ior_easy_1to4_rf{rf}_sx_vs_ec',      'compare_ior_1to4',    ['ior_easy%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_easy_c16_rf{rf}_sx_vs_ec',       'compare_ior_c16',     ['ior_easy%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_hard_1to4_rf{rf}_sx_vs_ec',      'compare_ior_1to4',    ['ior_hard%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_hard_c16_rf{rf}_sx_vs_ec',       'compare_ior_c16',     ['ior_hard%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_1to4_rf{rf}_sx_vs_ec',   'compare_mdtest_1to4', ['mdtest_easy%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_easy_c16_rf{rf}_sx_vs_ec',    'compare_mdtest_c16',  ['mdtest_easy%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_1to4_rf{rf}_sx_vs_ec',   'compare_mdtest_1to4', ['mdtest_hard%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_c16_rf{rf}_sx_vs_ec',    'compare_mdtest_c16',  ['mdtest_hard%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'ior_easy_1to4_rf{rf}_sx_vs_repl',      'compare_ior_1to4',    ['ior_easy%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_easy_c16_rf{rf}_sx_vs_repl',       'compare_ior_c16',     ['ior_easy%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_1to4_rf{rf}_sx_vs_repl',      'compare_ior_1to4',    ['ior_hard%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_c16_rf{rf}_sx_vs_repl',       'compare_ior_c16',     ['ior_hard%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_1to4_rf{rf}_sx_vs_repl',   'compare_mdtest_1to4', ['mdtest_easy%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_easy_c16_rf{rf}_sx_vs_repl',    'compare_mdtest_c16',  ['mdtest_easy%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_1to4_rf{rf}_sx_vs_repl',   'compare_mdtest_1to4', ['mdtest_hard%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_c16_rf{rf}_sx_vs_repl',    'compare_mdtest_c16',  ['mdtest_hard%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]]]
        calls += [
            [f'ior_easy_1to4_rf{rf}_s128_vs_sx',      'compare_ior_c16',    ['ior_easy%', 'S128', f'SX', args.base_commit, args.commit]]]


    elif args.report == 'rebuild':
        if not check_required(args, 'commit'):
            return 1

        calls = [
            [f'rebuild_{args.commit}.csv', 'show_rebuild', [args.commit]]]

    # Create a CSV for each procedure call
    with db_utils.connect(args.config) as conn:
        if not conn:
            return 1
        csv_list = []
        mkdir(args.output_dir)
        for csv_name, proc_name, proc_args in calls:
            print(' '.join([f'{csv_name}:'] + [proc_name] + proc_args))
            with db_utils.callproc(conn, proc_name, proc_args) as cur:
                if not cur:
                    return 1
                csv_path = join(args.output_dir, csv_name)
                if not list_to_csv(db_utils.cur_iter(cur), csv_path):
                    return 1
                csv_list.append(csv_path)

    # Add all CSVs to XLSX
    if not csv_to_xlsx(csv_list, join(args.output_dir, f'report_{args.report}.xlsx'), group_by_csv=True):
        return 1

    return 0
