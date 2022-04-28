
from os.path import isfile, basename
import os
import csv
import subprocess
import tempfile
import sys
import textwrap

try:
    from .workbook import Workbook, WorkbookOptions
except:
    Workbook = None

try:
    from tabulate import tabulate
except:
    tabulate = None

def print_err(message):
    '''Print a standardized error message.

    Args:
        message (str): the message to print.

    '''
    print(f'ERR {message}', file=sys.stderr)

def print_arr_tabular(arr, file=sys.stdout, header=True):
    '''Print a 2D array in a tabular/aligned format.
    Args:
        arr (iter): 2D iterable object. E.g. list of rows.
            Rows are assumed to have the same length.
            Each row is assumed to be string-like.
        file (file): file-like object to print to.
            Defaut is sys.stdout.
        header (bool, optional): whether to print a header after the first row.
            Default is True
    '''
    # Use tabulate module if available
    if tabulate is not None:
        wrapped_arr = []
        for row in arr:
            wrapped_row = []
            for col in row:
                wrapped_row.append('\n'.join(
                    [textwrap.fill(line, 50, break_long_words=False, replace_whitespace=False)
                    for line in str(col).splitlines() if line.strip() != '']))
            wrapped_arr.append(wrapped_row)
        print(tabulate(wrapped_arr, headers="firstrow", tablefmt="psql"), file=file)
        return

    # Use custom tabulation
    arr = list(arr)
    for row_idx, row in enumerate(arr):
        if row_idx == 0:
            col_widths = [0] * len(row)
        for col_idx, col_val in enumerate(row):
            col_len = len(str(col_val))
            if col_len > col_widths[col_idx]:
                col_widths[col_idx] = col_len

    for row_idx, row in enumerate(arr):
        for col_idx, col_val in enumerate(row):
            print(f'{str(col_val).ljust(col_widths[col_idx])}  ', end='', file=file)
        if row_idx == 0 and header:
            print('', file=file)
            for col_idx in range(len(col_widths)):
                print(f'{"-" * col_widths[col_idx]}  ', end='', file=file)
        print('', file=file)

def confirm(message):
    '''Get user confirmation for a message.

    Args:
        message (str): the message to cofirm.

    Returns:
        True if the message is confirmed. False otherwise.

    '''
    while True:
        response = input(f'{message} (Yes/No): ').lower()
        if response in ('y', 'yes'):
            return True
        if response in ('n', 'no'):
            return False
        print('Invalid response (Yes/No)')

def send_email(address, subject, body='', attachments=[]):
    '''Send an email using the mail command.

    Args:
        address (str/list): single string or list of addresses to send to.
        subject (str): email subject.
        body (str, optional): email body.
        attachments (str, optional): single string or list of file paths to
            attach to the email.

    Returns:
        bool: True if successful. False otherwise.

    '''
    if not isinstance(address, list):
        address = [address]
    if not isinstance(attachments, list):
        attachments = [attachments]

    address_str = ' '.join(address)
    attach_str = ''
    for path in attach_str:
        if not isfile(path):
            print_err(f'Not a file: {path}')
            return False
        attach_str += f'-a "{path}" '

    mail_cmd = f'echo "{body}" | mail -s "{subject}" {attach_str} {address_str}'
    result = subprocess.run(mail_cmd, shell=True)
    if result.returncode != 0:
        print_err('Failed to send email.')
        return False
    return True

def list_to_csv(data, csv_path):
    '''Convert an iterable object to CSV.

    Args:
        data (list): iterable object.
        csv_path: (str): path to the CSV.

    Returns:
        bool: True if successful. False otherwise.

    '''
    with open(csv_path, 'w') as f:
        writer = csv.writer(f)
        for row in data:
            writer.writerow(row)
    return True

def csv_to_xlsx(csv_list, xlsx_file_path, group_by_col=None, group_by_csv=False, sheet_names=None):
    '''Convert a single or list of CSV files to XLSX format.
    Args:
        csv_list (str/list): single string or list of CSV file paths.
        xlsx_file_path (str): path to the XLSX workbook.
        group_by_col (int/str, optional): column index or column header name to
            group by. Each group will be put on a separate sheet.
        group_by_csv (bool, optional): whether to group each csv into a
            separate sheet. Incompatible with group_by_col.
        sheet_names (list, optional): sheet names to use when grouping by csv.
            Default uses basename of each csv file path.
    Returns:
        bool: True on success. False otherwise.
    '''
    # TODO cleaner
    if Workbook is None:
        print_err('Not installed: xlsxwriter')
        return None
    # TODO cleaner
    options = WorkbookOptions(
        stat_cols=['write_gib%', 'read_gib%', 'create%', 'stat%', 'read%', 'remove%'])
    Workbook.from_csv(xlsx_file_path, csv_list, group_by_col, group_by_csv, sheet_names, options)

def list_to_output_type(data, output_type='table', file=sys.stdout, data_dims=1, xlsx_sheet_names=None):
    """Convert list(s) of data to various output types.
    
    Args:
        data (list): single list of rows, or list of lists of rows.
        output_type (str, optional): table, csv, or xlsx. Default is table.
        file (str/obj, optional): if str, the output path. If obj, the open stream to write to.
            Default is sys.stdout.
        data_dims (int, optional): 1 or 2 for data dimensions.
            E.g.: 1 -> ['a', 'b', 'c']
                  2 -> [['a', 'b', 'c'], ['d', 'e']]
        xlsx_sheet_names (list, optional): list of sheet names for xlsx output.
            len(xlsx_sheet_names) must == len(data).
            Default uses generated tmp names.
    Returns:
        bool: True on success. False otherwise.
    """
    if data_dims == 1:
        data = [data]
    elif data_dims != 2:
        print_err('data_dims must be 1 or 2')
        return False

    need_open = isinstance(file, str)
    def return_handler(success):
        try:
            if need_open:
                f.close()
        except:
            success = False
        finally:
            return success

    f = open(file, 'w') if need_open else file
    if output_type == 'table':
        for d in data:
            print_arr_tabular(d, file=f)
        return return_handler(True)
    elif output_type == 'csv':
        writer = csv.writer(f)
        for d in data:
            writer.writerows(d)
        return return_handler(True)
    elif output_type == 'xlsx':
        if f in (sys.stdin, sys.stdout, sys.stderr):
            print_err('Refuse to write xlsx to standard IO')
            return return_handler(False)
        csv_list = []
        try:
            for d in data:
                tmp = tempfile.mkstemp()
                csv_list.append(tmp[1])
                os.close(tmp[0])
                if not list_to_csv(d, tmp[1]):
                    return return_handler(False)
            return return_handler(csv_to_xlsx(csv_list, file, group_by_csv=True, sheet_names=xlsx_sheet_names))
        finally:
            for path in csv_list:
                os.remove(path)

    return return_handler(False)
