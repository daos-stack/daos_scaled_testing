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
