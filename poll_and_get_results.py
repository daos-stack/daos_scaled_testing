#!/usr/bin/env python3

#
# WIP - Needs further testing and tweaking
#

import time
import subprocess
import pwd
import os
from argparse import ArgumentParser
from get_results import main as get_results

def get_username():
    """Get the username of the executing user.

    Returns:
        str: The username.
    """
    return pwd.getpwuid(os.getuid())[0]

def get_num_jobs(username, jobname):
    """Get the number of jobs for a given job name.

    Args:
        username (str): Username of the job owner.
        jobname (str): The job name.

    Returns:
        int: The number of jobs.
    """
    cmd = "squeue -u {} --noheader --name='{}' | wc -l".format(
        username, jobname)
    cmd_result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE)
    return int(cmd_result.stdout)

def main():
    parser = ArgumentParser()
    parser.add_argument(
        "result_path",
        type=str,
        help="full path to results directory")
    parser.add_argument(
        "-n", "--name",
        required=True,
        type=str,
        help="the job name")
    parser.add_argument(
        "-i", "--interval",
        default="5",
        type=int,
        help="minutes between each check")
    args = parser.parse_args()

    result_path = args.result_path
    jobname = args.name
    interval_m = args.interval
    interval_s = interval_m * 60
    username = get_username()

    num_jobs = get_num_jobs(username, jobname)
    if (not num_jobs) or (num_jobs == 0):
        print("No jobs found.")
        return 1

    max_wait_s = 12 * 60 * 60
    total_wait_s = 0
    while (total_wait_s < max_wait_s):
        time.sleep(interval_s)
        total_wait_s += interval_s
        num_jobs = get_num_jobs(username, jobname)
        if num_jobs == 0:
            return get_results(result_path, email_list=["dalton.bohning@intel.com"])

if __name__ == "__main__":
    exit(main())
