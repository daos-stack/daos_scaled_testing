import sys
from argparse import ArgumentParser, RawDescriptionHelpFormatter
import os
from os.path import join, isdir
from os import mkdir
import csv

from .io_utils import csv_to_xlsx, list_to_output_type, print_err, list_to_csv
from . import db_utils


def check_required(args, *check_args):
    for required_arg in check_args:
        if not getattr(args, required_arg):
            print_err(
                f'--{required_arg.replace("_", "-")} is required for report {args.report}')
            return False
    return True


def main(args):
    description = [
        'Generate canned database reports.',
        '',
        '\tsimple      - IOR/MDTest easy/hard 1to4/c16 SX/S1 with no comparison',
        '\tsimple_ec   - IOR/MDTest easy/hard EC with no comparison',
        '',
        '\tbasic      - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared for two commits',
        '\tbasic_repl - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared to RP_*GX/RP_*G1',
        '\tbasic_rf   - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared to RF1+ oclasses',
        '',
        '\tec         - IOR/MDTest easy/hard EC_* compared for two commits',
        '\ts_ec       - IOR/MDTest easy/hard equivalent S* compared to EC_* oclasses',
        '\trebuild    - Rebuild for a specific commit'
    ]
    parser = ArgumentParser(
        formatter_class=RawDescriptionHelpFormatter,
        description='\n'.join(description))
    db_utils.add_config_args(parser)
    db_utils.add_output_args(parser)
    parser.add_argument(
        'report',
        type=str,
        help='comma-separated list of report(s) to generate (basic, basic_repl, basic_rf, rebuild)')
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
        default='%',
        help='redundancy/replication factor')
    args = parser.parse_args(args)

    reports = args.report.split(',')
    all_reports = ('simple', 'simple_ec', 'basic', 'basic_repl', 'basic_rf', 'ec', 's_ec', 'rebuild')
    for r in reports:
        if r not in all_reports:
            print_err(f'Invalid report: {r}')
            return 1

    # Generate a list of procedure calls.
    # If specified, multiple reports are rolled into one.
    calls = []

    if 'simple' in reports:
        if not check_required(args, 'commit'):
            return 1

        calls += [
            ['ior_easy_1to4_SX',        'simple_ior_1to4',    [
                'ior_easy%', 'SX', args.commit]],
            ['ior_easy_c16_SX',         'simple_ior_c16',     [
                'ior_easy%', 'SX', args.commit]],
            ['ior_hard_1to4_SX',        'simple_ior_1to4',    [
                'ior_hard%', 'SX', args.commit]],
            ['ior_hard_c16_SX',         'simple_ior_c16',     [
                'ior_hard%', 'SX', args.commit]],
            ['mdtest_easy_1to4_S1',     'simple_mdtest_1to4', [
                'mdtest_easy%', 'S1', args.commit]],
            ['mdtest_easy_c16_S1',      'simple_mdtest_c16',  [
                'mdtest_easy%', 'S1', args.commit]],
            ['mdtest_hard_1to4_S1',     'simple_mdtest_1to4', [
                'mdtest_hard%', 'S1', args.commit]],
            ['mdtest_hard_c16_S1',      'simple_mdtest_c16',  [
                'mdtest_hard%', 'S1', args.commit]]]

    if 'simple_ec' in reports:
        if not check_required(args, 'commit', 'rf'):
            return 1

        calls += [
            [f'ior_easy_EC_rf{args.rf}', 'simple_ior',
                ['ior_easy%', f'EC_%P{args.rf}%', args.commit, 'NULL']],
            [f'ior_hard_EC_rf{args.rf}', 'simple_ior',
                ['ior_hard%', f'EC_%P{args.rf}%', args.commit, 'NULL']],
            [f'mdtest_easy_EC_rf{args.rf}', 'simple_mdtest',
                ['mdtest_easy%', f'EC_%P{args.rf}%', args.commit, 'NULL']],
            [f'mdtest_hard_EC_rf{args.rf}', 'simple_mdtest',
                ['mdtest_hard%', f'EC_%P{args.rf}%', args.commit, 'NULL']]]

    if 'basic' in reports:
        if not check_required(args, 'base_commit', 'commit'):
            return 1

        calls += [
            ['ior_easy_1to4_SX',        'compare_ior_1to4',    [
                'ior_easy%', 'SX', 'SX', args.base_commit, args.commit]],
            ['ior_easy_c16_SX',         'compare_ior_c16',     [
                'ior_easy%', 'SX', 'SX', args.base_commit, args.commit]],
        # ]
            ['ior_hard_1to4_SX',        'compare_ior_1to4',    [
                'ior_hard%', 'SX', 'SX', args.base_commit, args.commit]],
            ['ior_hard_c16_SX',         'compare_ior_c16',     [
                'ior_hard%', 'SX', 'SX', args.base_commit, args.commit]],
            ['mdtest_easy_1to4_S1',     'compare_mdtest_1to4', [
                'mdtest_easy%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_easy_c16_S1',      'compare_mdtest_c16',  [
                'mdtest_easy%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_hard_1to4_S1',     'compare_mdtest_1to4', [
                'mdtest_hard%', 'S1', 'S1', args.base_commit, args.commit]],
            ['mdtest_hard_c16_S1',      'compare_mdtest_c16',  [
                'mdtest_hard%', 'S1', 'S1', args.base_commit, args.commit]],

            ['ior_easy_1to4_RP_2GX',    'compare_ior_1to4',    [
                'ior_easy%', 'RP_2GX', 'RP_2GX', args.base_commit, args.commit]],
            ['ior_easy_c16_RP_2GX',     'compare_ior_c16',     [
                'ior_easy%', 'RP_2GX', 'RP_2GX', args.base_commit, args.commit]],
            ['ior_hard_1to4_RP_2GX',    'compare_ior_1to4',    [
                'ior_hard%', 'RP_2GX', 'RP_2GX', args.base_commit, args.commit]],
            ['ior_hard_c16_RP_2GX',     'compare_ior_c16',     [
                'ior_hard%', 'RP_2GX', 'RP_2GX', args.base_commit, args.commit]],
            ['mdtest_easy_1to4_RP_2G1', 'compare_mdtest_1to4', [
                'mdtest_easy%', 'RP_2G1', 'RP_2G1', args.base_commit, args.commit]],
            ['mdtest_easy_c16_RP_2G1',  'compare_mdtest_c16',  [
                'mdtest_easy%', 'RP_2G1', 'RP_2G1', args.base_commit, args.commit]],
            ['mdtest_hard_1to4_RP_2G1', 'compare_mdtest_1to4', [
                'mdtest_hard%', 'RP_2G1', 'RP_2G1', args.base_commit, args.commit]],
            ['mdtest_hard_c16_RP_2G1',  'compare_mdtest_c16',  [
                'mdtest_hard%', 'RP_2G1', 'RP_2G1', args.base_commit, args.commit]],

            ['ior_easy_1to4_RP_3GX',    'compare_ior_1to4',    [
                'ior_easy%', 'RP_3GX', 'RP_3GX', args.base_commit, args.commit]],
            ['ior_easy_c16_RP_3GX',     'compare_ior_c16',     [
                'ior_easy%', 'RP_3GX', 'RP_3GX', args.base_commit, args.commit]],
            ['ior_hard_1to4_RP_3GX',    'compare_ior_1to4',    [
                'ior_hard%', 'RP_3GX', 'RP_3GX', args.base_commit, args.commit]],
            ['ior_hard_c16_RP_3GX',     'compare_ior_c16',     [
                'ior_hard%', 'RP_3GX', 'RP_3GX', args.base_commit, args.commit]],
            ['mdtest_easy_1to4_RP_3G1', 'compare_mdtest_1to4', [
                'mdtest_easy%', 'RP_3G1', 'RP_3G1', args.base_commit, args.commit]],
            ['mdtest_easy_c16_RP_3G1',  'compare_mdtest_c16',  [
                'mdtest_easy%', 'RP_3G1', 'RP_3G1', args.base_commit, args.commit]],
            ['mdtest_hard_1to4_RP_3G1', 'compare_mdtest_1to4', [
                'mdtest_hard%', 'RP_3G1', 'RP_3G1', args.base_commit, args.commit]],
            ['mdtest_hard_c16_RP_3G1',  'compare_mdtest_c16',  ['mdtest_hard%', 'RP_3G1', 'RP_3G1', args.base_commit, args.commit]]]

    if 'basic_repl' in reports:
        if not check_required(args, 'commit', 'rf'):
            return 1

        if not args.base_commit:
            args.base_commit = args.commit

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        for rf in rfs:
            repl = str(int(rf) + 1)
            calls += [
                [f'ior_easy_1to4_RP_{repl}GX',    'compare_ior_1to4',    [
                    'ior_easy%', 'SX', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_easy_c16_RP_{repl}GX',     'compare_ior_c16',     [
                    'ior_easy%', 'SX', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_1to4_RP_{repl}GX',    'compare_ior_1to4',    [
                    'ior_hard%', 'SX', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_c16_RP_{repl}GX',     'compare_ior_c16',     [
                    'ior_hard%', 'SX', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_1to4_RP_{repl}GX', 'compare_mdtest_1to4', [
                    'mdtest_easy%', 'S1', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_easy_c16_RP_{repl}GX',  'compare_mdtest_c16',  [
                    'mdtest_easy%', 'S1', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_1to4_RP_{repl}GX', 'compare_mdtest_1to4', [
                    'mdtest_hard%', 'S1', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_c16_RP_{repl}GX',  'compare_mdtest_c16',  ['mdtest_hard%', 'S1', f'RP_{repl}G1', args.base_commit, args.commit]]]

    if 'basic_rf' in reports:
        if not check_required(args, 'commit', 'rf'):
            return 1

        if not args.base_commit:
            args.base_commit = args.commit

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        for rf in rfs:
            repl = str(int(rf) + 1)
            calls += [
                [f'ior_easy_1to4_rf{rf}_sx_vs_ec',      'compare_ior_1to4',    [
                    'ior_easy%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_easy_c16_rf{rf}_sx_vs_ec',       'compare_ior_c16',     [
                    'ior_easy%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_hard_1to4_rf{rf}_sx_vs_ec',      'compare_ior_1to4',    [
                    'ior_hard%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_hard_c16_rf{rf}_sx_vs_ec',       'compare_ior_c16',     [
                    'ior_hard%', 'S%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_1to4_rf{rf}_sx_vs_ec',   'compare_mdtest_1to4', [
                    'mdtest_easy%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_easy_c16_rf{rf}_sx_vs_ec',    'compare_mdtest_c16',  [
                    'mdtest_easy%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_1to4_rf{rf}_sx_vs_ec',   'compare_mdtest_1to4', [
                    'mdtest_hard%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_c16_rf{rf}_sx_vs_ec',    'compare_mdtest_c16',  [
                    'mdtest_hard%', 'S%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'ior_easy_1to4_rf{rf}_sx_vs_repl',      'compare_ior_1to4',    [
                    'ior_easy%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_easy_c16_rf{rf}_sx_vs_repl',       'compare_ior_c16',     [
                    'ior_easy%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_1to4_rf{rf}_sx_vs_repl',      'compare_ior_1to4',    [
                    'ior_hard%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'ior_hard_c16_rf{rf}_sx_vs_repl',       'compare_ior_c16',     [
                    'ior_hard%', 'S%', f'RP_{repl}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_1to4_rf{rf}_sx_vs_repl',   'compare_mdtest_1to4', [
                    'mdtest_easy%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_easy_c16_rf{rf}_sx_vs_repl',    'compare_mdtest_c16',  [
                    'mdtest_easy%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_1to4_rf{rf}_sx_vs_repl',   'compare_mdtest_1to4', [
                    'mdtest_hard%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_c16_rf{rf}_sx_vs_repl',    'compare_mdtest_c16',  ['mdtest_hard%', 'S%', f'RP_{repl}G1', args.base_commit, args.commit]]]
        calls += [
            [f'ior_easy_1to4_rf{rf}_s128_vs_sx',      'compare_ior_c16',    ['ior_easy%', 'S128', f'SX', args.base_commit, args.commit]]]

    if 'ec' in reports:
        if not check_required(args, 'base_commit', 'commit', 'rf'):
            return 1

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        for rf in rfs:
            calls += [
                [f'ior_easy_EC_%P{rf}GX',    'compare_ior',    [
                    'ior_easy%', f'EC_%P{rf}GX', f'EC_%P{rf}GX', args.base_commit, args.commit, 'NULL']],
                [f'ior_hard_EC_%P{rf}GX',    'compare_ior',    [
                    'ior_hard%', f'EC_%P{rf}GX', f'EC_%P{rf}GX', args.base_commit, args.commit, 'NULL']],
                [f'mdtest_easy_EC_%P{rf}G1',    'compare_mdtest',    [
                    'mdtest_easy%', f'EC_%P{rf}G1', f'EC_%P{rf}G1', args.base_commit, args.commit, 'NULL']],
                [f'mdtest_hard_EC_%P{rf}G1',    'compare_mdtest',    [
                    'mdtest_hard%', f'EC_%P{rf}G1', f'EC_%P{rf}G1', args.base_commit, args.commit, 'NULL']],]

    if 's_ec' in reports:
        if not check_required(args, 'commit', 'rf'):
            return 1

        if not args.base_commit:
            args.base_commit = args.commit

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        for rf in rfs:
            calls += [
                [f'ior_easy_s_vs_EC_%P{rf}GX',    'compare_ior_s_ec_simple',    [
                    'ior_easy%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'ior_hard_s_vs_EC_%P{rf}GX',    'compare_ior_s_ec_simple',    [
                    'ior_hard%', f'EC_%P{rf}GX', args.base_commit, args.commit]],
                [f'mdtest_easy_s_vs_EC_%P{rf}G1',    'compare_mdtest_s_ec',    [
                    'mdtest_easy%', f'EC_%P{rf}G1', args.base_commit, args.commit]],
                [f'mdtest_hard_s_vs_EC_%P{rf}G1',    'compare_mdtest_s_ec',    [
                    'mdtest_hard%', f'EC_%P{rf}G1', args.base_commit, args.commit]]]

    if 'rebuild' in reports:
        if not check_required(args, 'commit'):
            return 1

        calls += [
            [f'rebuild_{args.commit}', 'show_rebuild', [args.commit]]]

    # Get data rows for each procedure call
    data = []
    sheet_names = []
    with db_utils.connect(args) as conn:
        for sheet_name, proc_name, proc_args in calls:
            if sheet_name in sheet_names:
                print_err(f'Duplicate sheet name: {sheet_name}')
                return 1
            print(' '.join([f'{sheet_name}:'] + [proc_name] + proc_args))
            with db_utils.callproc(conn, proc_name, proc_args) as cur:
                if not cur:
                    return 1
                d = list(db_utils.cur_iter(cur))
                if len(d) > 1:
                    sheet_names.append(sheet_name)
                    data.append(d)

    # Output all query results
    success = list_to_output_type(
        output_type=args.output_format,
        data=data,
        data_dims=2,
        xlsx_sheet_names=sheet_names,
        file=args.output_path)
    return 0 if success else 1

    # return 0
