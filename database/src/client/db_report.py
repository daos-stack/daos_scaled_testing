from argparse import ArgumentParser, RawDescriptionHelpFormatter

from .io_utils import list_to_output_type, print_err
from . import db_utils
from .sql_query_generator import SQLQuery
from . import reports as report_funs


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
        '\tbasic      - IOR/MDTest easy/hard 1to4/c16 SX/S1 compared for two commits',
        '',
        '\tec         - IOR/MDTest easy/hard EC_* compared for two commits',
        '\ts_ec       - IOR/MDTest easy/hard equivalent S* compared to EC_* oclasses',
        '',
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
        help='comma-separated list of report(s) to generate')
    parser.add_argument(
        '--base-commit',
        type=str,
        help='baseline commit for comparison')
    parser.add_argument(
        '--commit',
        type=str,
        help='commit to report on')
    parser.add_argument(
        '--rf', # TODO unused??
        type=str,
        default='%',
        help='redundancy/replication factor')
    parser.add_argument(
        'kv',
        nargs='*',
        type=str,
        help='col=val pairs for report arguments')
    args = parser.parse_args(args)

    reports = args.report.split(',')
    all_reports = ('basic', 'ec', 's_ec', 'rebuild')
    if 'all' in reports:
        reports = list(all_reports)
    for _report in reports:
        if _report not in all_reports:
            print_err(f'Invalid report: {_report}')
            return 1

    # Parse KV args for report args
    try:
        where = SQLQuery.kv_to_where(args.kv)
    except Exception as error:
        print_err(error)
        return 1

    # Generate a list of procedure calls.
    calls = []

    def _commit_test_oclass_args(prefix, commit1, commit2, test_case1, test_case2, oclass1):
        return [
            [f'{prefix}1.daos_commit', commit1, '='],
            [f'{prefix}2.daos_commit', commit2, '='],
            [f'{prefix}1.test_case', test_case1, '='],
            [f'{prefix}2.test_case', test_case2, '='],
            [f'{prefix}1.oclass', oclass1, '=']]

    def _ior_commit_test_oclass_args(*args, **kwargs):
        return _commit_test_oclass_args('ior', *args, **kwargs)

    def _mdtest_commit_test_oclass_args(*args, **kwargs):
        return _commit_test_oclass_args('mdtest', *args, **kwargs)

    if 'basic' in reports:
        if not check_required(args, 'base_commit', 'commit'):
            return 1

        calls += [
            ['ior_easy_1to4_SX', 'report_compare_ior_1to4', _ior_commit_test_oclass_args(
                args.base_commit, args.commit, '%easy%', '%easy%', 'SX')],
            ['ior_easy_c16_SX', 'report_compare_ior_c16', _ior_commit_test_oclass_args(
                args.base_commit, args.commit, '%easy%', '%easy%', 'SX')],
            ['ior_hard_1to4_SX', 'report_compare_ior_1to4', _ior_commit_test_oclass_args(
                args.base_commit, args.commit, '%hard%', '%hard%', 'SX')],
            ['ior_hard_c16_SX', 'report_compare_ior_c16', _ior_commit_test_oclass_args(
                args.base_commit, args.commit, '%hard%', '%hard%', 'SX')],
            ['mdtest_easy_1to4_SX', 'report_compare_mdtest_easy_1to4', _mdtest_commit_test_oclass_args(
                args.base_commit, args.commit, '%easy%', '%easy%', 'S1')],
            ['mdtest_easy_c16_SX', 'report_compare_mdtest_easy_c16', _mdtest_commit_test_oclass_args(
                args.base_commit, args.commit, '%easy%', '%easy%', 'S1')],
            ['mdtest_hard_1to4_SX', 'report_compare_mdtest_hard_1to4', _mdtest_commit_test_oclass_args(
                args.base_commit, args.commit, '%hard%', '%hard%', 'S1')],
            ['mdtest_hard_c16_SX', 'report_compare_mdtest_hard_c16', _mdtest_commit_test_oclass_args(
                args.base_commit, args.commit, '%hard%', '%hard%', 'S1')],
        ]

    if 'ec' in reports:
        if not check_required(args, 'base_commit', 'commit', 'rf'):
            return 1

        if args.rf == '%':
            rfs = ['1', '2']
        else:
            rfs = [args.rf]
        for rf in rfs:
            calls += [
                [f'ior_easy_EC_%P{rf}GX', 'report_compare_ior_ec', _ior_commit_test_oclass_args(
                    args.base_commit, args.commit, '%easy%', '%easy%', f'EC_%P{rf}GX')],
                [f'ior_hard_EC_%P{rf}GX', 'report_compare_ior_ec', _ior_commit_test_oclass_args(
                    args.base_commit, args.commit, '%hard%', '%hard%', f'EC_%P{rf}GX')],
                [f'mdtest_easy_EC_%P{rf}GX', 'report_compare_mdtest_easy_ec', _mdtest_commit_test_oclass_args(
                    args.base_commit, args.commit, '%easy%', '%easy%', f'EC_%P{rf}G1')],
                [f'mdtest_hard_EC_%P{rf}GX', 'report_compare_mdtest_hard_ec', _mdtest_commit_test_oclass_args(
                    args.base_commit, args.commit, '%hard%', '%hard%', f'EC_%P{rf}G1')],
            ]

    if 's_ec' in reports:
        raise Exception('TODO Report s_ec needs to be converted')
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
        raise Exception('TODO Report rebuild needs to be converted')
        if not check_required(args, 'commit'):
            return 1

        calls += [
            [f'rebuild_{args.commit}', 'show_rebuild', [args.commit]]]

    # Get data rows for each procedure call
    data = []
    sheet_names = []
    cur = None
    try:
        with db_utils.connect(args) as conn:
            for sheet_name, report_fun, extra_where in calls:
                with conn.cursor() as cur:
                    report_fun = getattr(report_funs, report_fun)
                    sql, values = report_fun(where + extra_where, bind_pattern=db_utils._cur_placeholder(cur))
                    db_utils.execute(cur, sql, values)
                    data.append(list(db_utils.cur_iter(cur)))
                    sheet_names.append(sheet_name)
            if not list_to_output_type(args, data, data_dims=2, xlsx_sheet_names=sheet_names):
                raise Exception('TODO list_to_output_type failed')
    except Exception as error:
        print_err(error)
        return 1

    return 0
