Modify Slurm related variables
#SBATCH -p <development>     	# Queue (partition) name
#SBATCH -N 3                    # Total # of nodes
#SBATCH -n 168                  # Total # of mpi tasks (56 x  Total # of nodes)
#SBATCH -t 00:10:00             # Run time (hh:mm:ss)
#SBATCH --mail-user=first.last@intel.com
#SBATCH --mail-type=all         # Send email at begin and end of job

Modiy DAOS related parameters
DAOS_SERVERS=4					# Number of DAOS servers
DAOS_CLIENTS=2					# Number of DAOS clients
ACCESS_PORT=10001 				# Access port
DAOS_DIR="<path_to_daos>/daos"			# Path to daos build
POOL_SIZE="60G"					# Pool size
MPI="openmpi" #supports openmpi or mpich	# MPI

Run CART self_test
- sbatch main.sh SELF_TEST

Run IOR test
- sbatch main.sh IOR 

Run MDTEST
- sbatch main.sh MDTEST
