#!/usr/bin/env python3

"""
    Gathers ior and mdtest results into csv format.
    Examples:
    - Get all test results
        ./get_results.py $WORK/RESULTS
    - Get just ior results
        ./get_results.py $WORK/RESULTS --tests ior
    - Get and email all results
        ./get_results.py $WORK/RESULTS --email dalton
"""

import re
import datetime
from argparse import ArgumentParser
import os
import stat
import sys
from os.path import join, dirname, basename, isfile, isdir
from pathlib import Path
import subprocess
import csv

# Imports that require package installs
xlsxwriter = None
try:
    import xlsxwriter
except:
    pass

# Shorthand for mapping names to emails.
# Useful for avoiding email typos.
EMAIL_DICT = {
    "dalton": "dalton.bohning@intel.com",
    "sylvia": "sylvia.oi.yee.chan@intel.com",
    "samir":  "samir.raval@intel.com"
}

# Timestamp from test output
FORMAT_TIMESTAMP_TEST = "%a %b %d %H:%M:%S %Z %Y"

# Timestamp from daos_control log
FORMAT_TIMESTAMP_DAOS_CONTROL = "%Y/%m/%d %H:%M:%S"

# Timestamp for output CSV
FORMAT_TIMESTAMP_OUT = "%Y-%m-%d %H:%M:%S"

def get_test_param(param, delim, output):
    """Get a test param of the form PARAM={}.

    For example:
        DAOS_SERVERS=2
        nodes  :  4

    Args:
        param (str): The param to get.
            E.g. DAOS_SERVERS, DAOS_CLIENTS, PPC, nodes.
        delim (str): The delimiter between the label and value.
            Can be multiple characters, in which each is tried.
        output (str): The output from the mdtest run.

    Returns:
        list: str for each occurrence
              None if not found.
    """
    match = re.findall(f"(^|\W){param} *[{delim}] *(.*)", output, re.MULTILINE)
    if not match:
        return None
    return [v[1].strip() for v in match]

from dateutil import parser as date_parser
def convert_timestamp(timestamp, src_format, dst_format):
    """Convert a timestamp from one format to another.

    Args:
        timestamp (str): Representation of a timestamp.
        src_format (str): Input format of timestamp.
        dst_format (str): Output format of timestamp.

    Returns:
        str: timestamp formatted in dst_format.
    """
    timestamp_obj = date_parser.parse(timestamp)
    return timestamp_obj.strftime(dst_format)

def format_timestamp(timestamp):
    """Format a timestamp from ior or mdtest output.

    Args:
        timestamp (str): The full timestamp from ior or mdtest output.

    Returns:
        str: A formatted timestamp.
             Input timestamp on failure.
    """
    if not timestamp:
        return None
    return convert_timestamp(
        timestamp,
        FORMAT_TIMESTAMP_TEST,
        FORMAT_TIMESTAMP_OUT)

def format_timestamp_daos_control(timestamp):
    """Format a timestamp from a daos_control.log.

    Args:
        timestamp (str): The full timestamp from a daos_control.log.

    Returns:
        str: A formatted timestamp.
             Empty string on failure.
    """
    if not timestamp:
        return ""
    return convert_timestamp(
        timestamp,
        FORMAT_TIMESTAMP_DAOS_CONTROL,
        FORMAT_TIMESTAMP_OUT)

def get_lines_after(header, num_lines, output):
    """Get a specified number of lines after a given match.

    Args:
        header (str): The line to match.
        num_lines (int): The number of lines to get after the header.
        output (str): The output to search in.

    Returns:
        list: str for each occurrence, including num_lines after the header
              None if not found.
    """
    lines_regex = "[^\n]*\n" * (num_lines + 1)
    return re.findall(f"{header}{lines_regex}", output)

def get_daos_commit(output_file_path, slurm_job_id):
    """Get the DAOS commit for a given log file from repo_info.txt.

    Args:
        output_file_path (str): Path to the log output.
        slurm_job_id (str): The slurm job id.

    Returns:
        str: The DAOS commit hash.
            None if not found.
    """
    dir_name = dirname(output_file_path)

    repo_info_path = join(dir_name, "repo_info.txt")
    repo_info = read_file(repo_info_path)
    if not repo_info:
        return None
    match = re.search("^Repo:.*daos\.git\ncommit (.*)", repo_info, re.MULTILINE)
    if not match:
        return None
    return match.group(1)[:7]

def get_num_targets(output_file_path, slurm_job_id):
    """Get the number of targets from the server config.

    Assumes each engine uses the same number of targets.

    Args:
        output_file_path (str): path to the log output.
        slurm_job_id (str): the slurm job id.

    Returns:
        str: the number of targets
             None on failure.

    """
    if not slurm_job_id:
        return None

    dir_name = dirname(output_file_path)

    config_path = join(dir_name, "daos_server.yml")
    config = read_file(config_path)
    if not config:
        return None
    match = re.search("^ *targets: ([0-9]+)", config, re.MULTILINE)
    if not match:
        return None
    return match.group(1)

def get_mdtest_metric_max(metric, output):
    """Get the "max" for an mdtest metric.

    Args:
        metric (str): The metric label.
        output (str): The mdtest metric output.
            For example, from get_lines_after("SUMMARY rate:", 10, ...).

    Returns:
        str: The metric value.
             None if not found.
    """
    match = re.search(f" *{metric}(.*)", output, re.MULTILINE)
    if not match:
        return None

    # Of the form: "<max> <min> <mean> <std>"
    all_metrics = match.group(1).lstrip(" ")

    # Index 0 is <max>
    return all_metrics.split(" ")[0]

# TODO support multiple variants
def get_mdtest_sw_hit_max(output):
    """Get the stonewall hit max from mdtest.

    Args:
        output (str): The mdtest output.

    Returns:
        str: The stonewall hit max value.
             None if not found.
    """
    match = re.search(" *Continue stonewall hit.* max: ([0-9]*) ", output, re.MULTILINE)
    if not match:
        return None
    return match.group(1)


def get_ior_metric(metric_name, output):
    """Get a metric from ior output in GiB.

    For example:
        Max Write: 11194.42 MiB/sec

    Args:
        metric_name (str): The name of the metric.
        output (str): The output from ior.

    Returns:
        list: float for each occurrence in GiB, to 2 decimal places.
              None if not found
    """
    match = re.findall(f"{metric_name}: *([0-9|\.]*)", output, re.MULTILINE)
    if not match:
        return None
    return [float(val) / 1024 for val in match]

def format_float(val):
    """Format a floating point value to 2 decimal places.

    Args:
        val (str/float): The string or float value.

    Returns:
        str: The float formatted to 2 decimal places.
    """
    return f"{float(val):.2f}"

def format_ops_to_kops(ops):
    """Convert ops to formatted kops

    Args:
        ops (str/float): String or float ops.

    Returns:
        str: kops formatted to 2 decimal places.
    """
    return format_float(float(ops) / 1000)

def read_file(path):
    """Read a file's contents into a string.
    
    Args:
        path (str): path to the file.
        
    Returns:
        str: the file's contents.
             None on failure or if the file is too large.

    """
    max_size = 256 * 1024 * 1024
    try:
        file_stat = os.stat(path)
    except FileNotFoundError:
        print(f"ERR File not found: {path}", file=sys.stderr)
        return None
    if file_stat.st_size > max_size:
        print(f"ERR File larger than {max_size} bytes: {path}", file=sys.stderr)
        return None
    if not stat.S_ISREG(file_stat.st_mode):
        print(f"ERR Not a file: {path}", file=sys.stderr)
        return None
    with open(path, 'r') as f:
        return f.read()

class TestStatus():
    """Class for managing a test status."""

    PASS = 0
    WARN = 1
    FAIL = 2

    def __init__(self):
        """Initialize a default status."""
        self._status = self.PASS
        self._notes = []

    def warn(self, note=None):
        """Set the status to at least WARN.

        Args:
            note (str, optional): A note about the status.
        """
        if self._status < TestStatus.WARN:
            self._status = TestStatus.WARN
        if note:
            self._notes.append(note)

    def fail(self, note=None):
        """Set the status to at least FAIL.

        Args:
            note (str, optional): A note about the status.
        """
        if self._status < TestStatus.FAIL:
            self._status = TestStatus.FAIL
        if note:
            self._notes.append(note)

    def note(self, note):
        """Add a note without changing the status.

        Args:
            note: (str): The note.
        """
        self._notes.append(note)

    def get_status_str(self):
        """Get the status as a string.
        
        Returns:
            str: The status.
        """
        return ("Pass", "Warning", "Fail")[self._status]

    def get_notes_str(self):
        """Get the notes as a string.

        Returns:
            str: The notes separated by a comma.
        """
        return ",".join(self._notes)

class CsvBase():
    """Class for generating a CSV with results."""

    def __init__(self, csv_file_path, output_style="full", row_template={},
                 row_order=[], row_sort=[]):
        """Initialize a CSV object.
        
        Args:
            csv_file_path (str): Path the the CSV file to write to.
            output_style (str, optional): full or simple output.
            row_template (dict): Key/Value pairs for new rows.
                Also serves as the header row.
            row_order (list): Order of keys on write when style is simple.
            row_sort (list): [key, val_type] pairs for sorting.
                For example: [['my_key', int], ['foo', str]].
        """
        assert output_style in ("full", "simple")
        self.csv_file_path = csv_file_path
        self.output_style = output_style
        self.rows = []
        self.row_template = row_template
        self.row_order = row_order
        self.row_sort = row_sort

    def new_rows(self, output=None):
        """Add some new rows based on self.row_template and set some common params.

        Uses TEST_NAME as a reference for how many variants are in a single job file.

        Args:
            output (str, optional): Output to set common test params.

        Returns:
            list: List of dictionary rows.

        """
        rows = []
        test_cases = get_test_param("TEST_NAME", ":", output)
        for test_case in test_cases:
            row = dict.fromkeys(self.row_template.keys())
            rows.append(row)
            row["TESTCASE"] = test_case
        for key, label in [["slurm_job_id", "SLURM_JOB_ID"],
                           ["test_case", "TESTCASE"],
                           ["oclass", "OCLASS"],
                           ["dir_oclass", "DIR_OCLASS"],
                           ["num_servers", "NUM_SERVERS"],
                           ["num_clients", "NUM_CLIENTS"],
                           ["num_ranks", "RANKS"],
                           ["ppc", "PPC"],
                           ["segments", "SEGMENTS"],
                           ["xfer_size", "XFER_SIZE"],
                           ["block_size", "BLOCK_SIZE"],
                           ["ec_cell_size", "EC_CELL_SIZE"],
                           ["iterations", "ITERATIONS"],
                           ["sw_time", "SW_TIME"],
                           ["n_file", "N_FILE"],
                           ["chunk_size", "CHUNK_SIZE"],
                           ["bytes_read", "BYTES_READ"],
                           ["bytes_write", "BYTES_WRITE"],
                           ["tree_depth", "TREE_DEPTH"],
                           ["num_pools", "NUM_POOLS"],
                           ["pool_size", "POOL_SIZE"]]:
            if key in rows[0]:
                vals = get_test_param(label, ":", output)
                if vals:
                    for index, val in enumerate(vals):
                        rows[index][key] = val

        if "fpp" in rows[0]:
            vals = get_test_param("FPP", ":", output)
            if vals:
                    for index, val in enumerate(vals):
                        if val:
                            rows[index]["fpp"] = True

        for key, label in [["start_time", "Start Time"],
                           ["end_time", "End Time"]]:
            if key in rows[0]:
                vals = get_test_param(label, ":", output)
                if vals:
                        for index, val in enumerate(vals):
                            rows[index][key] = format_timestamp(val)

        self.rows += rows
        return rows

    def new_row(self, output=None):
        """Add a new row based on self.row_template.

        Args:
            output (str, optional): Output to set common test params.

        Returns:
            dict: The new row.
        """
        row = dict.fromkeys(self.row_template.keys())
        self.rows.append(row)
        if output:
            self.set_common_test_params(row, output)
        return row

    @staticmethod
    def set_common_test_params(row, output):
        """Set the common test params for any job.
        
        These are generally the config options and params printed for any job.

        Args:
            row (dict): A row in self.rows to store the params.
            output (str): The output to search in.
        """
        for key, label in [["slurm_job_id", "SLURM_JOB_ID"],
                           ["test_case", "TESTCASE"],
                           ["oclass", "OCLASS"],
                           ["dir_oclass", "DIR_OCLASS"],
                           ["num_servers", "DAOS_SERVERS"],
                           ["num_clients", "DAOS_CLIENTS"],
                           ["num_ranks", "RANKS"],
                           ["ppc", "PPC"],
                           ["segments", "SEGMENTS"],
                           ["xfer_size", "XFER_SIZE"],
                           ["block_size", "BLOCK_SIZE"],
                           ["ec_cell_size", "EC_CELL_SIZE"],
                           ["iterations", "ITERATIONS"],
                           ["sw_time", "SW_TIME"],
                           ["n_file", "N_FILE"],
                           ["chunk_size", "CHUNK_SIZE"],
                           ["bytes_read", "BYTES_READ"],
                           ["bytes_write", "BYTES_WRITE"],
                           ["num_pools", "NUM_POOLS"],
                           ["pool_size", "POOL_SIZE"]]:
            if key in row:
                row[key] = get_test_param(label, ":=", output)

        if "fpp" in row:
            if get_test_param("FPP", ":", output):
                row["fpp"] = True

        for key, label in [["start_time", "Start Time"],
                           ["end_time", "End Time"]]:
            if key in row:
                row[key] = format_timestamp(get_test_param(label, ":", output))

    def sort_rows(self):
        """Sort the rows based on self.row_sort.

        Uses bubble sort, which is stable.
        Puts None values last.
        """
        if not self.row_sort:
            return
        num_rows = len(self.rows)
        for key, typ in reversed(self.row_sort):
            swap = True
            while (swap):
                swap = False
                for row in range(1, num_rows):
                    left_val = self.rows[row-1][key]
                    right_val = self.rows[row][key]
                    if not right_val:
                        continue
                    if (not left_val) or (typ(left_val) > typ(right_val)):
                        tmp = self.rows[row-1]
                        self.rows[row-1] = self.rows[row]
                        self.rows[row] = tmp
                        swap = True

    def write(self):
        """Write the internal data to CSV."""
        print("Sorting rows... ", end="", flush=True)
        self.sort_rows()
        print("Done", flush=True)

        print("Writing rows to CSV... ", end="", flush=True)
        with open(self.csv_file_path, 'w', newline='') as csv_file:
            if self.output_style == "full":
                writer = csv.DictWriter(csv_file,
                                        self.row_template.keys(),
                                        extrasaction="ignore")
                writer.writeheader()
                writer.writerows(self.rows)
            elif self.output_style == "simple":
                writer = csv.DictWriter(csv_file,
                                        self.row_order,
                                        extrasaction="ignore")
                writer.writerows([self.row_template] + self.rows)
            csv_file.flush()
        print("Done", flush=True)
        print(f"CSV Path: {self.csv_file_path}", flush=True)

class CsvIor(CsvBase):
    """Class for generating a CSV with IOR results."""

    def __init__(self, csv_file_path, output_style="full"):
        """Initialize a CSV IOR object.
        
        Args:
            csv_file_path (str): Path the the CSV file.
            output_style (str, optional): full or simple output.

        """
        # Key names should match the table column names
        row_template = {
            "slurm_job_id": "Slurm Job ID",
            "test_case":    "Test Case",
            "start_time":   "Date",
            "end_time":     "End",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "num_servers":  "Num_Servers",
            "num_targets":  "Num Targets",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "fpp":          "File Per Process",
            "segments":     "Segments",
            "xfer_size":    "Xfer Size",
            "block_size":   "Block Size",
            "chunk_size":   "Chunk Size",
            "ec_cell_size": "Cell Size",
            "iterations":   "Iterations",
            "notes":        "Notes",
            "status":       "Status",
            "sw_time":      "SW Time",
            "write_gib":    "Write (GiB/sec)",
            "read_gib":     "Read (GiB/sec)"
        }
        row_order = ["test_case", "start_time", "daos_commit", "oclass",
                     "num_servers", "num_clients", "ppc",
                     "write_gib", "read_gib",
                     "notes", "status"]
        row_sort = [["test_case", str], ["num_servers", int]]

        super().__init__(csv_file_path, output_style, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from an IOR result file.

        Args:
            file_path (str): Path to the result file.
        """
        output = read_file(file_path)
        if not output:
            return

        rows = self.new_rows(output)
        if not rows:
            return
        
        status_list = [TestStatus() for _ in range(len(rows))]
        for index, wr_gib in enumerate(get_ior_metric("Max Write", output)):
            rows[index]["write_gib"] = wr_gib
        for index, rd_gib in enumerate(get_ior_metric("Max Read", output)):
            rows[index]["read_gib"] = rd_gib

        for index, row in enumerate(rows):
            if not row["end_time"]:
                status_list[index].fail("did not finish")
            if row["write_gib"] <= 0:
                status_list[index].warn("write failed")
            if row["read_gib"] <= 0:
                status_list[index].warn("read failed")
            if (row["write_gib"] <= 0) and (row["read_gib"] <= 0):
                status_list[index].fail()
            row["write_gib"] = format_float(row["write_gib"])
            row["read_gib"] = format_float(row["read_gib"])

#        row["daos_commit"] = get_daos_commit(file_path, row["slurm_job_id"])
#        row["num_targets"] = get_num_targets(file_path, row["slurm_job_id"])
#        row["write_gib"]   = format_float(wr_gib)
#        row["read_gib"]    = format_float(rd_gib)
#        row["status"]      = status.get_status_str()
#        row["notes"]       = status.get_notes_str()

class CsvMdtest(CsvBase):
    """Class for generating a CSV with MDTEST results."""

    def __init__(self, csv_file_path, output_style="full"):
        """Initialize a CSV MDTEST object.

        Args:
            csv_file_path (str): Path the the CSV file.
            output_style (str, optional): full or simple output.

        """
        # Key names should match the table column names
        row_template = {
            "slurm_job_id": "Slurm Job ID",
            "test_case":    "Test Case",
            "start_time":   "Date",
            "end_time":     "End",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "dir_oclass":   "Dir Oclass",
            "num_servers":  "Num Servers",
            "num_targets":  "Num Targets",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "notes":        "Notes",
            "status":       "Status",
            "sw_time":      "SW Time",
            "n_file":       "Number of Files",
            "chunk_size":   "Chunk Size",
            "bytes_read":   "Bytes Read",
            "bytes_write":  "Bytes Write",
            "create_kops":  "create(Kops/sec)",
            "stat_kops":    "stat(Kops/sec)",
            "read_kops":    "read(Kops/sec)",
            "remove_kops":  "remove(Kops/sec)"
        }
        row_order = ["test_case", "start_time", "daos_commit", "oclass",
                     "num_servers", "num_clients", "ppc", "create_kops",
                     "stat_kops", "read_kops", "remove_kops",
                     "notes", "status"]
        row_sort = [["test_case", str], ["num_servers", int]]

        super().__init__(csv_file_path, output_style, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from an MDTEST result file.

        Args:
            file_path (str): Path to the result file.
        """
        output = read_file(file_path)
        if not output:
            return

        rows = self.new_rows(output)
        if not rows:
            return

        status_list = [TestStatus() for _ in range(len(rows))]

        # TODO test this
        for index, mdtest_rates in enumerate(get_lines_after("SUMMARY rate:", 10, output)):
            row = rows[index]

            create_raw = get_mdtest_metric_max("File creation", mdtest_rates)
            stat_raw   = get_mdtest_metric_max("File stat", mdtest_rates)
            read_raw   = get_mdtest_metric_max("File read", mdtest_rates)
            remove_raw = get_mdtest_metric_max("File removal", mdtest_rates)
            row["create_kops"] = format_ops_to_kops(create_raw)
            row["stat_kops"]   = format_ops_to_kops(stat_raw)
            row["read_kops"]   = format_ops_to_kops(read_raw)
            row["remove_kops"] = format_ops_to_kops(remove_raw)

        for index, row in enumerate(rows):
            status = status_list[index]

            if not row["end_time"]:
                status_list[index].fail("did not finish")
            sw_time = row["sw_time"]
            n_file = row["n_file"]

            # TODO support multiple variants
            if n_file:
                sw_hit_max = get_mdtest_sw_hit_max(output)
                if sw_hit_max and (int(sw_hit_max) >= int(n_file)):
                    status.warn(f"{n_file} sw hit")

            # TODO support multiple variants
            if False and sw_time:
                mdtest_times = get_lines_after("SUMMARY time:", 10, output)
                if mdtest_times:
                    create_time_raw = get_mdtest_metric_max("File creation", mdtest_times)
                    if float(create_time_raw) < float(sw_time):
                        status.warn("create < SW_TIME")

            # TODO support some baseline sw_time
            if False and sw_time and (int(sw_time) != 60):
                status.note(f"sw={sw_time}s")

#        row["daos_commit"] = get_daos_commit(file_path, row["slurm_job_id"])
#        row["num_targets"] = get_num_targets(file_path, row["slurm_job_id"])
#        row["status"]      = status.get_status_str()
#        row["notes"]       = status.get_notes_str()

class CsvRebuild(CsvBase):
    """Class for generating a CSV with rebuild results."""

    def __init__(self, csv_file_path, output_style="full"):
        """Initialize a CSV rebuild object.

        Args:
            csv_file_path (str): Path the the CSV file.
            output_style (str, optional): full or simple output.

        """
        row_template = {
            "slurm_job_id":           "Slurm Job ID",
            "test_case":              "Test Case",
            "start_time":             "Date",
            "end_time":               "End",
            "daos_commit":            "Commit",
            "oclass":                 "Oclass",
            "num_servers":            "Num Servers",
            "num_clients":            "Num Clients",
            "num_targets":            "Num Targets",
            "ppc":                    "Processes Per Client",
            "num_pools":              "Num Pools",
            "pool_size":              "Pool Size",
            "rebuild_kill_time":      "Rebuild Kill Time",
            "rebuild_down_time":      "Rebuild Dead Time",
            "rebuild_queued_time":    "Rebuild Queued Time",
            "rebuild_completed_time": "Rebuild Completed Time",
            "status":                 "Status",
            "notes":                  "Notes"
        }
        row_order = ["test_case", "start_time", "daos_commit", "oclass",
                     "num_servers", "num_pools", "num_targets", "pool_size",
                     "rebuild_kill_time", "rebuild_down_time",
                     "rebuild_queued_time", "rebuild_completed_time",
                     "end_time", "notes",
                     "status"]
        row_sort = [["test_case", str],
                    ["num_servers", int],
                    ["num_pools", int]]

        super().__init__(csv_file_path, output_style, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from a rebuild result file.

        Args:
            file_path (str): Path to the result file.
        """
        output = read_file(file_path)
        if not output:
            return

        row = self.new_row(output)
        status = TestStatus()

        num_pools = row["num_pools"]

        num_pools_after_rebuild = get_test_param("NUM_POOLS_AFTER_REBUILD", ":", output, 0)
        num_pools_rebuild_done  = get_test_param("NUM_POOLS_REBUILD_DONE", ":", output, 0)

        if int(num_pools_after_rebuild) != int(num_pools):
            status.warn(f"num_pools_after_rebuild={num_pools_after_rebuild},")
        if int(num_pools_rebuild_done) != int(num_pools):
            status.warn(f"num_pools_rebuild_done={num_pools_rebuild_done},")

        log_dir = join(dirname(file_path), "logs")

        rebuild_kill_time      = get_test_param("Kill Time", ":", output)
        rebuild_queued_time    = None
        rebuild_down_time      = None
        rebuild_completed_time = None

        # Get a list of all queued and completed times
        control_log_list  = []
        rebuild_down      = []
        rebuild_queued    = []
        rebuild_completed = []
        if os.path.isdir(log_dir):
            path_obj = Path(log_dir)
            control_log_list = sorted(path_obj.rglob("daos_control.log"))
        for control_log in control_log_list:
            control_log_output = read_file(control_log)
            if not control_log_output:
                continue
            match = re.search("INFO (.*) daos_engine.*is down",
                              control_log_output, re.MULTILINE)
            if not match:
                continue
            rebuild_down.append(match.group(1).strip())
            match = re.search("INFO (.*) daos_engine.*Rebuild \[queued\]",
                              control_log_output, re.MULTILINE)
            if not match:
                continue
            rebuild_queued.append(match.group(1).strip())
            match = re.search("INFO (.*) daos_engine.*Rebuild \[completed\]",
                              control_log_output, re.MULTILINE)
            if not match:
                continue
            rebuild_completed.append(match.group(1).strip())

        # Down time is when the first down message was logged
        if rebuild_down:
            rebuild_down.sort()
            rebuild_down_time = rebuild_down[0]

        # Queued time is when the first rebuild was queued
        if rebuild_queued:
            rebuild_queued.sort()
            rebuild_queued_time = rebuild_queued[0]

        # Completed time is when the last rebuild completed
        if rebuild_completed:
            rebuild_completed.sort()
            rebuild_completed_time = rebuild_completed[-1]

        if not (rebuild_kill_time and rebuild_down_time and rebuild_queued_time and rebuild_completed_time):
            status.fail("did not finish")

        row["rebuild_kill_time"]      = format_timestamp(rebuild_kill_time)
        row["rebuild_down_time"]      = format_timestamp_daos_control(rebuild_down_time)
        row["rebuild_queued_time"]    = format_timestamp_daos_control(rebuild_queued_time)
        row["rebuild_completed_time"] = format_timestamp_daos_control(rebuild_completed_time)
        row["daos_commit"]            = get_daos_commit(file_path, row["slurm_job_id"])
        row["num_targets"]            = get_num_targets(file_path, row["slurm_job_id"])
        row["status"]                 = status.get_status_str()
        row["notes"]                  = status.get_notes_str()

class CsvCart(CsvBase):
    """Class for generating a CSV with cart results."""

    def __init__(self, csv_file_path, output_style="full"):
        """Initialize a CSV cart object.

        Args:
            csv_file_path (str): Path the the CSV file.
            output_style (str, optional): full or simple output.

        """
        row_template = {
            "slurm_job_id":           "Slurm Job ID",
            "test_case":              "Test Case",
            "start_time":             "Date",
            "end_time":               "End",
            "daos_commit":            "Commit",
            "num_servers":            "Num Servers",
            "num_clients":            "Num Clients",
            "num_targets":            "Num Targets",
            "ppc":                    "Processes Per Client",
            "num_pools":              "Num Pools",
            "pool_size":              "Pool Size",
            "status":                 "Status",
            "notes":                  "Notes"
        }
        row_order = ["test_case", "start_time", "daos_commit",
                     "num_servers", "num_pools", "num_targets", "pool_size",
                     "end_time", "notes", "status"]
        row_sort = [["test_case", str],
                    ["num_servers", int]]

        super().__init__(csv_file_path, output_style, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from a cart result file.

        Args:
            file_path (str): Path to the result file.
        """
        output = read_file(file_path)
        if not output:
            return

        row = self.new_row(output)
        status = TestStatus()

        row["daos_commit"]            = get_daos_commit(file_path, row["slurm_job_id"])
        row["num_targets"]            = get_num_targets(file_path, row["slurm_job_id"])
        row["status"]                 = status.get_status_str()
        row["notes"]                  = status.get_notes_str()

def get_output_list(result_path, prefix, log_style):
    """Get a list of output files for a given prefix.

    Args:
        result_path (str): Path to the top-level directory.
        prefix (str): Directory prefix.
            For example: mdtest, ior, rebuild.
        log_style (str): frontera or avocado

    Returns:
        list: List of sorted paths to output files.
    """
    # Recursively drill down to find each output file in each log directory
    # in each directory
    path_obj = Path(result_path)

    if log_style == "frontera":
        output_file_list = sorted(path_obj.rglob(f"*{prefix}_*/log_*/*/output*"))
        if not output_file_list and prefix in result_path:
            output_file_list = sorted(path_obj.rglob("log_*/*/output*"))

        # In case the log directory itself is passed
        if not output_file_list and prefix in result_path and "log_" in result_path:
            output_file_list = sorted(path_obj.rglob("output*"))
    elif log_style == "avocado":
        output_file_list = sorted(path_obj.rglob(f"*frontera-{prefix}_*/job.log"))
    else:
        print("ERR Invalid log_style")

    if not output_file_list:
        print(f"No {prefix} log files found", flush=True)
    return output_file_list

def generate_results(result_dir, prefix, csv_class, csv_path, log_style, output_style):
    """Generate a CSV from a directory containing results.

    Args:
        result_dir (str): Path the results directory.
        prefix (str): Test prefix to filter directories.
            E.g. mdtest, ior, rebuild.
        csv_class (CsvBase): The csv class to format/generate the results.
            E.g. CsvMdtest, CsvIor, CsvRebuild.
        csv_path (str): Path to the generated csv.
        log_style (str): frontera or avocado
        output_style (str): full or simple output.

    Returns:
        bool: True if results were found; False if not.
    """
    if not issubclass(csv_class, CsvBase):
        print(f"ERR {csv_class} is not a subclass of CsvBase", file=sys.stderr)
        return False

    output_file_list = get_output_list(result_dir, prefix, log_style)
    if not output_file_list:
        return False

    print(f"\nGenerating {prefix} csv", flush=True)
    csv_obj = csv_class(csv_path, output_style)
    for output_file in output_file_list:
        print(f"  Processing: {output_file}", flush=True)
        csv_obj.process_result_file(output_file)
    csv_obj.write()

    return True

def get_email_str():
    """Get a string representation of EMAIL_DICT.
    
    Returns:
        str: Emails formatted as:
             <name>: <email>
    """
    return "\n".join([f"{k}: {v}" for k, v in EMAIL_DICT.items()])

def email_results(output_list, email_list):
    """Email the results.

    Args:
        output_list (list): List of output result paths.
            E.g. the generated csv files.
        email_list (list): List of email addresses.

    Returns:
        bool: True/False if successful.
    """
    # Send an email with the results
    body_cmd = 'printf "'
    attach_str = ""
    for path in output_list:
        body_cmd += f"`cat '{path}'`\\n\\n\\n"
        attach_str += f"-a '{path}' "
    body_cmd += '"'
    subject = "Frontera Test Results"
    email_str = " ".join(email_list)
    mail_cmd = 'echo "See Attached" | mail -s "{}" {} {}'.format(
        subject, attach_str, email_str)
    print("\nSending email... \n  To: {}\n  Files: {}".format(
          "\n      ".join(email_list),
          "\n         ".join(output_list)), flush=True)
    result = subprocess.run(mail_cmd, shell=True)
    if result.returncode != 0:
        print("ERR Failed to send email.", file=sys.stderr)
        return False
    return True

def csv_list_to_xlsx(csv_list, xlsx_file_path, group_by=None):
    """Convert a list of CSV files to XLSX format.

    Args:
        csv_list (list): List of CSV file paths.
        xlsx_file_path (str): Path to the XLSX workbook.
        group_by (int/str, optional): column index or column header name to
            group by. Each group will be put on a separate sheet.

    Returns:
        bool: True/False if successful.

    """
    group_by_index = False
    group_by_name = True
    if isinstance(group_by, int):
        group_by_index = True
    elif isinstance(group_by, str):
        group_by_name = True
    elif group_by is not None:
        print("ERR group_by must be int or str", file=sys.stderr)
        return False

    if not csv_list:
        print("No CSV files provided.")
        return False

    # Create a dictionary where each entry is an array
    # containing all results for a given group.
    # Each row is grouped by group_by, or "other" if not supplied.
    print("\nGrouping rows... ", end="", flush=True)
    group_dict = {}
    for csv_file_path in csv_list:
        with open(csv_file_path, 'rt') as csv_file:
            reader = csv.DictReader(csv_file)
            if group_by_index:
                group_by_key = reader.fieldnames[group_by]
            elif group_by_name:
                group_by_key = group_by
            else:
                group_by_key = None

            for row in reader:
                if group_by_key:
                    this_group = row[group_by_key]
                else:
                    this_group = "other"

                # The header for a group is the header of the first csv
                # that contains a row in the group
                if this_group not in group_dict:
                    group_dict[this_group] = [reader.fieldnames]
                group_dict[this_group].append(row.values())
    print("Done", flush=True)

    # Create a workbook where each worksheet is a group.
    with xlsxwriter.Workbook(xlsx_file_path) as xlsx_file:
        print("\nWriting rows to XLSX... ", end="", flush=True)
        # Create a main worksheet that will link to all other worksheets
        main_worksheet = xlsx_file.add_worksheet("main")
        main_row = 0

        for group in group_dict:
            worksheet_name = group
            worksheet = xlsx_file.add_worksheet(worksheet_name)
            # Link between main<->group
            worksheet.write_url(0, 0, "internal:main!A1", string="Go back to main")
            main_worksheet.write_url(main_row, 0,
                                     f"internal:{group}!A1",
                                     string=group)
            main_row += 1
            for row_idx, row in enumerate(group_dict[group]):
                worksheet.write_row(row_idx + 1, 0, row)
        print("Done", flush=True)
        print(f"XLSX Path: {xlsx_file_path}", flush=True)

    return True

def main(result_path, tests=["all"], log_style="frontera", output_format="csv", output_style="full",
         email_list=[]):
    """See __main__ below for arguments."""
    all_tests = ["ior", "mdtest", "rebuild", "cart"]
    if "all" in tests:
        tests = all_tests
    else:
        for test in tests:
            if test not in all_tests:
                print(f"ERROR: invalid test: {test}")
                return 1

    result_path = result_path.rstrip("/")
    result_name = os.path.basename(result_path)
    output_list = []

    if not os.path.isdir(result_path):
        print(f"ERR Not a directory: {result_path}", file=sys.stderr)
        return 1

    if output_format == "xlsx" and not xlsxwriter:
        print("ERR xlsxwriter not installed", file=sys.stderr)
        return 1

    for i, email in enumerate(email_list):
        if email in EMAIL_DICT.keys():
            email_list[i] = EMAIL_DICT[email]
        elif not (email.endswith("intel.com")
                  or email in EMAIL_DICT.values()):
            # Restrict email addresses se we don't accidentally get blacklisted
            # for email typos.
            print("ERR email must end with 'intel.com' or be in the dictionary:\n" +
                  get_email_str(), file=sys.stderr)
            return 1

    print("\n" +
          f"Result Path: {result_path}\n" +
          f"Result Name: {result_name}\n" +
          f"Email: {email_list}\n", flush=True)

    # Generate results for each test in tests
    for (test, test_class) in (("ior", CsvIor),
                               ("mdtest", CsvMdtest),
                               ("rebuild", CsvRebuild),
                               ("cart", CsvCart)):
        if test in tests:
            print("")
            csv_name = f"{test}_result_{result_name}.csv"
            csv_path = join(result_path, csv_name)
            if generate_results(result_path, test, test_class, csv_path, log_style, output_style):
                output_list.append(csv_path)

    if not output_list:
        print("No results generated.")
        return 1

    if output_format == "xlsx" and output_list:
        excel_file_name = f"result_{result_name}.xlsx"
        excel_file_path = join(result_path, excel_file_name)
        if output_style == "simple":
            group_by = 0
        else:
            group_by = "test_case"
        if csv_list_to_xlsx(output_list, excel_file_path, group_by):
            output_list.append(excel_file_path)

    if output_list and email_list:
        if not email_results(output_list, email_list):
            return 1

    print("\nDone")

    return 0


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "result_path",
        type=str,
        help="full path to results directory")
    parser.add_argument(
        "--tests",
        type=str,
        default="ior,mdtest",
        help="comma-separated list of tests (all,ior,mdtest,rebuild,cart)")
    parser.add_argument(
        "--log-style",
        type=str,
        choices=("frontera","avocado"),
        default="frontera",
        help="log style. default frontera")
    parser.add_argument(
        "--output-format",
        type=str,
        choices=("csv", "xlsx"),
        default="csv",
        help="output format. default csv")
    parser.add_argument(
        "--output-style",
        type=str,
        choices=("full", "simple"),
        default="full",
        help="output style. default full.")
    parser.add_argument(
        "--email",
        type=str,
        help="email addresses or names to send result csv(s) to\n" +
             "Must end with 'intel.com' or be in the dictionary:\n" + get_email_str())
    args = parser.parse_args()
    email_list = []
    if args.email:
        email_list = args.email.split(",")
    rc = main(
        result_path=args.result_path,
        tests=args.tests.split(","),
        log_style=args.log_style,
        output_format=args.output_format,
        output_style=args.output_style,
        email_list=email_list)
    exit(rc)
