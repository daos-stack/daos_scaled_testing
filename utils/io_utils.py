from sys import stderr
from os.path import isfile
import csv
import subprocess

try:
    import xlsxwriter
except:
    xlsxwriter = None

def print_err(message):
    """Print a standardized error message.

    Args:
        message (str): the message to print.

    """
    print(f"ERR {message}", file=stderr)

def send_email(address, subject, body="", attachments=[]):
    """Send an email using the mail command.

    Args:
        address (str/list): single string or list of addresses to send to.
        subject (str): email subject.
        body (str, optional): email body.
        attachments (str, optional): single string or list of file paths to
            attach to the email.

    Returns:
        bool: True if successful. False otherwise.

    """
    if not isinstance(address, list):
        address = [address]
    if not isinstance(attachments, list):
        attachments = [attachments]

    address_str = " ".join(address)
    attach_str = ""
    for path in attach_str:
        if not isfile(path):
            print_err(f"Not a file: {path}")
            return False
        attach_str += f"-a '{path}' "

    mail_cmd = f"echo '{body}' | mail -s '{subject}' {attach_str} {address_str}"
    result = subprocess.run(mail_cmd, shell=True)
    if result.returncode != 0:
        print_err("Failed to send email.")
        return False
    return True

def csv_to_xlsx(csv_list, xlsx_file_path, group_by=None):
    """Convert a single or list of CSV files to XLSX format.

    Args:
        csv_list (str/list): single string or list of CSV file paths.
        xlsx_file_path (str): path to the XLSX workbook.
        group_by (int/str, optional): column index or column header name to
            group by. Each group will be put on a separate sheet.

    Returns:
        bool: True on success. False otherwise.

    """
    if xlsxwriter is None:
        print_err("Not installed: xlsxwriter")
        return False

    if not csv_list:
        print_err("No CSVs provided")
        return False

    if not isinstance(csv_list, list):
        csv_list = [csv_list]

    for csv_file in csv_list:
        if not isfile(csv_file):
            print_err(f"Not a file: {csv_file}")
            return False

    # Allow grouping by an integer col index or string col name
    group_by_index = False
    group_by_name = False
    if isinstance(group_by, int):
        group_by_index = True
    elif isinstance(group_by, str):
        group_by_name = True
    elif group_by is not None:
        print_err("group_by must be int or str")
        return False

    # Create a dictionary where each entry is an array
    # containing all results for a given group.
    # Each row is grouped by group_by, or "other" if not matching.
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
                group_dict[this_group].append(list(row.values()))

    # Create a workbook where each worksheet is a group.
    with xlsxwriter.Workbook(xlsx_file_path) as xlsx_file:
        if group_by:
            # Create a main worksheet that will link to all other worksheets
            main_worksheet = xlsx_file.add_worksheet("main")
            main_row = 0

        for group in group_dict:
            if group_by:
                # Create a worksheet with the name of the group and
                # link between main<->group
                worksheet_name = group
                worksheet = xlsx_file.add_worksheet(worksheet_name)
                worksheet.write_url(0, 0, "internal:main!A1", string="Go back to main")
                main_worksheet.write_url(main_row, 0,
                                         f"internal:{group}!A1",
                                         string=group)
                main_row += 1
                row_offset = 1
            else:
                # Create a default worksheet
                worksheet = xlsx_file.add_worksheet()
                row_offset = 0

            # Write each row
            for row_idx, row in enumerate(group_dict[group]):
                worksheet.write_row(row_idx + row_offset, 0, row)

            # Auto-fit the width of each column
            widths = [max([len(row[col_i]) for row in
                        group_dict[group]]) for col_i
                            in range(len(group_dict[group][0]))]
            for col_i, width in enumerate(widths):
                worksheet.set_column(col_i, col_i, width)

    return True
