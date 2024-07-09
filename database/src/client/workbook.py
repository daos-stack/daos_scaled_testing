import xlsxwriter

from os.path import isfile, basename
import csv
from sys import stderr


class WorkbookOptions():
    def __init__(self, **kwargs):
        self.auto_col_width = True
        self.create_toc = True
        self.stat_cols = []
        for attr_name, attr_val in kwargs.items():
            setattr(self, attr_name, attr_val)


class Workbook():
    def __init__(self, path, options=None):
        self.path = path
        self.options = options or WorkbookOptions()
        self.workbook = None
        self._toc_worksheet = None
        self._toc_row = 0

    def __enter__(self):
        self.workbook = xlsxwriter.Workbook(self.path)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.workbook.close()

    @staticmethod
    def __auto_row_type(row):
        '''Auto convert row values to numerics.'''
        new_row = row.copy()
        types = (int, float)
        for idx, val in enumerate(new_row):
            for _type in types:
                try:
                    new_row[idx] = _type(val)
                    break
                except:
                    pass
        return new_row

    @staticmethod
    def __idx_to_xls_col(idx):
        quotient = int(idx / 26) - 1
        remainder = idx % 26
        col = ''
        if quotient >= 0:
            col += Workbook.__idx_to_xls_col(quotient)
        return col + chr(ord('A') + remainder)

    def __toc_create(self):
        if self.options.create_toc:
            self._toc_worksheet = self.workbook.add_worksheet('TOC')

    def __toc_add_entry(self, worksheet):
        # Bi-directional link between toc<->worksheet_name
        worksheet.write_url(0, 0, 'internal:toc!A1', string='Return to TOC')
        self._toc_worksheet.write_url(
            self._toc_row, 0, f"internal:'{worksheet.name}'!A1", string=worksheet.name)
        self._toc_row += 1

    def __add_worksheet(self, name=None, rows=None):
        rows = rows or []
        worksheet = self.workbook.add_worksheet(name)
        row_offset = 0

        # Add entry to TOC
        if self._toc_worksheet is not None:
            self.__toc_add_entry(worksheet)
            row_offset = 1

        # Write the rows
        for row_idx, row in enumerate(rows):
            worksheet.write_row(row_idx + row_offset, 0, self.__auto_row_type(row))

        # Write some aggregate statistics
        if self.options.stat_cols:
            stat_format = self.workbook.add_format()
            stat_format.set_num_format('General;[Red][<-5]-General;General')
            row_idx = len(rows) + row_offset + 1 # One blank line after last row
            worksheet.write_column(row_idx, len(rows[0]), ['Min', 'Max', 'Mean'])
            for col in self.options.stat_cols:
                if isinstance(col, int):
                    col_idx = col
                else:
                    try:
                        col_idx = rows[0].index(col)
                    except ValueError:
                        continue
                col_letter = self.__idx_to_xls_col(col_idx)
                row_start_1 = row_offset + 2 # offset + header - 1-based index
                row_end_1 = row_start_1 + len(rows) - 2 # 1-based index
                col_range = f'{col_letter}{row_start_1}:{col_letter}{row_end_1}'
                worksheet.write_column(
                    row_idx, col_idx, [
                        f'=ROUND(MIN({col_range}),2)',
                        f'=ROUND(MAX({col_range}),2)',
                        f'=ROUND(AVERAGE({col_range}),2)'], stat_format)

        # Auto-fit the width of each column
        if self.options.auto_col_width:
            for col_i in range(len(rows[0])):
                worksheet.set_column(col_i, col_i, max([len(row[col_i]) for row in rows]))

        return worksheet

    @classmethod
    def from_csv(cls, path, csv_list, group_by_col=None, group_by_csv=False, sheet_names=None, workbook_options=None):
        with cls(path, workbook_options) as w:
            w.csv_to_xlsx(csv_list, group_by_col, group_by_csv, sheet_names)
        return w

    def csv_to_xlsx(self, csv_list, group_by_col=None, group_by_csv=False, sheet_names=None):
        '''Convert a single or list of CSV files to XLSX format.
        Args:
            csv_list (str/list): single string or list of CSV file paths.
            group_by_col (int/str, optional): column index or column header name to
                group by. Each group will be put on a separate sheet.
            group_by_csv (bool, optional): whether to group each csv into a
                separate sheet. Incompatible with group_by_col.
            sheet_names (list, optional): sheet names to use when grouping by csv.
                Default uses basename of each csv file path.
        '''
        if not csv_list:
            raise Exception('No CSVs provided')

        if group_by_col and group_by_csv:
            raise Exception('group_by_col is not compatible with group_by_csv')

        if sheet_names and not group_by_csv:
            raise Exception('sheet_names is only valid with group_by_csv')

        if not isinstance(csv_list, list):
            csv_list = [csv_list]

        for csv_file in csv_list:
            if not isfile(csv_file):
                raise Exception(f'Not a file: {csv_file}')

        if group_by_csv and not sheet_names:
            sheet_names = []
            for csv_file in csv_list:
                sheet_names.append(basename(csv_file_path).replace('.csv', ''))

        # Allow grouping by an integer col index or string col name
        group_by_index = None
        group_by_name = None
        if isinstance(group_by_col, int):
            group_by_index = group_by_col
        elif isinstance(group_by_col, str):
            group_by_name = group_by_col
        elif group_by_col is not None:
            raise Exception('group_by_col must be int or str')

        # Create a dictionary where each entry is an array
        # containing all results for a given group.
        # Each row is grouped by group_by, or 'other' if not matching.
        worksheet_dict = {}
        for index, csv_file_path in enumerate(csv_list):
            with open(csv_file_path, 'rt') as csv_file:
                reader = csv.DictReader(csv_file)
                worksheet_name = 'other'
                group_by_key = None
                if group_by_index:
                    group_by_key = reader.fieldnames[group_by_index]
                elif group_by_name:
                    group_by_key = group_by_name
                elif group_by_csv:
                    worksheet_name = sheet_names[index]

                for row in reader:
                    if group_by_key:
                        worksheet_name = row[group_by_key]

                    # The header for a group is the header of the first csv
                    # that contains a row in the group
                    if worksheet_name not in worksheet_dict:
                        worksheet_dict[worksheet_name] = [reader.fieldnames]

                    # Save a copy of the row to avoid use-after-free errors
                    worksheet_dict[worksheet_name].append(list(row.values()).copy())

        # Create a workbook where each worksheet is a group.
        if (group_by_col or group_by_csv) and (len(worksheet_dict) > 1):
            self.__toc_create()

        for worksheet_name, worksheet_rows in worksheet_dict.items():
            _name = worksheet_name if (group_by_col or group_by_csv) else None
            self.__add_worksheet(_name, worksheet_rows)
