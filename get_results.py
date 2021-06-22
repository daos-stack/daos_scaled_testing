#!/usr/bin/env python3

"""
    Gathers ior and mdtest results into csv format.
    Examples:
    - Get all ior and mdtest results
        ./get_results.py /work2/08126/dbohninx/frontera/RESULTS
    - Get just ior results
        ./get_results.py /work2/08126/dbohninx/frontera/RESULTS --no-mdtest
    - Get and email all results
        ./get_results.py /work2/08126/dbohninx/frontera/RESULTS --email dalton
"""

import re
import datetime
from argparse import ArgumentParser
import os
from os.path import join, dirname, basename
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
    "dalton": "daltonx.bohning@intel.com",
    "sylvia": "sylvia.oi.yee.chan@intel.com",
    "samir":  "samir.raval@intel.com"
}

# Timestamp from test output
FORMAT_TIMESTAMP_TEST = "%a %b %d %H:%M:%S %Z %Y"

# Timestamp from DAOS logs
FORMAT_TIMESTAMP_DAOS = "%Y/%m/%d %H:%M:%S"

# Timestamp for output CSV
FORMAT_TIMESTAMP_OUT = "%Y-%m-%d %H:%M:%S"

def get_test_param(param, delim, output, default=None):
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
        default (any): What to return if not found.
            Defaults to None.

    Returns:
        str: The param value.
             default if not found.
    """
    match = re.search(f"^{param} *[{delim}] *(.*)", output, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return default

def convert_timestamp(timestamp, src_format, dst_format):
    """Convert a timestamp from one format to another.

    Args:
        timestamp (str): Representation of a timestamp.
        src_format (str): Input format of timestamp.
        dst_format (str): Output format of timestamp.

    Returns:
        str: timestamp formatted in dst_format.
    """
    timestamp_obj = datetime.datetime.strptime(timestamp, src_format)
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

def format_timestamp_daos_log(timestamp):
    """Format a timestamp from a DAOS log file.

    Args:
        timestamp (str): The full timestamp from a DAOS log.

    Returns:
        str: A formatted timestamp.
             Input timestamp on failure.
    """
    if not timestamp:
        return str(timestamp)
    return convert_timestamp(
        timestamp,
        FORMAT_TIMESTAMP_DAOS,
        FORMAT_TIMESTAMP_OUT)

def get_timestamp_diff_rebuild_detect(timestamp1, timestamp2):
    """Get the difference in minutes and seconds between rebuild kill and rebuild start.

    Args:
        timestamp1 (str): Representation of the kill timestamp.
        timestamp2 (str): Representation of the start timestamp.

    Returns:
        str: Formatted timestamp difference.
             None on failure.
    """
    if not timestamp1 or not timestamp2:
        return None
    timestamp_obj1 = datetime.datetime.strptime(timestamp1, FORMAT_TIMESTAMP_TEST)
    timestamp_obj2 = datetime.datetime.strptime(timestamp2, FORMAT_TIMESTAMP_DAOS)
    timestamp_diff = timestamp_obj2 - timestamp_obj1
    total_seconds = int(timestamp_diff.total_seconds())
    minutes = int(total_seconds / 60)
    seconds = int(total_seconds % 60)
    return f"{minutes:02d}:{seconds:02d}"

def get_timestamp_diff_rebuild(timestamp1, timestamp2):
    """Get the difference in minutes and seconds between two rebuild timestamps.

    Args:
        timestamp1 (str): Representation of the start timestamp.
        timestamp2 (str): Representation of the end timestamp.

    Returns:
        str: Formatted timestamp difference.
             None on failure.
    """
    if not timestamp1 or not timestamp2:
        return None
    timestamp_obj1 = datetime.datetime.strptime(timestamp1, FORMAT_TIMESTAMP_DAOS)
    timestamp_obj2 = datetime.datetime.strptime(timestamp2, FORMAT_TIMESTAMP_DAOS)
    timestamp_diff = timestamp_obj2 - timestamp_obj1
    total_seconds = int(timestamp_diff.total_seconds())
    minutes = int(total_seconds / 60)
    seconds = int(total_seconds % 60)
    return f"{minutes:02d}:{seconds:02d}"

def get_lines_after(header, num_lines, output):
    """Get a specified number of lines after a given match.

    Args:
        header (str): The line to match.
        num_lines (int): The number of lines to get after the header.
        output (str): The output to search in.

    Returns:
        str: num_lines including and after the header.
             None if not found.
    """
    match = re.search(f"{header}.*", output, re.MULTILINE | re.DOTALL)
    if not match:
        return None
    return "\n".join(match.group(0).split("\n")[:num_lines])

def get_daos_commit(output_file_path, slurm_job_id):
    """Get the DAOS commit for a given log file.

    First tries repo_info_{slurm_job_id}.txt, then defaults to repo_info.txt.

    Args:
        output_file_path (str): Path to the log output.
        slurm_job_id (str): The slurm job id.

    Returns:
        str: The DAOS commit hash.
            None if not found.
    """
    dir_name = dirname(output_file_path)

    if slurm_job_id:
        repo_info_path = join(dir_name, f"repo_info_{slurm_job_id}.txt")
    else:
        repo_info_path = join(dir_name, "repo_info.txt")
    if not os.path.isfile(repo_info_path):
        return None
    with open(repo_info_path, "r") as f:
        repo_info = f.read()
    match = re.search("^Repo:.*daos\.git\ncommit (.*)", repo_info, re.MULTILINE)
    if not match:
        return None
    return match.group(1)[:7]

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

def get_mdtest_sw_hit_max(output):
    """Get the stonewall hit max from mdtest.

    Args:
        output (str): The mdtest output.

    Returns:
        str: The stonewall hit max value.
             None if not found.
    """
    pattern = re.compile("^Continue stonewall hit.* max: ([0-9]*) ", re.MULTILINE)
    match = pattern.search(output)
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
        float: The metric value in GiB, to 2 decimal places.
               0 if not found.
    """
    pattern = re.compile(f"^{metric_name}: *([0-9|\.]*)", re.MULTILINE)
    match = pattern.search(output)
    if not match:
        return 0
    val_kib = float(match.group(1).strip())
    val_gib = val_kib / 1024
    return val_gib

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
                           ["cont_rf", "CONT_RF"],
                           ["iterations", "ITERATIONS"],
                           ["sw_time", "SW_TIME"],
                           ["n_file", "N_FILE"],
                           ["chunk_size", "CHUNK_SIZE"],
                           ["bytes_read", "BYTES_READ"],
                           ["bytes_write", "BYTES_WRITE"],
                           ["tree_depth", "TREE_DEPTH"],
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
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "fpp":          "File Per Process",
            "segments":     "Segments",
            "xfer_size":    "Xfer Size",
            "block_size":   "Block Size",
            "cont_rf":      "Cont RF",
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
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)
        status = TestStatus()

        wr_gib = get_ior_metric("Max Write", output)
        rd_gib = get_ior_metric("Max Read", output)

        if not row["end_time"]:
            status.fail("did not finish")
        if wr_gib <= 0:
            status.warn("write failed")
        if rd_gib <= 0:
            status.warn("read failed")
        if (wr_gib <= 0) and (rd_gib <= 0):
            status.fail()

        row["daos_commit"] = get_daos_commit(file_path, row["slurm_job_id"])
        row["write_gib"]   = format_float(wr_gib)
        row["read_gib"]    = format_float(rd_gib)
        row["status"]      = status.get_status_str()
        row["notes"]       = status.get_notes_str()

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
            "num_servers":  "Num_Servers",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "notes":        "Notes",
            "status":       "Status",
            "sw_time":      "SW Time",
            "n_file":       "Number of Files",
            "chunk_size":   "Chunk Size",
            "bytes_read":   "Bytes Read",
            "bytes_write":  "Bytes Write",
            "tree_depth":   "Tree Depth",
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
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)
        status = TestStatus()

        sw_time = row["sw_time"]
        n_file = row["n_file"]

        mdtest_rates = get_lines_after("SUMMARY rate:", 10, output)
        if not mdtest_rates or not row["end_time"]:
            status.fail("did not finish")

        if mdtest_rates:
            create_raw = get_mdtest_metric_max("File creation", mdtest_rates)
            stat_raw   = get_mdtest_metric_max("File stat", mdtest_rates)
            read_raw   = get_mdtest_metric_max("File read", mdtest_rates)
            remove_raw = get_mdtest_metric_max("File removal", mdtest_rates)
            row["create_kops"] = format_ops_to_kops(create_raw)
            row["stat_kops"]   = format_ops_to_kops(stat_raw)
            row["read_kops"]   = format_ops_to_kops(read_raw)
            row["remove_kops"] = format_ops_to_kops(remove_raw)

        if n_file:
            sw_hit_max = get_mdtest_sw_hit_max(output)
            if sw_hit_max and (int(sw_hit_max) >= int(n_file)):
                status.warn(f"{n_file} sw hit")

        if mdtest_rates and sw_time:
            mdtest_times = get_lines_after("SUMMARY time:", 10, output)
            if mdtest_times:
                create_time_raw = get_mdtest_metric_max("File creation", mdtest_times)
                if float(create_time_raw) < float(sw_time):
                    status.warn("create < SW_TIME")

        if sw_time and (int(sw_time) != 60):
            status.note(f"sw={sw_time}s")

        row["daos_commit"] = get_daos_commit(file_path, row["slurm_job_id"])
        row["status"]      = status.get_status_str()
        row["notes"]       = status.get_notes_str()

class CsvRebuild(CsvBase):
    """Class for generating a CSV with rebuild results."""

    def __init__(self, csv_file_path, output_style="full"):
        """Initialize a CSV rebuild object.

        Args:
            csv_file_path (str): Path the the CSV file.
            output_style (str, optional): full or simple output.

        """
        row_template = {
            "slurm_job_id":    "Slurm Job ID",
            "test_case":       "Test Case",
            "start_time":      "Date",
            "end_time":        "End",
            "daos_commit":     "Commit",
            "num_servers":     "Num_Servers",
            "num_pools":       "Num_Pools",
            "rebuild_kill":    "Rebuild Kill",
            "rebuild_start":   "Rebuild Start",
            "rebuild_end":     "Rebuild End",
            "rebuild_detect":  "Rebuild Detection",
            "rebuild_elapsed": "Rebuild Time",
            "status":          "Status",
            "notes":           "Notes"
        }
        row_order = ["test_case", "start_time", "daos_commit",
                     "num_servers", "num_pools", "rebuild_detect",
                     "rebuild_elapsed", "end_time", "notes",
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
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)
        status = TestStatus()

        num_pools = row["num_pools"]

        kill_time               = get_test_param("Kill Time", ":", output)
        num_pools_after_rebuild = get_test_param("NUM_POOLS_AFTER_REBUILD", ":", output, 0)
        num_pools_rebuild_done  = get_test_param("NUM_POOLS_REBUILD_DONE", ":", output, 0)

        if int(num_pools_after_rebuild) != int(num_pools):
            status.warn(f"num_pools_after_rebuild={num_pools_after_rebuild},")
        if int(num_pools_rebuild_done) != int(num_pools):
            status.warn(f"num_pools_rebuild_done={num_pools_rebuild_done},")

        log_dir = join(dirname(file_path), row["slurm_job_id"], "logs")

        rebuild_start = None
        rebuild_end = None
        rebuild_detect = None
        rebuild_elapsed = None

        # Get a list of all queued and completed times
        control_log_list = []
        rebuild_queued = []
        rebuild_completed = []
        if os.path.isdir(log_dir):
            path_obj = Path(log_dir)
            control_log_list = sorted(path_obj.rglob("daos_control.log"))
        for control_log in control_log_list:
            with open(control_log, 'r') as f:
                control_log_output = f.read()
            pattern = re.compile("INFO (.*) daos_engine.*Rebuild \[queued\]", re.MULTILINE)
            match = pattern.search(control_log_output)
            if not match:
                continue
            rebuild_queued.append(match.group(1).strip())
            pattern = re.compile("INFO (.*) daos_engine.*Rebuild \[completed\]", re.MULTILINE)
            match = pattern.search(control_log_output)
            if not match:
                continue
            rebuild_completed.append(match.group(1).strip())

        # Start time is when the first rebuild was queued
        if rebuild_queued:
            rebuild_queued.sort()
            rebuild_start = rebuild_queued[0]

        # End time is when the last rebuild completed
        if rebuild_completed:
            rebuild_completed.sort()
            rebuild_end = rebuild_completed[-1]

        if rebuild_start:
            rebuild_detect = get_timestamp_diff_rebuild_detect(kill_time, rebuild_start)
        if rebuild_start and rebuild_end:
            rebuild_elapsed = get_timestamp_diff_rebuild(rebuild_start, rebuild_end)

        if not (kill_time and rebuild_start and rebuild_end):
            status.fail("did not finish")

        row["rebuild_kill"]    = format_timestamp(kill_time)
        row["rebuild_start"]   = format_timestamp_daos_log(rebuild_start)
        row["rebuild_end"]     = format_timestamp_daos_log(rebuild_end)
        row["rebuild_detect"]  = rebuild_detect
        row["rebuild_elapsed"] = rebuild_elapsed
        row["daos_commit"]     = get_daos_commit(file_path, row["slurm_job_id"])
        row["status"]          = status.get_status_str()
        row["notes"]           = status.get_notes_str()

def get_stdout_list(result_path, prefix):
    """Get a list of stdout files for a given prefix.

    Args:
        result_path (str): Path to the top-level directory.
        prefix (str): Directory prefix.
            For example: mdtest, ior, rebuild.

    Returns:
        list: List of sorted paths to stdout files.
    """
    # Recursively drill down to find each stdout file in each log directory
    # in each directory
    path_obj = Path(result_path)
    glob_path = f"{prefix}_*/log_*/stdout*"
    output_file_list = sorted(path_obj.rglob(glob_path))
    if not output_file_list and prefix in result_path:
        output_file_list = sorted(path_obj.rglob("log_*/stdout*"))
    if not output_file_list and prefix in result_path:
        output_file_list = sorted(path_obj.rglob("stdout*"))
    if not output_file_list:
        print(f"No {prefix} log files found", flush=True)
    return output_file_list

def generate_results(result_dir, prefix, csv_class, csv_path, output_style):
    """Generate a CSV from a directry containing results.

    Args:
        result_dir (str): Path the results directory.
        prefix (str): Test prefix to filter directories.
            E.g. mdtest, ior, rebuild.
        csv_class (CsvBase): The csv class to format/generate the results.
            E.g. CsvMdtest, CsvIor, CsvRebuild.
        csv_path (str): Path to the generated csv.
        output_style (str): full or simple output.

    Returns:
        bool: True if results were found; False if not.
    """
    if not issubclass(csv_class, CsvBase):
        print(f"{csv_class} is not a subclass of CsvBase")
        return False

    output_file_list = get_stdout_list(result_dir, prefix)
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
        print("Failed to send email.")
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
        print("ERROR: group_by must be int or str")
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

def main(result_path, tests=["all"], output_format="csv", output_style="full",
         email_list=[]):
    """See __main__ below for arguments."""
    all_tests = ["ior", "mdtest", "rebuild"]
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
        print(f"ERROR: {result_path} is not a directory")
        return 1

    if output_format == "xlsx" and not xlsxwriter:
        print("ERROR: xlsxwriter not found")
        return 1

    for i, email in enumerate(email_list):
        if email in EMAIL_DICT.keys():
            email_list[i] = EMAIL_DICT[email]
        elif not (email.endswith("intel.com")
                  or email in EMAIL_DICT.values()):
            # Restrict email addresses se we don't accidentally get blacklisted
            # for email typos.
            print("ERROR: email must end with 'intel.com' or be in the dictionary:\n" +
                  get_email_str())
            return 1

    print("\n" +
          f"Result Path: {result_path}\n" +
          f"Result Name: {result_name}\n" +
          f"Email: {email_list}\n", flush=True)

    # Generate results for each test in tests
    for (test, test_class) in (("ior", CsvIor),
                               ("mdtest", CsvMdtest),
                               ("rebuild", CsvRebuild)):
        if test in tests:
            print("")
            csv_name = f"{test}_result_{result_name}.csv"
            csv_path = join(result_path, csv_name)
            if generate_results(result_path, test, test_class, csv_path, output_style):
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
        default="all",
        help="comma-separated list of tests (all,ior,mdtest,rebuild)")
    parser.add_argument(
        "--format",
        type=str,
        choices=("csv", "xlsx"),
        default="csv",
        help="output format. default csv")
    parser.add_argument(
        "--style",
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
        output_format=args.format,
        output_style=args.style,
        email_list=email_list)
    exit(rc)