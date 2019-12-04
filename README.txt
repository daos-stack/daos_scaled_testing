Modify Slurm related variables
#SBATCH -p <skx-dev>          	# Queue (partition) name
#SBATCH -N 3                    # Total # of nodes
#SBATCH -n 144                  # Total # of mpi tasks (48 x  Total # of nodes)
#SBATCH -t 00:10:00             # Run time (hh:mm:ss)
#SBATCH --mail-user=first.last@intel.com
#SBATCH --mail-type=all         # Send email at begin and end of job

Modiy DAOS related parameters
DAOS_SERVERS=1					#Number of servers
DAOS_CLIENTS=1					#Number of clients
DAOS_DIR="/home1/<PATH>/daos"

Run CART self_test
- sbatch main.sh SELF_TEST

Run IOR test only
- sbatch main.sh IOR 

Run all tests
- sbatch main.sh IOR SELF_TEST MDTEST DAOS_TEST

