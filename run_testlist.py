#!/usr/bin/python

import os
import subprocess

env = os.environ

env['PATH'] = "/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:."

env['LD_LIBRARY_PATH'] = "/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/"

env['JOBNAME'] = "<sbatch_jobname>"
env['EMAIL'] = "<email>"  # <first.last@email.com>
env['DAOS_DIR'] = "<path_to_daos>"  # /scratch/BUILDS/latest/daos
env['DST_DIR'] = "<path_to_daos_scaled_testing>" # /scratch/TESTS/daos_scaled_testing
env['RES_DIR'] = "<path_to_result_dir>" # /home1/06753/soychan/work/POC/TESTS/dst_framework/RESULTS

slf_testlist = [{'testcase': 'st_1tomany_cli2srv_inf1',
                 'nServer': [2, 4, 8, 16, 32, 64, 128, 256, 512],
                 'nClient': [1, 1, 1, 1, 1, 1, 1, 1, 1],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15, 15, 15, 15, 15, 15],
                 'ppc': 1,
                 'inflight': 1,
                 'enabled': 0
                 },
                {'testcase': 'st_1tomany_cli2srv_inf16',
                 'nServer': [2, 4, 8, 16, 32, 64, 128, 256, 512],
                 'nClient': [1, 1, 1, 1, 1, 1, 1, 1, 1],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15, 15, 15, 15, 15, 15],
                 'ppc': 1,
                 'inflight': 16,
                 'enabled': 0
                 }
                ]

ior_testlist = [{'testcase': 'ioreasy_1to4',
                 'nServer': [2, 4, 8, 16],
                 'nClient': [8, 16, 32, 64],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15],
                 'ppc': 32,
                 'pool_sz': '85G',
                 'xfer_sz': '1M',
                 'blk_sz': '1G',
                 'enabled': 0
                 },
                {'testcase': 'ioreasy_c16',
                 'nServer': [2, 4, 8, 16],
                 'nClient': [16, 16, 16, 16],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15],
                 'ppc': 32,
                 'pool_sz': '85G',
                 'xfer_sz': '1M',
                 'blk_sz': '1G',
                 'enabled': 0
                 },
                {'testcase': 'iorhard_1to4',
                 'nServer': [2, 4, 8, 16, 32, 64, 128, 256],
                 'nClient': [8, 16, 32, 64, 128, 256, 512, 1024],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15, 15, 15, 15, 15],
                 'ppc': 32,
                 'pool_sz': '85G',
                 'xfer_sz': '47008',
                 'blk_sz': '47008',
                 'enabled': 0
                 },
                {'testcase': 'iorhard_c16',
                 'nServer': [2, 4, 8, 16, 32, 64, 128, 256],
                 'nClient': [16, 16, 16, 16, 16, 16, 16, 16],
                 # timeout in minutes
                 'timeout': [15, 15, 15, 15, 15, 15, 15, 15],
                 'ppc': 32,
                 'pool_sz': '85G',
                 'xfer_sz': '47008',
                 'blk_sz': '47008',
                 'enabled': 0
                 }
                ]

dst_dir = os.getenv("DST_DIR")
script = os.path.join(dst_dir, "run_sbatch.sh")

for test in slf_testlist:
    if test['enabled'] == 1:
        env['TEST_GROUP'] = "SELF_TEST"
        env['TESTCASE'] = test['testcase']
        env['INFLIGHT'] = str(test['inflight'])
        for i in range(len(test['nServer'])):
            srv = test['nServer'][i]
            cli = test['nClient'][i]
            nodes = srv + cli + 1
            cores = nodes * test['ppc']
            if nodes <= 512:
                env['PARTITION'] = 'normal'
            else:
                env['PARTITION'] = 'large'

            env['DAOS_SERVERS'] = str(srv)
            env['DAOS_CLIENTS'] = str(cli)
            env['NNODE'] = str(nodes)
            env['NCORE'] = str(cores)

            t = test['timeout'][i] + 10
            h = int(t / 60)
            m = t % 60
            s = 0
            env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
            env['OMPI_TIMEOUT'] = str(test['timeout'][i] * 60)

            subprocess.Popen(script, env=env)

for test in ior_testlist:
    if test['enabled'] == 1:
        env['TEST_GROUP'] = "IOR"
        env['TESTCASE'] = test['testcase']
        for i in range(len(test['nServer'])):
            srv = test['nServer'][i]
            cli = test['nClient'][i]
            nodes = srv + cli + 1
            cores = nodes * test['ppc']
            if nodes <= 512:
                env['PARTITION'] = 'normal'
            else:
                env['PARTITION'] = 'large'

            env['DAOS_SERVERS'] = str(srv)
            env['DAOS_CLIENTS'] = str(cli)
            env['NNODE'] = str(nodes)
            env['NCORE'] = str(cores)
            env['PPC'] = str(test['ppc'])
            env['POOL_SIZE'] = test['pool_sz']
            env['XFER_SIZE'] = test['xfer_sz']
            env['BLOCK_SIZE'] = test['blk_sz']

            t = test['timeout'][i] + 10
            h = int(t / 60)
            m = t % 60
            s = 0
            env['TIMEOUT'] = str(h) + ":" + str(m) + ":" + str(s)
            env['OMPI_TIMEOUT'] = str(test['timeout'][i] * 60)

            subprocess.Popen(script, env=env)
