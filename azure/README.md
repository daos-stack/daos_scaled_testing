# daos\_scaled\_testing/azure

This bunch scripts allow to run ior and mdtest benchmark on an Azure cluster.


## Environment Scripts

The _envs_ directory contains several scripts defining common variables and functions. They are
defining variables such as the list of client nodes, ior options, etc.


## Files Directory

The _files_ directory contains miscellaneous files used by the different scripts. There is mainly
DAOS service files and dnf repositories.  It should also contains some tarball gathering DAOS rpms.  


## MPI Hostfiles

The _hostfiles_ directory contains the mpich hostfiles defining the list of DAOS client nodes which
could be used according to the number of nodes to use.


## Install Scripts

The _instal-daos.sh_ and _install-ior.sh_ scripts allow to respectively install DAOS and ior on
an Azure cloud cluster.  The _instal-daos.sh_ script used the _generate-daos_server\_cfg.sh_ script
to create the _/etc/daos/daos\_server.yml_ of each DAOS server.

The _instal-daos.sh_ script needs a tarball compressed throughh xz containing the DAOS rpms and some
of there direct dependencies.  Folllowing is the content of a tarball of the DAOS master branch
which could be used with this script:

```bash
$ tar tf daos-master-el8.txz
daos-master-el8/
daos-master-el8/daos-2.3.100-22.8622.g03165cb1.el8.src.rpm
daos-master-el8/daos-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-admin-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-admin-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-client-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-client-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-client-tests-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-client-tests-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-client-tests-openmpi-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-devel-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-firmware-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-serialize-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-server-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-server-tests-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-tests-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-tests-internal-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/argobots-1.1-1.el8.x86_64.rpm
daos-master-el8/compat-hwloc1-2.2.0-3.el8.x86_64.rpm
daos-master-el8/dpdk-21.11.1-1.el8.x86_64.rpm
daos-master-el8/hdf5-mpich-1.13.1-1.el8.x86_64.rpm
daos-master-el8/libfabric-1.15.1-1.el8.x86_64.rpm
daos-master-el8/libisa-l-2.30.0-1.el8_3.x86_64.rpm
daos-master-el8/libisa-l_crypto-2.23.0-1.el8.x86_64.rpm
daos-master-el8/libpmem-1.12.1~rc1-1.el8.x86_64.rpm
daos-master-el8/libpmemobj-1.12.1~rc1-1.el8.x86_64.rpm
daos-master-el8/libpmempool-1.12.1~rc1-1.el8.x86_64.rpm
daos-master-el8/librpmem-1.11.0-3.el8.x86_64.rpm
daos-master-el8/mercury-2.2.0-1.el8.x86_64.rpm
daos-master-el8/mpich-4.0~a2-3.el8.src.rpm
daos-master-el8/spdk-22.01.1-2.el8.x86_64.rpm
daos-master-el8/spdk-tools-22.01.1-2.el8.noarch.rpm
daos-master-el8/daos-client-tests-openmpi-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-debugsource-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-firmware-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-mofed-shim-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-serialize-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-server-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
daos-master-el8/daos-server-tests-debuginfo-2.3.100-22.8622.g03165cb1.el8.x86_64.rpm
```


## DAOS Starting Scripts

_start-*.sh_ files allow to start the different DAOS services (e.g. DAOS server, DAOS agent, etc.).
It also generates some configuration files suche as the _/etc/daos/daos\_server.yml_ thanks to the
_generate-daos_server\_cfg.sh_ script.


## DAOS Cleanup Scripts

_cleanup-*.sh_ files allow to properly stop DAOS services, remove useless huge pages, stop client
processes.


## Run Scripts

_run.sh_ and _run-all-deprecated.sh_ scripts allow to run a set of benchmarks test.
_run-ior.sh_ and _run-mdtest.sh_ are used by the previous script to run one given benchmark.
They could be used directly with calling them with adapated arguments.  More details on the list of
supported arguments could be found inside the scripts


## Plot Scripts

_plot.sh_ generates _png_ graphs thanks to _gnuplot_ and the results of a set of benchmark recorded
in the result directory.
