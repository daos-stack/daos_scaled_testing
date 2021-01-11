#!/usr/bin/python

import os
import subprocess

env = os.environ

env['PATH'] = "/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:."

env['LD_LIBRARY_PATH'] = "/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/"

env['JOBNAME']    = "<sbatch_jobname>"
env['EMAIL']      = "<email>" #<first.last@email.com>
env['DAOS_DIR']   = "<path_to_daos>" #/scratch/BUILDS/latest/daos
env['DST_DIR']    = "<path_to_daos_scaled_testing>" #/scratch/TESTS/daos_scaled_testing
env['RES_DIR']    = "<path_to_result_dir>" #/home1/06753/soychan/work/POC/TESTS/dst_framework/RESULTS
env['MPICH_DIR']  = "<path_to_mpich>" #e.g./scratch/POC/mpich
env['OPENMPI_DIR']= "<path_to_openmpi>" #e.g./scratch/POC/openmpi


self_testlist = [{'testcase': 'st_1tomany_cli2srv_inf1',
                  # Number of servers, number of clients, timeout in minutes
                  'testvariants': [
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
                  'ppc': 1,
                  'env_vars': {
                      'inflight': 1
                  },
                  'enabled': False
                  },
                 {'testcase': 'st_1tomany_cli2srv_inf16',
                  # Number of servers, number of clients, timeout in minutes
                  'testvariants': [
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
                  'ppc': 1,
                  'env_vars': {
                      'inflight': 16
                  },
                  'enabled': False
                  }
                 ]

ior_testlist = [{'testcase': 'ior_easy_1to4_sx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'SX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_easy_c16_sx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'SX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_easy_1to4_2gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'RP_2GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_easy_c16_2gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'RP_2GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_easy_1to4_3gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'RP_3GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_easy_c16_3gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '1',
                     'xfer_size': '1M',
                     'block_size': '1G',
                     'oclass': 'RP_3GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_1to4_sx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'SX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_c16_sx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'SX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_1to4_2gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'RP_2GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_c16_2gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'RP_2GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_1to4_3gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 8, 15),
                     (4, 16, 15),
                     (8, 32, 15),
                     (16, 64, 15),
                     (32, 128, 20),
                     (64, 256, 20),
                     (128, 512, 20),
                     (256, 1024, 20)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'RP_3GX'
                 },
                 'enabled': False
                 },
                {'testcase': 'ior_hard_c16_3gx',
                 # Number of servers, number of clients, timeout in minutes
                 'testvariants': [
                     (2, 16, 15),
                     (4, 16, 15),
                     (8, 16, 15),
                     (16, 16, 15),
                     (32, 16, 15),
                     (64, 16, 15),
                     (128, 16, 15),
                     (256, 16, 15)
                 ],
                 'ppc': 32,
                 'env_vars': {
                     'pool_size': '85G',
                     'segments': '2000000',
                     'xfer_size': '47008',
                     'block_size': '47008',
                     'oclass': 'RP_3GX'
                 },
                 'enabled': False
                 }
                ]


mdtest_testlist = [{'testcase': 'mdtest_easy_1to4_sx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 8, 15),
                        (4, 16, 15),
                        (8, 32, 15),
                        (16, 64, 15),
                        (32, 128, 15),
                        (64, 256, 15),
                        (128, 512, 20),
                        (256, 1024, 20)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'SX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_easy_c16_sx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 16, 15),
                        (4, 16, 15),
                        (8, 16, 15),
                        (16, 16, 15),
                        (32, 16, 15),
                        (64, 16, 15),
                        (128, 16, 15),
                        (256, 16, 15)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'SX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_easy_1to4_2gx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 8, 15),
                        (4, 16, 15),
                        (8, 32, 15),
                        (16, 64, 15),
                        (32, 128, 15),
                        (64, 256, 15),
                        (128, 512, 20),
                        (256, 1024, 20)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'RP_2GX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_easy_c16_2gx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 16, 15),
                        (4, 16, 15),
                        (8, 16, 15),
                        (16, 16, 15),
                        (32, 16, 15),
                        (64, 16, 15),
                        (128, 16, 15),
                        (256, 16, 15)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'RP_2GX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_easy_1to4_3gx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 8, 15),
                        (4, 16, 15),
                        (8, 32, 15),
                        (16, 64, 15),
                        (32, 128, 15),
                        (64, 256, 15),
                        (128, 512, 20),
                        (256, 1024, 20)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'RP_3GX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_easy_c16_3gx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 16, 15),
                        (4, 16, 15),
                        (8, 16, 15),
                        (16, 16, 15),
                        (32, 16, 15),
                        (64, 16, 15),
                        (128, 16, 15),
                        (256, 16, 15)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '0',
                        'bytes_write': '0',
                        'tree_depth': '0',
                        'dir_oclass': 'S1',
                        'oclass': 'RP_3GX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_hard_1to4_sx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 8, 15),
                        (4, 16, 15),
                        (8, 32, 15),
                        (16, 64, 15),
                        (32, 128, 15),
                        (64, 256, 15),
                        (128, 512, 20),
                        (256, 1024, 20)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '3901',
                        'bytes_write': '3901',
                        'tree_depth': '0/20',
                        'dir_oclass': 'S1',
                        'oclass': 'SX'
                    },
                    'enabled': False
                    },
                   {'testcase': 'mdtest_hard_c16_sx',
                    # Number of servers, number of clients, timeout in minutes
                    'testvariants': [
                        (2, 16, 15),
                        (4, 16, 15),
                        (8, 16, 15),
                        (16, 16, 15),
                        (32, 16, 15),
                        (64, 16, 15),
                        (128, 16, 15),
                        (256, 16, 15)
                    ],
                    'ppc': 32,
                    'env_vars': {
                        'pool_size': '85G',
                        'n_file': '12000',
                        'bytes_read': '3901',
                        'bytes_write': '3901',
                        'tree_depth': '0/20',
                        'dir_oclass': 'S1',
                        'oclass': 'SX'
                    },
                    'enabled': False
                    }
                   ]


swim_testlist = [{'testcase': 'pool_rebuild',
                  # Number of servers, number of clients, timeout in minutes
                  'testvariants': [
                      (4, 1, 15),
                      (4, 1, 15),
                      (8, 1, 15),
                      (16, 1, 15),
                      (32, 1, 15),
                      (64, 1, 15),
                      (128, 1, 15),
                      (256, 1, 15),
                      (512, 1, 15),
                      (1024, 1, 15)
                  ],
                  'ppc': 32,
                  'env_vars': {
                      'pool_size': '85G'
                  },
                  'enabled': False
                  }
                 ]


class TestList(object):
    def __init__(self, test_group, testlist, env, script='run_sbatch.sh'):
        self._test_group = test_group
        self._testlist = testlist
        self._env = env
        self._teardown_offset = 10
        self._pool_create_timeout = 5
        self._cmd_timeout = 2
        dst_dir = os.getenv('DST_DIR')
        self._script = os.path.join(dst_dir, script)

    def _expand_default_env_vars(self, env, test):
        env['TEST_GROUP'] = self._test_group
        env['TESTCASE'] = test['testcase']
        env['PPC'] = str(test['ppc'])

    def _expand_extra_env_vars(self, env, test):
        env_vars = test.get('env_vars', {})
        for name, value in env_vars.items():
            env[name.upper()] = str(value)

    def _add_partition(self, env, nodes):
        if nodes <= 512:
            env['PARTITION'] = 'normal'
        else:
            env['PARTITION'] = 'large'

    def _add_timeout(self, env, timeout):
        h = (timeout + self._teardown_offset) // 60
        m = (timeout + self._teardown_offset) % 60
        s = 0
        env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
        env['OMPI_TIMEOUT'] = str(timeout * 60)
        env['POOL_CREATE_TIMEOUT'] = str(self._pool_create_timeout * 60)
        env['CMD_TIMEOUT'] = str(self._cmd_timeout * 60)

    def _expand_variant(self, env, ppc, variant):
        srv, cli, timeout = variant

        nodes = srv + cli + 1
        cores = nodes * ppc

        env['DAOS_SERVERS'] = str(srv)
        env['DAOS_CLIENTS'] = str(cli)
        env['NNODE'] = str(nodes)
        env['NCORE'] = str(cores)

        self._add_partition(env, nodes)
        self._add_timeout(env, timeout)

    def run(self):
        for test in self._testlist:
            if not test['enabled']:
                continue

            env = self._env
            self._expand_default_env_vars(env, test)
            self._expand_extra_env_vars(env, test)
            ppc = test['ppc']
            for variant in test['testvariants']:
                self._expand_variant(env, ppc, variant)
                subprocess.Popen(self._script, env=env)


class SelfTestList(TestList):
    def __init__(self, testlist):
        super(SelfTestList, self).__init__('SELF_TEST', testlist, env)


class IorTestList(TestList):
    def __init__(self, testlist):
        super(IorTestList, self).__init__('IOR', testlist, env)

    def _add_timeout(self, env, timeout):
        # ior runs twice, read and write operations are performed separately
        testcase_timeout = timeout * 2
        h = (testcase_timeout + self._teardown_offset) // 60
        m = (testcase_timeout + self._teardown_offset) % 60
        s = 0
        env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
        env['OMPI_TIMEOUT'] = str(timeout * 60)
        env['POOL_CREATE_TIMEOUT'] = str(self._pool_create_timeout * 60)
        env['CMD_TIMEOUT'] = str(self._cmd_timeout * 60)


class MdtestTestList(TestList):
    def __init__(self, testlist):
        super(MdtestTestList, self).__init__('MDTEST', testlist, env)


class SwimTestList(TestList):
    def __init__(self, testlist):
        super(SwimTestList, self).__init__('SWIM', testlist, env)


def main():
    self_test = SelfTestList(self_testlist)
    self_test.run()

    ior_test = IorTestList(ior_testlist)
    ior_test.run()

    mdtest_test = MdtestTestList(mdtest_testlist)
    mdtest_test.run()

    swim_test = SwimTestList(swim_testlist)
    swim_test.run()


if __name__ == '__main__':
    main()
