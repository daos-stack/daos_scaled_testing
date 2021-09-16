#!/usr/bin/env python3

'''
    Convert older result organizations to the newer organization
    as best as possible. This allows new get_results.py to work
    on older result directories
'''

import sys
import re
from pathlib import Path
from os import rename, chdir
from os.path import join, dirname

def rename_v(old, new):
    '''Log and rename a file/dir.'''
    print(f'{old} -> {new}', flush=True)
    rename(old, new)

def convert_org(pathname):
    '''Convert old organization to new organization.'''
    chdir(pathname)
    files = sorted(Path('.').rglob('log_*/*'))
    for filename in files:
        filename = str(filename)
        dir_name = dirname(filename)

        # output_<slurm>.txt -> <slurm>/output.txt
        match = re.search('output_([0-9].*)\.txt', filename)
        if match:
            slurm_job_id = match.group(1)
            rename_v(filename, join(dir_name, slurm_job_id, 'output.txt'))

        # repo_info_<slurm>.txt -> <slurm>/repo_info.txt
        match = re.search('repo_info_([0-9].*)\.txt', filename)
        if match:
            slurm_job_id = match.group(1)
            rename_v(filename, join(dir_name, slurm_job_id, 'repo_info.txt'))

        # stderr.e<slurm> -> <slurm>/stderr.txt
        match = re.search('stderr\.e([0-9].*)', filename)
        if match:
            slurm_job_id = match.group(1)
            rename_v(filename, join(dir_name, slurm_job_id, 'stderr.txt'))

        # stdout.o<slurm> -> <slurm>/stdout.txt
        match = re.search('stdout\.o([0-9].*)', filename)
        if match:
            slurm_job_id = match.group(1)
            rename_v(filename, join(dir_name, slurm_job_id, 'stdout.txt'))

        # sw.<slurm> -> <slurm>/sw
        match = re.search('sw\.([0-9].*)', filename)
        if match:
            slurm_job_id = match.group(1)
            rename_v(filename, join(dir_name, slurm_job_id, 'sw'))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <result_path>')
        sys.exit(1)

    convert_org(sys.argv[1])
