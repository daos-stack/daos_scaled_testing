from sys import stderr, stdout
from os.path import isfile, basename
import csv
import subprocess

try:
    import xlsxwriter
except:
    xlsxwriter = None

def print_err(message):
    '''Print a standardized error message.

    Args:
        message (str): the message to print.

    '''
    print(f'ERR {message}', file=stderr)

def print_arr_tabular(arr, file=stdout):
    '''Print a 2D array in a tabular/aligned format.

    Args:
        arr (iter): 2D iterable object. E.g. list of rows.
            Rows are assumed to have the same length.
            Each row is assumed to be string-like.
        file (file): file-like object to print to.
            Defaut is stdout.

    '''
    arr = list(arr)
    for row_idx, row in enumerate(arr):
        if row_idx == 0:
            col_widths = [0] * len(row)
        for col_idx, val in enumerate(row):
            col_len = len(str(val))
            if col_len > col_widths[col_idx]:
                col_widths[col_idx] = col_len
    for row_idx, row in enumerate(arr):
        for col_idx, val in enumerate(row):
            print(f'{str(val).rjust(col_widths[col_idx])}  ', end='', file=file)
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

def csv_to_xlsx(csv_list, xlsx_file_path, group_by_col=None, group_by_csv=False):
    '''Convert a single or list of CSV files to XLSX format.

    Args:
        csv_list (str/list): single string or list of CSV file paths.
        xlsx_file_path (str): path to the XLSX workbook.
        group_by_col (int/str, optional): column index or column header name to
            group by. Each group will be put on a separate sheet.
        group_by_csv (bool, optional): whether to group each csv into a
            separate sheet. Incompatible with group_by_col.

    Returns:
        bool: True on success. False otherwise.

    '''
    if xlsxwriter is None:
        print_err('Not installed: xlsxwriter')
        return False

    if not csv_list:
        print_err('No CSVs provided')
        return False

    if group_by_col and group_by_csv:
        print_err('group_by_col is not compatible with group_by_csv')
        return False

    if not isinstance(csv_list, list):
        csv_list = [csv_list]

    for csv_file in csv_list:
        if not isfile(csv_file):
            print_err(f'Not a file: {csv_file}')
            return False

    # Allow grouping by an integer col index or string col name
    group_by_index = None
    group_by_name = None
    if isinstance(group_by_col, int):
        group_by_index = group_by_col
    elif isinstance(group_by_col, str):
        group_by_name = group_by_col
    elif group_by_col is not None:
        print_err('group_by_col must be int or str')
        return False

    # Create a dictionary where each entry is an array
    # containing all results for a given group.
    # Each row is grouped by group_by, or 'other' if not matching.
    group_dict = {}
    for csv_file_path in csv_list:
        with open(csv_file_path, 'rt') as csv_file:
            reader = csv.DictReader(csv_file)
            this_group = 'other'
            group_by_key = None
            if group_by_index:
                group_by_key = reader.fieldnames[group_by_index]
            elif group_by_name:
                group_by_key = group_by_name
            elif group_by_csv:
                this_group = basename(csv_file_path)

            for row in reader:
                if group_by_key:
                    this_group = row[group_by_key]

                # The header for a group is the header of the first csv
                # that contains a row in the group
                if this_group not in group_dict:
                    group_dict[this_group] = [reader.fieldnames]
                group_dict[this_group].append(list(row.values()))

    # Create a workbook where each worksheet is a group.
    with xlsxwriter.Workbook(xlsx_file_path) as xlsx_file:
        if group_by_col or group_by_csv:
            # Create a main worksheet that will link to all other worksheets
            main_worksheet = xlsx_file.add_worksheet('main')
            main_row = 0

        for group in group_dict:
            if group_by_col or group_by_csv:
                # Create a worksheet with the name of the group and
                # link between main<->group
                worksheet_name = group
                worksheet = xlsx_file.add_worksheet(worksheet_name)
                worksheet.write_url(0, 0, 'internal:main!A1', string='Go back to main')
                main_worksheet.write_url(main_row, 0,
                                         f"internal:'{group}'!A1",
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
