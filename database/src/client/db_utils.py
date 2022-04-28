try:
    import mariadb
except:
    mariadb = None
try:
    import mysql.connector as mysql_connector
except:
    mysql_connector = None
try:
    from ClusterShell.NodeSet import NodeSet
except:
    NodeSet = None

import re
import textwrap
from os.path import isfile
from collections import defaultdict, OrderedDict
import sys
import getpass

from .io_utils import print_err
from . import io_utils


def add_config_args(parser):
    '''Add shared config args.
    
    Args:
        parser (ArgumentParser): the parser object
    '''
    parser.add_argument(
        '--config',
        default='utils/config/client.cnf',
        help='database config for connection')
    parser.add_argument(
        '-p', '--pass',
        action='store_true',
        default=False,
        help='prompt for a password. Default False')
    parser.add_argument(
        '--connector',
        type=str,
        default=None,
        choices=('mariadb', 'mysql'),
        help='connector to use. Default uses the first available.')

# TODO use this
def add_output_args(parser):
    '''Add shared output args.
    
    Args:
        parser (ArgumentParser): the parser object
    '''
    parser.add_argument(
        '--output-format', '--of',
        type=str,
        choices=('table', 'csv', 'xlsx'),
        default='table',
        help='output format')
    parser.add_argument(
        '--output-path', '-o',
        type=str,
        default=sys.stdout,
        help='output path')

def _connect(default_file=None, autocommit=False, password=None, connector=None):
    '''Wrapper for different SQL connectors.
    
    Args:
        default_file (str, optional): database config file.
        autocommit (bool) : whether SQL statements should always auto commit. Default False.
        password (str, optional): the database password. Default None.
        connector (str, optional): either "mariadb" or "mysql".
            Default tries mariadb and then mysql, as available.
    Returns:
        obj: the resultant .connect() object.
    '''
    kwargs = {'autocommit': autocommit}
    if password:
        kwargs['password'] = password
    if connector == 'mariadb' or (connector is None and mariadb is not None):
        if default_file:
            kwargs['default_file'] = default_file
        return mariadb.connect(**kwargs)
    if connector == 'mysql' or (connector is None and mysql_connector is not None):
        if default_file:
            kwargs['option_files'] = default_file
        return mysql_connector.connect(**kwargs)
    raise Exception('No valid SQL connector found')

def _cur_type(cur):
    if mysql_connector is not None and isinstance(cur, mysql_connector.cursor_cext.CMySQLCursor):
        return 'mysql'
    elif mariadb is not None:
        return 'mariadb'
    raise Exception('Unable to determine connector type')

def _cur_placeholder(cur):
    return '%s' if _cur_type(cur) == 'mysql' else '?'

def connect(args):
    '''Connect to the database.
    Args:
        args (argparse.Namespace): result of ArgumentParser.parse_args().
            Tries to use args.[config, no_pass]
            args.config (str): the config for connection. Default None.
            args.pass (bool): 
    Returns:
        connection: the database connection object.
    Raises:
        Exception: if config_path is invalid or failed to read password.
        Exception: if connection failed.
    '''
    config = getattr(args, 'config', None)
    prompt_pass = getattr(args, 'pass', False)
    connector = getattr(args, 'connector', None)
    if config and not isfile(config):
        raise Exception(f'Config not found: {config}')

    password = getpass.getpass('DB Password: ') if prompt_pass else None

    return _connect(default_file=config, autocommit=False, password=password, connector=connector)

def execute(cur, sql, values=None):
    '''Execute a single sql statement.

    Args:
        cur (cursor): cursor for the database connection.
        sql (str): the sql statement.
        values (list, optional): list of bind values.

    Returns:
        bool: True on success. False otherwise.

    '''
    sql = textwrap.dedent(sql)
    try:
        cur.execute(sql, values)
    except Exception as e:
        print_err(f'Failed to execute query:\n{sql}\n{values}\n{e}')
        return False
    return True

def execute_many(cur, sql, values=None):
    '''Execte a sql statement with a list of values.
    
    Args:
        cur (cursor): cursor for the database connection.
        sql (str): the sql statement.
        values (list): list of list of sql values.

    '''
    sql = textwrap.dedent(sql)
    try:
        cur.executemany(sql, values)
    except Exception as e:
        if len(values) > 5:
            print_err(f'Failed to execute query:\n{sql}\n{values[:5]}\n...\n{e}')
        else:
            print_err(f'Failed to execute query:\n{sql}\n{values}\n{e}')
        return False
    return True

def callproc(conn, name, args):
    '''Call a procedure.

    Args:
        conn (connection): database connection object.
        name (str): procedure name.
        args (list): procedure arguments.

    Returns:
        cursor: conn.cursor on success. None otherwise.

    '''
    if not is_valid_identifier(name):
        print_err(f'Invalid name: {name}')
        return None

    # Convert 'NULL' to None
    args = list(args)
    for arg_idx, arg in enumerate(args):
        if arg == 'NULL':
            args[arg_idx] = None

    try:
        cur = conn.cursor()
        cur.callproc(name, args)
    except mariadb.Error as e:
        print_err(f'Failed to call procedure: {name} {args}\n{e}')
        return None
    return cur

def is_valid_identifier(name):
    '''Validate whether a name is a valid SQL identifier.

    Only alphanumeric and underscores are valid.

    Args:
        name (str): the name to validate

    Returns:
        bool: True if valid. False otherwise.

    '''
    return bool(re.match(r'^\w+$', name))

def insert_rows(cur, rows, table_name, replace=False):
    '''Insert some rows into some table.

    Args:
        cur (cursor): cursor for the database connection.
        rows (dict, list): singular or list of kv dict where keys are column
            names.
        table_name (str): table to insert into.
        replace (bool, optional): whether to replace existing rows
            when conflicting. Default is False.

    Returns:
        bool: True on success. False otherwise.

    '''
    if not is_valid_identifier(table_name):
        print_err(f'Invalid table_name: {table_name}')
        return False

    if not isinstance(rows, list):
        rows = [rows]

    # Use the first row as a reference for keys/columns
    row_keys = rows[0].keys()
    for key in row_keys:
        if not is_valid_identifier(key):
            print_err(f'Invalid column name: {key}')
            return False

    insert_keyword = 'REPLACE' if replace else 'INSERT'
    placeholder = _cur_placeholder(cur)

    sql = f'''
        {insert_keyword} INTO {table_name}
        ({','.join(row_keys)})
        VALUES
        ({','.join((f' {placeholder} ' for _ in row_keys))})'''
    values = []
    for row in rows:
        # Append a tuple for each row and ensure the values are in the same order.
        values.append(tuple((row[key] if row[key] else None for key in row_keys)))
    return execute_many(cur, sql, values)

def delete_rows(cur, table_name, key, values):
    '''Delete some rows from table, based on a key.

    Args:
        cur (cursor): cursor for the database connection.
        table_name (str): table to delete from.
        key (str): column to match on.
        values (list): list of key values to delete.

    Returns:
        bool: True on success. False otherwise.

    '''
    if not is_valid_identifier(table_name):
        print_err(f'Invalid table_name: {table_name}')
        return False

    if not is_valid_identifier(key):
        print_err(f'Invalid key: {key}')
        return False

    if not isinstance(values, list) and not isinstance(values, tuple):
       values = [values]

    placeholder = _cur_placeholder(cur)

    sql = f'''
        DELETE FROM {table_name}
        WHERE {key} IN ({','.join((f' {placeholder} ' for _ in values))})'''
    return execute(cur, sql, values)

def get_insertable_columns(conn, table_name):
    '''Get a list of columns that can be inserted for a table.

    Args:
        conn (connection): database connection object.
        table_name (str): table to get columns for.

    Returns:
        list: the columns that can be set on INSERT.
              None on error.

    '''
    if not is_valid_identifier(table_name):
        print_err(f'Invalid table_name: {table_name}')
        return None

    cur = conn.cursor()
    placeholder = _cur_placeholder(cur)
    sql = f'''
        SELECT column_name
          FROM information_schema.columns
          WHERE table_schema = {placeholder}
            AND table_name = {placeholder}
            AND is_generated != 'ALWAYS'
          ORDER BY ordinal_position'''
    values = (conn.database, table_name)
    if not execute(cur, sql, values):
        return None
    return [row[0] for row in cur]

def get_procedures(conn, name=None):
    '''Get database procedures and arguments.

    Args:
        conn (connection): database connection object.
        name (str, optional): filter by procedure name.

    Returns:
        dict: dictionary where each key is a procedure name, each value is a
            list of parameters, and each parameter is a dictionary of
            parameter_mode, parameter_name, data_type.
            None on failure.

    '''
    name = name or '%'
    proc_dict = {}
    cur = conn.cursor()
    placeholder = _cur_placeholder(cur)
    sql = f'''
        SELECT routine_name
          FROM information_schema.routines
          WHERE routine_type = 'PROCEDURE'
            AND routine_schema = {placeholder}
            AND routine_name like {placeholder}
          ORDER BY routine_name'''
    values = (conn.database, name)
    if not execute(cur, sql, values):
        return None

    placeholder = _cur_placeholder(cur)

    for name_row in list(cur):
        name = name_row[0]
        proc_dict[name] = []
        sql = f'''
            SELECT parameter_mode, parameter_name, data_type
              FROM information_schema.parameters
              WHERE specific_name={placeholder}
              ORDER BY ordinal_position'''
        values = (name,)
        if not execute(cur, sql, values):
            return None

        for arg_row in cur:
            proc_dict[name].append({
                'parameter_mode': arg_row[0],
                'parameter_name': arg_row[1],
                'data_type': arg_row[2]})

    return proc_dict

def cur_iter(cur):
    '''Iterator for a cursor's header row + data rows.
    Args:
        cur (cursor): cursor for the database connection that contains the rows.
    Returns:
        iter: iter for the header + data rows.
    '''
    cur_type = _cur_type(cur)
    if cur_type == 'mysql':
        stored_results = list(cur.stored_results())
        if stored_results:
            for result in stored_results:
                yield tuple((details[0] for details in result.description))
                for row in result.fetchall():
                    yield row
        else:
            yield tuple((details[0] for details in cur.description))
            for row in cur:
                yield row
    elif cur_type== 'mariadb':
        yield tuple((details[0] for details in cur.description))
        for row in cur:
            yield row
