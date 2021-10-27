#!/usr/bin/env python3

'''
    Generate and execute test environments.
'''

import os
import sys
from argparse import ArgumentParser
from os.path import isdir, isfile, join, expandvars, abspath
from os.path import splitext, dirname, basename
from importlib import import_module
import subprocess
import itertools

env = os.environ

env['PATH'] = "/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:."

env['LD_LIBRARY_PATH'] = "/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/"

env['JOBNAME']     = "<sbatch_jobname>"
env['EMAIL']       = "<email>" # <first.last@email.com>
env['DAOS_DIR']    = abspath(expandvars("${WORK}/BUILDS/latest/daos")) # Path to daos
env['DST_DIR']     = abspath(expandvars("../")) # Path to daos_scaled_testing repo
env['RES_DIR']     = abspath(expandvars("${WORK}/RESULTS")) # Path to test results

env['MPI_TARGET']  = "mvapich2" # mvapich2, openmpi, mpich

# Only if using MPICH or OPENMPI
env['MPICH_DIR']   = abspath(expandvars("${WORK}/TOOLS/mpich")) # Path to locally built mpich
env['OPENMPI_DIR'] = abspath(expandvars("${WORK}/TOOLS/openmpi")) # Path to locall build openmpi

def main(args):
    '''Run a test list.'''
    parser = ArgumentParser()
    parser.add_argument(
        '--recurse', '-r',
        default=False,
        action='store_true',
        help='recurse on directories')
    parser.add_argument(
        '--filter',
        default="",
        type=str,
        help='filter test cases. Space means OR. Comma means AND.\
              E.g. --filter "oclass=SX,daos_servers=1 daos_servers=2,daos_clients=16"')
    parser.add_argument(
        '--dryrun',
        action='store_true',
        help='print tests to be ran, but do not run.')
    parser.add_argument(
        'config',
        nargs='+',
        type=str,
        help='path(s) to python config files')
    parser.add_argument('--jobname',  type=str, help='environment JOBNAME')
    parser.add_argument('--email',    type=str, help='environment EMAIL')
    parser.add_argument('--daos_dir', type=str, help='environment DAOS_DIR')
    parser.add_argument('--dst_dir',  type=str, help='environment DST_DIR')
    parser.add_argument('--res_dir',  type=str, help='environment RES_DIR')
    parser_args = parser.parse_args(args)

    param_filter_s = parser_args.filter
    param_filters = []
    for _filter in param_filter_s.split(' '):
        _filter = _filter.strip()
        if len(_filter) == 0:
            continue
        this_filter = {}
        for _condition in _filter.split(','):
            if not _condition:
                continue
            name_val = _condition.split('=')
            if len(name_val) != 2:
                print(f'Invalid filter format. Expected <name>=<val>: {_condition}')
                return 1
            name, val = name_val
            if not name or not val:
                print(f'Invalid filter format. Expected <name>=<val>: {_condition}')
                return 1
            this_filter[name] = val
        param_filters.append(this_filter)

    if parser_args.jobname:
        env['JOBNAME'] = parser_args.jobname
    if parser_args.email:
        env['EMAIL'] = parser_args.email
    if parser_args.daos_dir:
        env['DAOS_DIR'] = abspath(parser_args.daos_dir)
    if parser_args.dst_dir:
        env['DST_DIR'] = abspath(parser_args.dst_dir)
    if parser_args.res_dir:
        env['RES_DIR'] = abspath(parser_args.res_dir)

    if not _verify_env(env):
        return 1

    tests = _import_paths(parser_args.config, parser_args.recurse)
    if tests is None:
        return 1

    test_list = TestList(tests, env)
    test_list.run(param_filters, parser_args.dryrun)
    return 0


class TestList(object):
    def __init__(self, testlist, env, script='frontera/run_sbatch.sh'):
        self._testlist = testlist
        self._env = env.copy()
        self._setup_offset = 4
        self._teardown_offset = 5
        dst_dir = os.getenv('DST_DIR')
        self._script = join(dst_dir, script)

    def _expand_default_test_params(self, test_params):
        for param, default in [
                ('oclass', ['']),
                ('ec_cell_size', ['1048576'])]:
            if param not in test_params:
                # Set default value
                test_params[param] = default
            else:
                if not _is_list_or_tuple(test_params[param]):
                    # Convert singular to list
                    test_params[param] = [test_params[param]]
                if not test_params[param]:
                    # Set empty list to default value
                    test_params[param] = default

    def _expand_default_env_vars(self, env, test_params):
        env['TESTCASE'] = test_params.get('test_name')
        env['TEST_GROUP'] = test_params.get('test_group')
        # Default IOR will use single shared file
        env['FPP'] = ''
        env_vars = test_params.get('env_vars', {})
        for name, value in env_vars.items():
            if value is None:
                raise ValueError(f"None-type env_var found for {env['TESTCASE']}")
            env[name.upper()] = str(value)

    def _add_partition(self, env, nodes):
        if nodes <= 2:
            env['PARTITION'] = 'small'
        elif nodes <= 512:
            env['PARTITION'] = 'normal'
        else:
            env['PARTITION'] = 'large'

    def _add_timeout(self, env, test_timeout):
        timeout = self._setup_offset + test_timeout + self._teardown_offset
        h = timeout // 60
        m = timeout % 60
        s = 0
        env['TIMEOUT'] = str(h) + ':' + str(m) + ':' + str(s)
        env['OMPI_TIMEOUT'] = str(test_timeout * 60)

    def _expand_env_oclass(self, env, oclass):
        if isinstance(oclass, str):
            env['OCLASS'] = oclass
        elif _is_list_or_tuple(oclass):
            env['OCLASS'] = oclass[0]
            env['DIR_OCLASS'] = oclass[1]
        else:
            raise ValueError

    def _expand_env_scale(self, env, scale):
        srv, cli, timeout = scale

        nodes = srv + cli + 1
        cores = nodes * int(env['PPC'])

        env['DAOS_SERVERS'] = str(srv)
        env['DAOS_CLIENTS'] = str(cli)
        env['NNODE'] = str(nodes)
        env['NCORE'] = str(cores)

        self._add_partition(env, nodes)
        self._add_timeout(env, timeout)

    def _expand_env_ec_cell_size(self, env, ec_cell_size):
        env['EC_CELL_SIZE'] = str(ec_cell_size)

    def _env_contains(self, env, param_filter):
        '''Determine whether an environment contains some dictionary values.

        Args:
            env (dict): environment dictionary.
            param_filter (dict): dictionary of test parameters to filter by.

        Returns:
            bool: True if the env contains all dictionary values.
                False otherwise.

        '''
        for key, val in param_filter.items():
            key = key.upper()
            if key not in env:
                return False
            if env[key] != val:
                return False
        return True

    def run(self, param_filters=[], dryrun=False):
        '''Run the test list.

        Args:
            param_filters (list/dict, optional): list of dictionaries of test parameters to filter by.
                Default is [], which runs all tests.
            dryrun (bool, optional): if True, print tests to be ran, but do not run.
                Default is False.

        '''
        # Create a list of environments, where each is a test to run
        variant_env_list = []

        for test_params in self._testlist:
            if not 'enabled' in test_params or not test_params['enabled']:
                continue

            self._expand_default_test_params(test_params)

            # Get an environment for all variants for this testcase
            testcase_env = self._env.copy()
            self._expand_default_env_vars(testcase_env, test_params)

            for oclass, scale, ec_cell_size in itertools.product(
                    test_params['oclass'],
                    test_params['scale'],
                    test_params['ec_cell_size']):
                # Get an environment for this testcase variant
                variant_env = testcase_env.copy()
                self._expand_env_oclass(variant_env, oclass)
                self._expand_env_scale(variant_env, scale)
                self._expand_env_ec_cell_size(variant_env, ec_cell_size)
                variant_env_list.append(variant_env)

        idx = 1
        for env in variant_env_list:
            do_skip = False
            for param_filter in param_filters:
                do_skip = True
                if self._env_contains(env, param_filter):
                    do_skip = False
                    break
            if do_skip:
                continue
            print(f"{idx:03}. Running {env['TESTCASE']} {env['OCLASS']}, "
                  f"{env['DAOS_SERVERS']} servers, {env['DAOS_CLIENTS']} clients, "
                  f"{env['EC_CELL_SIZE']} ec_ell_size")
            idx += 1
            if not dryrun:
                subprocess.Popen(self._script, env=env)

def _is_list_or_tuple(o):
    """Return True if an object is a list or tuple."""
    return isinstance(o, list) or isinstance(o, tuple)

def _verify_env(env):
    '''Verify env vars are valid.'''
    # Sanity check that directories exist
    for check_dir in (env['DAOS_DIR'], env['DST_DIR']):
        if not isdir(check_dir):
            print("ERROR: Not a directory: {}".format(check_dir))
            return False

    # Sanity check that it's actually a DAOS installation
    if not isfile(join(env['DAOS_DIR'], 'install/bin/daos')):
        print("ERROR: {} doesn't seem to be a DAOS installation".format(env['DAOS_DIR']))
        return False

    # Sanity check MPI target is valid
    if not env['MPI_TARGET'] in ('mvapich2', 'openmpi', 'mpich'):
        print("ERROR: invalid MPI_TARGET {}".format(env['MPI_TARGET']))
        return False

    return True

def _import_paths(paths, recurse=False):
    '''Import tests from a list of paths.

    Args:
        paths (list): list of paths to python file to import tests from.
        recurse (bool): whether to recursively import from directories.
            Default is False.

    Returns:
        list: list of imported tests.
            None on failure.

    '''
    if not _is_list_or_tuple(paths):
        paths = [paths]

    all_tests = []

    for path in paths:
        if '__pycache__' in path:
            continue

        if isdir(path):
            if not recurse:
                print(f'Skipping directory {path}')
                continue
            for sub_path in os.listdir(path):
                tests = _import_paths(join(path, sub_path), recurse)
                if tests is None:
                    print(f'Failed to import tests from {path}')
                    return None
                all_tests += tests
            continue

        if not path.endswith('.py'):
            print(f'Skipping non-python path: {path}')
            continue

        print(f'Importing tests from {path}')
        try:
            # Remove file extension
            _path = splitext(path)[0]

            # Temporarily point sys.path to ONLY the directory containing this file
            old_path = sys.path
            sys.path = [dirname(path)]

            # Import this file and the tests
            package = import_module(basename(_path))
            all_tests += package.tests

            # Uncache the module and revert sys.path
            sys.modules.pop(basename(_path))
            sys.path = old_path
        except Exception as e:
            print(e)
            print(f'Failed to import tests from {path}')
            return None

    return all_tests

if __name__ == '__main__':
    rc = main(sys.argv[1:])
    sys.exit(rc)
