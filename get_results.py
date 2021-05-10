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
FORMAT_TIMESTAMP_OUT = "%m/%d/%Y %H:%M:%S"

def match_single_group(expr, text, flags=0):
    """Regex match and return a single group.

    Args:
        expr (str): The regex expression.
        text (str): The text to match on.
        flags (int, optional): The regex flags.

    Returns:
        str: group(1) of the match.
             None if not found.
    """
    pattern = re.compile(expr, flags)
    match = pattern.search(text)
    if match:
        return str(match.group(1)).strip()
    return None

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
    for _delim in delim:
        pattern = re.compile(f"^{param} *{_delim} *(.*)", re.MULTILINE)
        match = pattern.search(output)
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
        return str(timestamp)
    return convert_timestamp(
        timestamp,
        FORMAT_TIMESTAMP_TEST,
        FORMAT_TIMESTAMP_OUT)

def get_timestamp_diff(timestamp1, timestamp2):
    """Get the approximate difference in minutes between two timestamps.

    Args:
        timestamp1 (str): Representation of the start timestamp.
        timestamp2 (str): Representation of the end timestamp.

    Returns:
        int: The approximate difference in minutes.
        0 if invalid timestamps.
    """
    if not timestamp1 or not timestamp2:
        return 0
    timestamp_obj1 = datetime.datetime.strptime(timestamp1, FORMAT_TIMESTAMP_TEST)
    timestamp_obj2 = datetime.datetime.strptime(timestamp2, FORMAT_TIMESTAMP_TEST)
    timestamp_diff = timestamp_obj2 - timestamp_obj1
    seconds = timestamp_diff.total_seconds()
    minutes = int(round(seconds / 60))
    return minutes

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
    pattern = re.compile(f"{header}.*", re.MULTILINE | re.DOTALL)
    match = pattern.search(output)
    if not match:
        return None
    s = "\n".join(match.group(0).split("\n")[:num_lines])
    return s

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
    pattern = re.compile("^Repo:.*daos\.git\ncommit (.*)", re.MULTILINE)
    match = pattern.search(repo_info)
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
             0 if not found.
    """
    pattern = re.compile(f" *{metric}(.*)", re.MULTILINE)
    match = pattern.search(output)
    if not match:
        return 0

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

    def __init__(self, csv_file_path, row_template={},
                 row_order=[], row_sort=[]):
        """Initialize a CSV object.
        
        Args:
            csv_file_path (str): Path the the CSV file to write to.
            row_template (dict): Key/Value pairs for new rows.
                Also serves as the header row.
            row_order (list): Order of keys on write.
            row_sort (list): [key, val_type] pairs for sorting.
                For example: [['my_key', int], ['foo', str]].
        """
        self.csv_file_path = csv_file_path
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
        """Try to get all common test params.

        Args:
            row (dict): A row in self.rows to store the params.
            output (str): The output to search in.
        """
        for key, label in [["slurm_job_id", "SLURM_JOB_ID"],
                           ["num_servers", "DAOS_SERVERS"],
                           ["num_clients", "DAOS_CLIENTS"],
                           ["num_ranks", "RANKS"],
                           ["ppc", "PPC"],
                           ["oclass", "OCLASS"],
                           ["test_case", "TESTCASE"]]:
            if key in row:
                row[key] = get_test_param(label, ":=", output)

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
            writer = csv.DictWriter(csv_file, self.row_order,
                                    extrasaction="ignore")
            writer.writeheader()
            writer.writerows(self.rows)
            #writer.writerows([self.row_template] + self.rows)
            csv_file.flush()
        print("Done", flush=True)
        print(f"CSV Path: {self.csv_file_path}", flush=True)

class CsvIor(CsvBase):
    """Class for generating a CSV with IOR results."""

    def __init__(self, csv_file_path):
        """Initialize a CSV IOR object.
        
        Args:
            csv_file_path (str): Path the the CSV file.
        """
        row_template = {
            "test_case":    "Test Case",
            "start_time":   "Date",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "num_servers":  "Num_Servers",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "num_ranks":        "Ranks",
            "write_gib":    "Write (GiB/sec)",
            "read_gib":     "Read (GiB/sec)",
            "eta_min":      "ETA (min)",
            "end_time":     "End",
            "notes":        "Notes",
            "status":       "Status",
            "write_10":     "1.0 Write", # placeholder
            "read_10":      "1.0 Read",  # placeholder
            "slurm_job_id": "Slurm Job ID"
        }
        row_order = ["test_case", "start_time", "daos_commit", "oclass",
                     "num_servers", "num_clients", "ppc", "num_ranks",
                     "write_gib", "write_10", "read_gib", "read_10",
                     "eta_min", "notes", "status", "slurm_job_id"]

        row_sort = [["test_case", str], ["num_servers", int]]

        super().__init__(csv_file_path, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from an IOR result file.

        Args:
            file_path (str): Path to the result file.
        """
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)

        start_time   = get_test_param("Start Time", ":", output)
        end_time     = get_test_param("End Time", ":", output)
        wr_gib       = get_ior_metric("Max Write", output)
        rd_gib       = get_ior_metric("Max Read", output)
        status = TestStatus()

        if not end_time:
            status.fail("did not finish")
        if wr_gib <= 0:
            status.warn("write failed")
        if rd_gib <= 0:
            status.warn("read failed")
        if (wr_gib <= 0) and (rd_gib <= 0):
            status.fail()

        row["start_time"]  = format_timestamp(start_time)
        row["end_time"]    = format_timestamp(end_time)
        row["daos_commit"] = get_daos_commit(file_path, row["slurm_job_id"])
        row["eta_min"]     = get_timestamp_diff(start_time, end_time)
        row["write_gib"]   = format_float(wr_gib)
        row["read_gib"]    = format_float(rd_gib)
        row["status"]      = status.get_status_str()
        row["notes"]       = status.get_notes_str()

class CsvMdtest(CsvBase):
    """Class for generating a CSV with MDTEST results."""

    def __init__(self, csv_file_path):
        """Initialize a CSV MDTEST object.

        Args:
            csv_file_path (str): Path the the CSV file.
        """
        row_template = {
            "test_case":    "Test Case",
            "start_time":   "Date",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "num_servers":  "Num_Servers",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "num_ranks":    "Ranks",
            "create_kops":  "create(Kops/sec)",
            "stat_kops":    "stat(Kops/sec)",
            "read_kops":    "read(Kops/sec)",
            "remove_kops":  "remove(Kops/sec)",
            "eta_min":      "ETA (min)",
            "create_ops":   "creates/sec",
            "stat_ops":     "stat/sec",
            "read_ops":     "reads/sec",
            "remove_ops":   "remove/sec",
            "end_time":     "End",
            "status":       "Status",
            "notes":        "Notes",
            "create_10":    "1.0 Create", # placeholder
            "stat_10":      "1.0 Stat",   # placeholder
            "read_10":      "1.0 Read",   # placeholder
            "remove_10":    "1.0 Remove", # placeholder
            "slurm_job_id": "Slurm Job ID"
        }
        row_order = ["test_case", "start_time", "daos_commit", "oclass",
                     "num_servers", "num_clients", "ppc", "num_ranks", "create_kops",
                     "create_10", "stat_kops", "stat_10", "read_kops",
                     "read_10", "remove_kops", "remove_10", "eta_min",
                     "notes", "status"]

        row_sort = [["test_case", str], ["num_servers", int]]

        super().__init__(csv_file_path, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from an MDTEST result file.

        Args:
            file_path (str): Path to the result file.
        """
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)

        start_time   = get_test_param("Start Time", ":", output)
        end_time     = get_test_param("End Time", ":", output)
        sw_time      = get_test_param("SW_TIME", ":", output)
        n_file       = get_test_param("N_FILE", ":", output)
        status = TestStatus()

        mdtest_rates = get_lines_after("SUMMARY rate:", 10, output)
        create_raw = 0
        stat_raw = 0
        read_raw = 0
        removal_raw = 0
        if not mdtest_rates or not end_time:
            status.fail("did not finish")

        if mdtest_rates:
            create_raw = get_mdtest_metric_max("File creation", mdtest_rates)
            stat_raw = get_mdtest_metric_max("File stat", mdtest_rates)
            read_raw = get_mdtest_metric_max("File read", mdtest_rates)
            removal_raw = get_mdtest_metric_max("File removal", mdtest_rates)

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

        row["start_time"]   = format_timestamp(start_time)
        row["end_time"]     = format_timestamp(end_time)
        row["create_kops"]  = format_ops_to_kops(create_raw)
        row["stat_kops"]    = format_ops_to_kops(stat_raw)
        row["read_kops"]    = format_ops_to_kops(read_raw)
        row["remove_kops"]  = format_ops_to_kops(removal_raw)
        row["create_ops"]   = format_float(create_raw)
        row["stat_ops"]     = format_float(stat_raw)
        row["read_ops"]     = format_float(read_raw)
        row["remove_ops"]   = format_float(removal_raw)
        row["daos_commit"]  = get_daos_commit(file_path, row["slurm_job_id"])
        row["eta_min"]      = get_timestamp_diff(start_time, end_time)
        row["status"]       = status.get_status_str()
        row["notes"]        = status.get_notes_str()

class CsvRebuild(CsvBase):
    """Class for generating a CSV with rebuild results."""

    def __init__(self, csv_file_path):
        """Initialize a CSV rebuild object.

        Args:
            csv_file_path (str): Path the the CSV file.
        """
        row_template = {
            "test_case":       "Test Case",
            "start_time":      "Date",
            "daos_commit":     "Commit",
            "num_servers":     "Num_Servers",
            "num_pools":       "Num_Pools",
            "rebuild_kill":    "Rebuild Kill",
            "rebuild_start":   "Rebuild Start",
            "rebuild_end":     "Rebuild End",
            "rebuild_detect":  "Rebuild Detection",
            "rebuild_elapsed": "Rebuild Time",
            "eta_min":         "ETA (min)",
            "end_time":        "End",
            "status":          "Status",
            "notes":           "Notes",
            "slurm_job_id":    "Slurm Job ID"
        }
        row_order = ["test_case", "start_time", "daos_commit",
                     "num_servers", "num_pools", "rebuild_detect",
                     "rebuild_elapsed", "eta_min", "end_time", "notes",
                     "status"]
        csv_file_path = csv_file_path

        row_sort = [["test_case", str],
                    ["num_servers", int],
                    ["num_pools", int]]

        super().__init__(csv_file_path, row_template, row_order, row_sort)

    def process_result_file(self, file_path):
        """Extract results from a rebuild result file.

        Args:
            file_path (str): Path to the result file.
        """
        with open(file_path, 'r') as f:
            output = f.read()

        row = self.new_row(output)

        start_time              = get_test_param("Start Time", ":", output)
        end_time                = get_test_param("End Time", ":", output)
        kill_time               = get_test_param("Kill Time", ":", output)
        num_pools               = get_test_param("NUM_POOLS", ":", output)
        num_pools_after_rebuild = get_test_param("NUM_POOLS_AFTER_REBUILD", ":", output, 0)
        num_pools_rebuild_done  = get_test_param("NUM_POOLS_REBUILD_DONE", ":", output, 0)
        status = TestStatus()

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

        rebuild_completed.sort()

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

        row["num_pools"]       = num_pools
        row["start_time"]      = format_timestamp(start_time)
        row["end_time"]        = format_timestamp(end_time)
        row["rebuild_kill"]    = format_timestamp(kill_time)
        row["rebuild_start"]   = format_timestamp_daos_log(rebuild_start)
        row["rebuild_end"]     = format_timestamp_daos_log(rebuild_end)
        row["rebuild_detect"]  = rebuild_detect
        row["rebuild_elapsed"] = rebuild_elapsed
        row["daos_commit"]     = get_daos_commit(file_path, row["slurm_job_id"])
        row["eta_min"]         = get_timestamp_diff(start_time, end_time)
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

def generate_results(result_dir, prefix, csv_class, csv_path):
    """Generate a CSV from a directry containing results.

    Args:
        result_dir (str): Path the results directory.
        prefix (str): Test prefix to filter directories.
            E.g. mdtest, ior, rebuild.
        csv_class (CsvBase): The csv class to format/generate the results.
            E.g. CsvMdtest, CsvIor, CsvRebuild.
        csv_path (str): Path to the generated csv.

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
    csv_obj = csv_class(csv_path)
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

def csv_list_to_xlsx(csv_list, xlsx_file_path):
    """Convert a list of CSV files to XLSX format.

    Args:
        csv_list (list): List of CSV file paths.
        xlsx_file_path (str): Path to the XLSX workbook.

    Returns:
        bool: True/False if successful.
    """
    print("\nWriting rows to XLSX... ", end="", flush=True)
    if not csv_list:
        print("No CSV files provided.", flush=True)
        return False
    with xlsxwriter.Workbook(xlsx_file_path) as xlsx_file:
        # Create a main worksheet that will link to all other worksheets
        main_worksheet = xlsx_file.add_worksheet("main")
        main_row = 0

        for csv_file_path in csv_list:
            with open(csv_file_path, 'rt') as csv_file:
                # Create a dictionary where each entry is an array
                # containing all results for a given test case.
                # Assumes the first row in the csv is the header row
                # and the first column of each data row is the test case name.
                test_case_dict = {}
                reader = csv.reader(csv_file)
                header_row = []
                for row_idx, row in enumerate(reader):
                    if row_idx == 0:
                        header_row = row[1:]
                        continue
                    test_case = row[0]
                    if test_case not in test_case_dict:
                        test_case_dict[test_case] = [row[1:]]
                    else:
                        test_case_dict[test_case].append(row[1:])

                # Create a separate worksheet for each test case
                # and create links between main<->test_case
                for test_case in test_case_dict:
                    worksheet_name = test_case
                    worksheet = xlsx_file.add_worksheet(worksheet_name)
                    worksheet.write_url(0, 0, "internal:main!A1", string="Go back to main")
                    main_worksheet.write_url(main_row, 0,
                                             f"internal:{test_case}!A1",
                                             string=test_case)
                    main_row += 1
                    for row_idx, row in enumerate([header_row] + test_case_dict[test_case]):
                        for col_idx, val in enumerate(row):
                            worksheet.write(row_idx + 1, col_idx, val)
    print("Done", flush=True)
    print(f"XLSX Path: {xlsx_file_path}", flush=True)
    return True

def main(result_path, no_ior=False, no_mdtest=False, no_rebuild=False,
         excel=False, email_list=None):
    """See __main__ below for arguments."""
    result_path = result_path.rstrip("/")
    result_name = os.path.basename(result_path)
    do_ior = not no_ior
    do_mdtest = not no_mdtest
    do_rebuild = not no_rebuild
    output_list = []

    if not os.path.isdir(result_path):
        print(f"ERROR: {result_path} is not a directory")
        return 1

    if not xlsxwriter:
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

    if do_ior:
        print("")
        ior_csv_name = f"ior_result_{result_name}.csv"
        ior_csv_path = join(result_path, ior_csv_name)
        if generate_results(result_path, "ior", CsvIor, ior_csv_path):
            output_list.append(ior_csv_path)
    if do_mdtest:
        print("")
        mdtest_csv_name = f"mdtest_result_{result_name}.csv"
        mdtest_csv_path = join(result_path, mdtest_csv_name)
        if generate_results(result_path, "mdtest", CsvMdtest, mdtest_csv_path):
            output_list.append(mdtest_csv_path)
    if do_rebuild:
        print("")
        rebuild_csv_name = f"rebuild_result_{result_name}.csv"
        rebuild_csv_path = join(result_path, rebuild_csv_name)
        if generate_results(result_path, "rebuild", CsvRebuild, rebuild_csv_path):
            output_list.append(rebuild_csv_path)

    if not output_list:
        print("No results generated.")
        return 1

    if excel and output_list:
        excel_file_name = f"result_{result_name}.xlsx"
        excel_file_path = join(result_path, excel_file_name)
        if csv_list_to_xlsx(output_list, excel_file_path):
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
        "--no-ior",
        action="store_true",
        help="don't generate ior results")
    parser.add_argument(
        "--no-mdtest",
        action="store_true",
        help="don't generate mdtest results")
    parser.add_argument(
        "--no-rebuild",
        action="store_true",
        help="don't generate rebuild results")
    parser.add_argument(
        "--excel",
        action="store_true",
        help="also add results to a .xlsx format")
    parser.add_argument(
        "--email",
        type=str,
        help="email addresses or names to send result csv(s) to\n" +
             "Must end with 'intel.com' or be in the dictionary:\n" + get_email_str())
    args = parser.parse_args()
    email_list = []
    if args.email:
        email_list = args.email.split(",")
    exit(main(
        result_path=args.result_path,
        no_ior=args.no_ior,
        no_mdtest=args.no_mdtest,
        no_rebuild=args.no_rebuild,
        excel=args.excel,
        email_list=email_list))
