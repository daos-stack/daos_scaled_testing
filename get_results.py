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
from pathlib import Path
import subprocess
import csv

# Shorthand for mapping names to emails.
# Useful for avoiding email typos.
EMAIL_DICT = {
    "dalton": "daltonx.bohning@intel.com",
    "sylvia": "sylvia.oi.yee.chan@intel.com"
}

def get_test_param(param, delim, output, default=None):
    """Get a test param of the form PARAM={}.

    For example:
        DAOS_SERVERS=2
        nodes  :  4

    Args:
        param (str): The param to get.
            E.g. DAOS_SERVERS, DAOS_CLIENTS, PPC, nodes.
        delim (str): The delimiter between the label and value.
        output (str): The output from the mdtest run.
        default (any): What to return if not found.
            Defaults to None.

    Returns:
        str: The param value.
             default if not found.
    """
    pattern = re.compile("^{} *{} *(.*)".format(param, delim), re.MULTILINE)
    match = pattern.search(output)
    if not match:
        return default
    return str(match.group(1).strip())

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
             None on failure.
    """
    if not timestamp:
        return str(timestamp)
    return convert_timestamp(
        timestamp,
        "%a %b %d %H:%M:%S %Z %Y",
        "%m/%d/%Y %H:%M:%S")

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
    timestamp_obj1 = datetime.datetime.strptime(timestamp1, "%a %b %d %H:%M:%S %Z %Y")
    timestamp_obj2 = datetime.datetime.strptime(timestamp2, "%a %b %d %H:%M:%S %Z %Y")
    timestamp_diff = timestamp_obj2 - timestamp_obj1
    seconds = timestamp_diff.total_seconds()
    minutes = int(round(seconds / 60))
    return minutes

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
    pattern = re.compile("{}.*".format(header), re.MULTILINE | re.DOTALL)
    match = pattern.search(output)
    if not match:
        return None
    s = "\n".join(match.group(0).split("\n")[:num_lines])
    return s

def get_daos_commit(output_file_path):
    """Get the DAOS commit for a given log file.

    Args:
        output_file_path (str): Path to the log output.

    Returns:
        str: The DAOS commit hash.
            None if not found.
    """
    dir_name = os.path.dirname(output_file_path)
    repo_info_path = os.path.join(dir_name, "repo_info.txt")
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
    pattern = re.compile(" *{}(.*)".format(metric, output), re.MULTILINE)
    match = pattern.search(output)
    if not match:
        return 0

    # Of the form: "<max> <min> <mean> <std>"
    all_metrics = match.group(1).lstrip(" ")

    # Index 0 is <max>
    return all_metrics.split(" ")[0]

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
    pattern = re.compile("^{}: *([0-9|\.]*)".format(metric_name), re.MULTILINE)
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
    return "{:.2f}".format(float(val))

def format_ops_to_kops(ops):
    """Convert ops to formatted kops

    Args:
        ops (str/float): String or float ops.

    Returns:
        str: kops formatted to 2 decimal places.
    """
    return format_float(float(ops) / 1000)

def array_sort(arr, col, col_type=str):
    """Sort a multi-dimensional array by a given column.

    Uses bubble sort, which is stable.

    Args:
        arr (list): The array to sort.
        col (int): Index of the column to sort by.
        col_type (type, optional): Datatype of the column.
            Default is str (lexicographical).
    """
    arr_len = len(arr)
    swap = True
    while (swap):
        swap = False
        for row in range(1, arr_len):
            if col_type(arr[row-1][col]) > col_type(arr[row][col]):
                (arr[row-1], arr[row]) = (arr[row], arr[row-1])
                swap = True

class CsvBase():
    """Class for generating a CSV with results."""

    def __init__(self):
        """Initialize a CSV object."""
        self.csv_file_path = None
        self.rows = []

        # Dictionary template for adding new rows
        # Also servers as the header row
        self.row_template = {}

        # Dictionary keys to order the rows on write
        self.row_order = []

        # Array of [col_i, col_type] to pass to array_sort.
        self.row_sort = []

    def new_row(self):
        """Add a new row.

        Returns:
            dict: The new row.
        """
        row = dict.fromkeys(self.row_template.keys())
        self.rows.append(row)
        return row

    def sort_rows(self):
        """Sort the rows.

        Uses bubble sort, which is stable.
        """
        if not self.row_sort:
            return
        num_rows = len(self.rows)
        for key, typ in reversed(self.row_sort):
            swap = True
            while (swap):
                swap = False
                for row in range(1, num_rows):
                    if typ(self.rows[row-1][key]) > typ(self.rows[row][key]):
                        tmp = self.rows[row-1]
                        self.rows[row-1] = self.rows[row]
                        self.rows[row] = tmp
                        swap = True

    def write(self):
        """Write the internal data to CSV."""
        print("Sorting rows...", end="", flush=True)
        self.sort_rows()
        print("Done", flush=True)

        print("Writing rows...", end="", flush=True)
        with open(self.csv_file_path, 'w', newline='') as csv_file:
            writer = csv.DictWriter(csv_file, self.row_order,
                                    extrasaction="ignore")
            writer.writerows([self.row_template] + self.rows)
        print("Done", flush=True)

class CsvIor(CsvBase):
    """Class for generating a CSV with IOR results."""

    def __init__(self, csv_file_path):
        """Initialize a CSV IOR object.
        
        Args:
            csv_file_path (str): Path the the CSV file.
        """
        super().__init__()
        self.row_template = {
            "scenario":     "Scenario",
            "start_time":   "Date",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "num_servers":  "Num_Servers",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "ranks":        "Ranks",
            "write_gib":    "Write (GiB/sec)",
            "read_gib":     "Read (GiB/sec)",
            "eta_min":      "ETA (min)",
            "end_time":     "End",
            "status":       "Status",
            "write_10":     "1.0 Write", # placeholder
            "read_10":      "1.0 Read"   # placeholder
        }
        self.row_order = ["scenario", "start_time", "daos_commit", "oclass",
                          "num_servers", "num_clients", "ppc", "ranks",
                          "write_gib", "write_10", "read_gib", "read_10",
                          "eta_min", "end_time", "status"]
        self.csv_file_path = csv_file_path

        self.row_sort = [["scenario", str], ["num_servers", int]]

    def process_result_file(self, file_path):
        """Extract results from an IOR result file.

        Args:
            file_path (str): Path to the result file.
        """
        with open(file_path, 'r') as f:
            output = f.read()

        start_time = get_test_param("Start Time", ":", output)
        end_time = get_test_param("End Time", ":", output)
        wr_gib = get_ior_metric("Max Write", output)
        rd_gib = get_ior_metric("Max Read", output)

        row = self.new_row()
        row["num_servers"] = get_test_param("DAOS_SERVERS", "=", output)
        row["num_clients"] = get_test_param("DAOS_CLIENTS", "=", output)
        row["ranks"]       = get_test_param("RANKS", "=", output)
        row["ppc"]         = get_test_param("PPC", "=", output)
        row["oclass"]      = get_test_param("OCLASS", "=", output)
        row["scenario"]    = get_test_param("RUN", ":", output)
        row["start_time"]  = format_timestamp(start_time)
        row["end_time"]    = format_timestamp(end_time)
        row["daos_commit"] = get_daos_commit(file_path)
        row["eta_min"]     = get_timestamp_diff(start_time, end_time)
        row["write_gib"]   = format_float(wr_gib)
        row["read_gib"]   = format_float(rd_gib)
        if wr_gib > 0 and rd_gib > 0:
            row["status"] = "Passed"
        elif wr_gib > 0 or rd_gib > 0:
            row["status"] = "Warning"
        else:
            row["status"] = "Failed"

class CsvMdtest(CsvBase):
    """Class for generating a CSV with MDTEST results."""

    def __init__(self, csv_file_path):
        """Initialize a CSV MDTEST object.

        Args:
            csv_file_path (str): Path the the CSV file.
        """
        super().__init__()
        self.row_template = {
            "scenario":     "Scenario",
            "start_time":   "Date",
            "daos_commit":  "Commit",
            "oclass":       "Oclass",
            "num_servers":  "Num_Servers",
            "num_clients":  "Clients",
            "ppc":          "PPC",
            "ranks":        "Ranks",
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
            "create_10":    "1.0 Create", # placeholder
            "stat_10":      "1.0 Stat",   # placeholder
            "read_10":      "1.0 Read",   # placeholder
            "remove_10":    "1.0 Remove"  # placeholder
        }
        self.row_order = ["scenario", "start_time", "daos_commit",
                          "num_servers", "num_clients", "ranks", "create_kops",
                          "create_10", "stat_kops", "stat_10", "read_kops",
                          "read_10", "remove_kops", "remove_10", "eta_min",
                          "create_ops", "stat_ops", "read_ops", "remove_ops",
                          "end_time", "status"]
        self.csv_file_path = csv_file_path

        self.row_sort = [["scenario", str], ["num_servers", int]]

    def process_result_file(self, file_path):
        """Extract results from an MDTEST result file.

        Args:
            file_path (str): Path to the result file.
        """
        with open(file_path, 'r') as f:
            output = f.read()

        start_time = get_test_param("Start Time", ":", output)
        end_time = get_test_param("End Time", ":", output)

        mdtest_metrics = get_lines_after("SUMMARY rate:", 10, output)
        if mdtest_metrics:
            create_raw = get_mdtest_metric_max("File creation", mdtest_metrics)
            stat_raw = get_mdtest_metric_max("File stat", mdtest_metrics)
            read_raw = get_mdtest_metric_max("File read", mdtest_metrics)
            removal_raw = get_mdtest_metric_max("File removal", mdtest_metrics)
            status = "Passed"
        else:
            create_raw = 0
            stat_raw = 0
            read_raw = 0
            removal_raw = 0
            status = "Failed"

        row = self.new_row()
        row["num_servers"]  = get_test_param("DAOS_SERVERS", "=", output)
        row["num_clients"]  = get_test_param("DAOS_CLIENTS", "=", output)
        row["ranks"]        = get_test_param("RANKS", "=", output)
        row["ppc"]          = get_test_param("PPC", "=", output)
        row["oclass"]       = get_test_param("OCLASS", "=", output)
        row["scenario"]     = get_test_param("RUN", ":", output)
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
        row["daos_commit"]  = get_daos_commit(file_path)
        row["eta_min"]      = get_timestamp_diff(start_time, end_time)
        row["status"]       = status

def generate_mdtest_results(result_path, csv_path):
    """Generate mdtest result csv.

    Args:
        result_path (str): Path the results directory.
        csv_path (str): Path to the generated csv.

    Returns:
        bool: True if results were found; False if not.
    """
    print("Generating mdtest csv", flush=True)
    # Recursively drill down to find each stdout file in each log directory
    # in each mdtest directory.
    path_obj = Path(result_path)
    output_file_list = sorted(path_obj.rglob("mdtest_*/log_*/stdout*"))
    if not output_file_list and "mdtest" in result_path:
        output_file_list = sorted(path_obj.rglob("log_*/stdout*"))
    if not output_file_list and "mdtest" in result_path:
        output_file_list = sorted(path_obj.rglob("stdout*"))
    if not output_file_list:
        print("  No mdtest results found", flush=True)
        return False

    csv_obj = CsvMdtest(csv_path)
    for output_file in output_file_list:
        print("  Processing: {}".format(output_file), flush=True)
        csv_obj.process_result_file(output_file)
    csv_obj.write()

    print("\n** MDTEST Result CSV: {}\n".format(csv_path))
    return True

def generate_ior_results(result_path, csv_path):
    """Generate ior result csv.

    Args:
        result_path (str): Path the results directory.
        csv_path (str): Path to the generated csv.

    Returns:
        bool: True if results were found; False if not.
    """
    print("Generating ior csv", flush=True)
    # Recursively drill down to find each stdout file in each log directory
    # in each ior directory.
    path_obj = Path(result_path)
    output_file_list = sorted(path_obj.rglob("ior_*/log_*/stdout*"))
    if not output_file_list and "ior" in result_path:
        output_file_list = sorted(path_obj.rglob("log_*/stdout*"))
    if not output_file_list and "ior" in result_path:
        output_file_list = sorted(path_obj.rglob("stdout*"))
    if not output_file_list:
        print("  No ior results found", flush=True)
        return False

    csv_obj = CsvIor(csv_path)
    for output_file in output_file_list:
        print("  Processing: {}".format(output_file), flush=True)
        csv_obj.process_result_file(output_file)
    csv_obj.write()

    print("\n** IOR Result CSV: {}\n".format(csv_path))
    return True

def get_email_str():
    """Get a string representation of EMAIL_DICT.
    
    Returns:
        str: Emails formatted as:
             <name>: <email>
    """
    return "\n".join(["{}: {}".format(k, v) for k, v in EMAIL_DICT.items()])

def email_results(output_list, email_list):
    """Email the results.

    Args:
        output_list (list): List of output result paths.
            E.g. the generated csv files.
        email_list (list): List of email addresses.
    """
    # Send an email with the results
    body_cmd = 'printf "'
    attach_str = ""
    for path in output_list:
        body_cmd += "`cat '{}'`\\n\\n\\n".format(path)
        attach_str += "-a '{}' ".format(path)
    body_cmd += '"'
    subject = "Frontera Test Results"
    email_str = " ".join(email_list)
    mail_cmd = 'echo "See Attached" | mail -s "{}" {} {}'.format(
        subject, attach_str, email_str)
    print("Mailing results to {}...\n".format(email_str), flush=True)
    subprocess.run(mail_cmd, shell=True)

def main(result_path, no_ior=False, no_mdtest=False, email_list=None):
    """See __main__ below for arguments."""
    result_path = result_path.rstrip("/")
    result_name = os.path.basename(result_path)
    do_ior = not no_ior
    do_mdtest = not no_mdtest
    output_list = []

    if not os.path.isdir(result_path):
        print("ERROR: {} is not a directory".format(result_path))
        exit(1)

    for i, email in enumerate(email_list):
        if email in EMAIL_DICT.keys():
            email_list[i] = EMAIL_DICT[email]
        elif email in EMAIL_DICT.values():
            pass
        elif email.endswith("intel.com"):
            pass
        else:
            # Restrict email addresses se we don't accidentally get blacklisted
            # for email typos.
            print("ERROR: email must end with 'intel.com' or be in the dictionary:\n" +
                  get_email_str())
            return 1

    print("\n" +
          "Result Path: {}\n".format(result_path) +
          "Result Name: {}\n".format(result_name) +
          "Email: {}\n".format(email_list), flush=True)

    if do_ior:
        ior_csv_name = "ior_result_{}.csv".format(result_name)
        ior_csv_path = os.path.join(result_path, ior_csv_name)
        if generate_ior_results(result_path, ior_csv_path):
            output_list.append(ior_csv_path)
    if do_mdtest:
        mdtest_csv_name = "mdtest_result_{}.csv".format(result_name)
        mdtest_csv_path = os.path.join(result_path, mdtest_csv_name)
        if generate_mdtest_results(result_path, mdtest_csv_path):
            output_list.append(mdtest_csv_path)

    if not output_list:
        print("No results generated.")

    if output_list and email_list:
        email_results(output_list, email_list)

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
        "--email",
        type=str,
        help="email addresses or names to send result csv(s) to\n" +
             "Must end with 'intel.com' or be in the dictionary:\n" + get_email_str())
    args = parser.parse_args()
    email_list = []
    if args.email:
        email_list = args.email.split(",")
    main(args.result_path, args.no_ior, args.no_mdtest, email_list)
