#!/usr/bin/env python3

import os
from os.path import isdir, isfile, join
import subprocess
import itertools

env = os.environ

env['PATH'] = "/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:."

env['LD_LIBRARY_PATH'] = "/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/"

env['JOBNAME']     = "<sbatch_jobname>"
env['EMAIL']       = "<email>" # <first.last@email.com>
env['DAOS_DIR']    = "<path_to_daos>" # E.g. /work2/08126/dbohninx/frontera/BUILDS/latest/daos
env['DST_DIR']     = "<path_to_daos_scaled_testing>" # E.g. /scratch/TESTS/daos_scaled_testing
env['RES_DIR']     = "<path_to_result_dir>" # E.g. /home1/06753/soychan/work/POC/TESTS/dst_framework/RESULTS

# Only if using MPICH or OPENMPI
env['MPICH_DIR']   = "<path_to_mpich>" #e.g./scratch/POC/mpich
env['OPENMPI_DIR'] = "<path_to_openmpi>" #e.g./scratch/POC/openmpi

# Sanity check that directories exist
for check_dir in (env['DAOS_DIR'], env['DST_DIR']):
    if not isdir(check_dir):
        print("ERROR: Not a directory: {}".format(check_dir))
        exit(1)

# Sanity check that it's actually a DAOS installation
if not isfile(join(env['DAOS_DIR'], "../repo_info.txt")):
    print("ERROR: {} doesn't seem to be a DAOS installation".format(env['DAOS_DIR']))
    exit(1)


# TODO refactor to make 'inflight' a variant?
self_testdict = {
    'st_1tomany_cli2srv_inf1': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (2, 1, 15),
            (4, 1, 15),
            (8, 1, 15),
            (16, 1, 15),
            (32, 1, 15),
            (64, 1, 15),
            (128, 1, 15),
            (256, 1, 15),
            (512, 1, 15)
        ],
        'env_vars': {
            'inflight': 1,
            'ppc': 1
        },
        'enabled': False
    },
    'st_1tomany_cli2srv_inf16': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (2, 1, 15),
            (4, 1, 15),
            (8, 1, 15),
            (16, 1, 15),
            (32, 1, 15),
            (64, 1, 15),
            (128, 1, 15),
            (256, 1, 15),
            (512, 1, 15)
        ],
        'env_vars': {
            'inflight': 16,
            'ppc': 1
        },
        'enabled': False
    }
}

ec_partial_stripe_testdict = {
    'ec_ior_partial_stripe_EC_2P1GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 8, 5)
        ],
        'cont_rf': '1',
        'oclass': 'EC_2P1GX',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_partial_stripe_EC_4P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (6, 12, 5)
        ],
        'oclass': 'EC_4P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_partial_stripe_EC_8P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (10, 20, 5)
        ],
        'oclass': 'EC_8P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '1G',
            'fpp': '-F',
            'cont_rf': '2',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_partial_stripe_EC_16P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (18, 36, 5)
        ],
        'oclass': 'EC_16P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    }
}

ec_full_stripe_testdict = {
    'ec_ior_full_stripe_EC_2P1GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 8, 5)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_2P1GX',
        'cont_rf': '1',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '2M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_full_stripe_EC_4P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (6, 12, 5)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_4P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '4M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_full_stripe_EC_8P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (10, 20, 5)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_8P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '8M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ec_ior_full_stripe_EC_16P2GX': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (18, 36, 5)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_16P2GX',
        'cont_rf': '2',
        'env_vars': {
            'chunk_size': '33554432',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '16M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    }
}


ior_single_replica_testdict = {
    'ior_easy_S2': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 8, 5)
        ],
        'oclass': 'S2',
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '2M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ior_easy_S4': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (6, 12, 5)
        ],
        'oclass': 'S4',
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '4M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ior_easy_S8': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (410, 20, 5)
        ],
        'oclass': 'S8',
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '8M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
    'ior_easy_S16': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (18, 36, 10)
        ],
        'oclass': 'S16',
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '16M',
            'block_size': '1G',
            'fpp': '-F',
            'sw_time': '60',
            'iterations': '2',
            'ppc': 32
        },
        'enabled': False
    },
}


ior_testdict = {
    'ior_easy': {
        'oclass': [
            #'SX',
            #'RP_2GX',
            #'RP_3GX',
            #'EC_2P1GX',
            #'EC_4P1GX'
        ],
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            #(1, 4, 5),
            #(2, 8, 5),
            #(4, 16, 5),
            #(8, 32, 5),
            #(16, 64, 5),
            #(32, 128, 5),
            #(64, 256, 5),
            #(128, 512, 5),
            #(256, 1024, 5),

            # c16, (num_servers, num_clients, timeout_minutes)
            #(1, 16, 5),
            #(2, 16, 5),
            #(4, 16, 5),
            #(8, 16, 5),
            #(16, 16, 5),
            #(32, 16, 5),
            #(64, 16, 5),
            #(128, 16, 5),
            #(256, 16, 5)
        ],
        'cont_rf' : [
            #0,
            #1,
            #2
        ],
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '150G',
            'sw_time': '60',
            'iterations': '1',
            'ppc': 32
        },
        'enabled': False
    },
    'ior_hard': {
        'oclass': [
            #'SX',
            #'RP_2GX',
            #'RP_3GX',
            #'EC_2P1GX',
            #'EC_4P1GX'
        ],
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            #(1, 4, 5),
            #(2, 8, 5),
            #(4, 16, 5),
            #(8, 32, 5),
            #(16, 64, 5),
            #(32, 128, 5),
            #(64, 256, 5),
            #(128, 512, 5),
            #(256, 1024, 5),

            # c16, (num_servers, num_clients, timeout_minutes)
            #(1, 16, 5),
            #(2, 16, 5),
            #(4, 16, 5),
            #(8, 16, 5),
            #(16, 16, 5),
            #(32, 16, 5),
            #(64, 16, 5),
            #(128, 16, 5),
            #(256, 16, 5)
        ],
        'cont_rf' : [
            #0,
            #1,
            #2
        ],
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'segments': '2000000',
            'xfer_size': '47008',
            'block_size': '47008',
            'sw_time': '60',
            'iterations': '1',
            'ppc': 32
        },
        'enabled': False
    }
}


mdtest_testdict = {
    'mdtest_easy': {
        'oclass': [
            #('S1', 'SX'),
            #('RP_2G1', 'RP_2GX'),
            #('RP_3G1', 'RP_3GX')
        ],
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            #(1, 4, 5),
            #(2, 8, 5),
            #(4, 16, 5),
            #(8, 32, 5),
            #(16, 64, 5),
            #(32, 128, 5),
            #(64, 256, 5),
            #(128, 512, 5),
            #(256, 1024, 5),

            # c16, (num_servers, num_clients, timeout_minutes)
            #(1, 16, 5),
            #(2, 16, 5),
            #(4, 16, 5),
            #(8, 16, 5), # sw=50 for S1
            #(16, 16, 5),
            #(32, 16, 5),
            #(64, 16, 5),
            #(128, 16, 5),
            #(256, 16, 5)
        ],
        'cont_rf' : [
            #0,
            #1,
            #2
        ],
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'n_file': '1000000',
            'bytes_read': '0',
            'bytes_write': '0',
            'tree_depth': '0',
            'sw_time': '60', # 30 for RP_2G1, RP_3G1
            'ppc': 32
        },
        'enabled': False
    },
    'mdtest_hard': {
        'oclass': [
            #('S1', 'SX'),
            #('RP_2G1', 'RP_2GX'),
            #('RP_3G1', 'RP_3GX')
        ],
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            #(1, 4, 5),
            #(2, 8, 5),
            #(4, 16, 5),
            #(8, 32, 5),
            #(16, 64, 5),
            #(32, 128, 5),
            #(64, 256, 5),
            #(128, 512, 5),
            #(256, 1024, 5),

            # c16, (num_servers, num_clients, timeout_minutes)
            #(1, 16, 5),
            #(2, 16, 5),
            #(4, 16, 5),
            #(8, 16, 5),
            #(16, 16, 5),
            #(32, 16, 5),
            #(64, 16, 5),
            #(128, 16, 5),
            #(256, 16, 5)
        ],
        'cont_rf' : [
            #0,
            #1,
            #2
        ],
        'env_vars': {
            'chunk_size': '1048576',
            'pool_size': '85G',
            'n_file': '200000',
            'bytes_read': '3901',
            'bytes_write': '3901',
            'tree_depth': '0/20',
            'sw_time': '60', # 30 for RP_2G1, RP_3G1
            'ppc': 32
        },
        'enabled': False
    }
}


swim_testdict = {
    'rebuild_pool_single': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (2, 1, 10),
            (4, 1, 10),
            (8, 1, 10),
            (16, 1, 10),
        ],
        'env_vars': {
            'pool_size': '85G',
            'number_of_pools': '1',
            'ppc': 32
        },
        'enabled': False
    },
    'rebuild_pool_multi': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (2, 1, 15),
            (4, 1, 15),
            (8, 1, 15),
            (16, 1, 15),
        ],
        'env_vars': {
            'pool_size': '256MiB', # Minimum 16MiB per rank
            'number_of_pools': '73',
            'ppc': 32
        },
        'enabled': False
    }
}


swim_ior_testdict = {
    'pool_rebuild_50_load': {
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (8, 4, 30)
        ],
        'oclass': 'SX',
        'env_vars': {
            'pool_size': '85G',
            'number_of_pools': '1',
            'chunk_size': '1048576',
            'segments': '1',
            'xfer_size': '1M',
            'block_size': '2656M',
            'iterations': '1',
            'ppc': 32
        },
        'enabled': False
    }
}



def is_list_or_tuple(o):
    """Return True if an object is a list or tuple."""
    return isinstance(o, list) or isinstance(o, tuple)


class TestList(object):
    def __init__(self, test_group, testdict, env, script='run_sbatch.sh'):
        self._test_group = test_group
        self._testdict = testdict
        self._env = env.copy()
        self._setup_offset = 10
        self._teardown_offset = 5
        self._pool_create_timeout = 3
        self._cmd_timeout = 2
        dst_dir = os.getenv('DST_DIR')
        self._script = os.path.join(dst_dir, script)

    def _expand_default_test_params(self, test_params):
        for param, default in [
                ('oclass', ['']),
                ('ec_cell_size', ['1048576']),
                ('cont_rf', [0])]:
            # Set default value
            if param not in test_params:
                test_params[param] = default
            # Convert singular to list
            elif not is_list_or_tuple(test_params[param]):
                test_params[param] = [test_params[param]]

    def _expand_default_env_vars(self, env, testcase):
        env['TEST_GROUP'] = self._test_group
        env['TESTCASE'] = testcase
        # Default IOR will use single shared file
        env['FPP'] = ''

    def _expand_extra_env_vars(self, env, test_params):
        env_vars = test_params.get('env_vars', {})
        for name, value in env_vars.items():
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
        env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
        env['OMPI_TIMEOUT'] = str(test_timeout * 60)
        env['POOL_CREATE_TIMEOUT'] = str(self._pool_create_timeout * 60)
        env['CMD_TIMEOUT'] = str(self._cmd_timeout * 60)

    def _expand_env_oclass(self, env, oclass):
        if isinstance(oclass, str):
            env['OCLASS'] = oclass
        elif is_list_or_tuple(oclass):
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

    def _expand_env_cont_rf(self, env, cont_rf):
        env['CONT_RF'] = str(cont_rf)

    def _verify_env(self, env):
        """Check that environment vars are not incompatible."""
        # TODO easy way to verify OCLASS is compatible with num servers?
        if int(env['DAOS_SERVERS']) <= int(env['CONT_RF']):
            print(f"ERR {env['TESTCASE']}: DAOS_SERVERS <= CONT_RF "
                  f"({env['DAOS_SERVERS']} <= {env['CONT_RF']})")
            return False
        return True

    def run(self):
        # Create a list of environments, where each is a test to run
        variant_env_list = []

        for testcase in self._testdict:
            test_params = self._testdict[testcase]
            if not 'enabled' in test_params or not test_params['enabled']:
                continue

            self._expand_default_test_params(test_params)

            # Get an environment for all variants for this testcase
            testcase_env = self._env.copy()
            self._expand_default_env_vars(testcase_env, testcase)
            self._expand_extra_env_vars(testcase_env, test_params)

            for oclass, scale, ec_cell_size, cont_rf in itertools.product(
                    test_params['oclass'],
                    test_params['scale'],
                    test_params['ec_cell_size'],
                    test_params['cont_rf']):
                # Get an environment for this testcase variant
                variant_env = testcase_env.copy()
                self._expand_env_oclass(variant_env, oclass)
                self._expand_env_scale(variant_env, scale)
                self._expand_env_ec_cell_size(variant_env, ec_cell_size)
                self._expand_env_cont_rf(variant_env, cont_rf)
                if not self._verify_env(variant_env):
                    print(f"Check config. Skipping all {testcase} variants")
                    return
                variant_env_list.append(variant_env)

        for env in variant_env_list:
            print(f"Running {env['TESTCASE']} {env['OCLASS']}, "
                  f"{env['DAOS_SERVERS']} servers, {env['DAOS_CLIENTS']} clients, "
                  f"{env['EC_CELL_SIZE']} ec_ell_size, cont_rf={env['CONT_RF']}")
            subprocess.Popen(self._script, env=env)

class SelfTestList(TestList):
    def __init__(self, testdict):
        super(SelfTestList, self).__init__('SELF_TEST', testdict, env)


class IorTestList(TestList):
    def __init__(self, testdict):
        super(IorTestList, self).__init__('IOR', testdict, env)

    def _add_timeout(self, env, test_timeout):
        # ior runs twice, read and write operations are performed separately
        timeout = self._setup_offset + (test_timeout * 2) + self._teardown_offset
        h = timeout // 60
        m = timeout % 60
        s = 0
        env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
        env['OMPI_TIMEOUT'] = str(test_timeout * 60)
        env['POOL_CREATE_TIMEOUT'] = str(self._pool_create_timeout * 60)
        env['CMD_TIMEOUT'] = str(self._cmd_timeout * 60)


class MdtestTestList(TestList):
    def __init__(self, testdict):
        super(MdtestTestList, self).__init__('MDTEST', testdict, env)


class SwimTestList(TestList):
    def __init__(self, testdict):
        super(SwimTestList, self).__init__('SWIM', testdict, env)


class SwimIORTestList(TestList):
    def __init__(self, testdict):
        super(SwimIORTestList, self).__init__('SWIM_IOR', testdict, env)

def main():
    self_test = SelfTestList(self_testdict)
    self_test.run()

    ior_test = IorTestList(ior_testdict)
    ior_test.run()

    mdtest_test = MdtestTestList(mdtest_testdict)
    mdtest_test.run()

    swim_test = SwimTestList(swim_testdict)
    swim_test.run()

    swim_ior_test = SwimIORTestList(swim_ior_testdict)
    swim_ior_test.run()

    ec_full_stripe = IorTestList(ec_full_stripe_testdict)
    ec_full_stripe.run()

    ior_single_replica = IorTestList(ior_single_replica_testdict)
    ior_single_replica.run()

    ec_partial_stripe_testlist = IorTestList(ec_partial_stripe_testdict)
    ec_partial_stripe_testlist.run()    

if __name__ == '__main__':
    main()
