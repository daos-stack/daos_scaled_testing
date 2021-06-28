import mariadb
import re
import textwrap
from os.path import isfile

from .io_utils import print_err

def connect(config_path):
    """Connect to the database.

    Args:
        config_path(str): the config for connection.

    Returns:
        connection: the database connection object.
            None on error.

    """
    if not isfile(config_path):
        print_err(f"Config not found: {config_path}")
        return None

    try:
        conn = mariadb.connect(
            default_file=config_path,
            autocommit=False)
    except mariadb.Error as e:
        print_err(f"Failed connect to MariaDB Platform: {e}")
        return None

    # Sanity check
    if not conn.user:
        print_err("Failed to connect to MariaDB Platform. Check configuration.")
        conn.close()
        return None

    return conn

def execute(cur, sql, values=None):
    """Execute a single sql statement.

    Args:
        cur (cursor): cursor for the database connection.
        sql (str): the sql statement.
        values (list, optional): list of bind values.

    Returns:
        bool: True on success. False otherwise.

    """
    sql = textwrap.dedent(sql)
    try:
        cur.execute(sql, values)
    except mariadb.Error as e:
        print_err(f"Failed to execute query:\n{sql}\n{values}\n{e}")
        return False
    return True

def execute_many(cur, sql, values=None):
    """Execte a sql statement with a list of values.
    
    Args:
        cur (cursor): cursor for the database connection.
        sql (str): the sql statement.
        values (list): list of list of sql values.

    """
    sql = textwrap.dedent(sql)
    try:
        cur.executemany(sql, values)
    except mariadb.Error as e:
        if len(values) > 5:
            print_err(f"Failed to execute query:\n{sql}\n{values[:5]}\n...\n{e}")
        else:
            print_err(f"Failed to execute query:\n{sql}\n{values}\n{e}")
        return False
    return True

def callproc(conn, name, args):
    """Call a procedure.

    Args:
        conn (connection): database connection object.
        name (str): procedure name.
        args (list): procedure arguments.

    Returns:
        cursor: conn.cursor on success. None otherwise.

    """
    if not is_valid_identifier(name):
        print_err(f"Invalid name: {name}")
        return None

    # Convert "NULL" to None
    args = list(args)
    for arg_idx, arg in enumerate(args):
        if arg == "NULL":
            args[arg_idx] = None

    try:
        cur = conn.cursor()
        cur.callproc(name, args)
    except mariadb.Error as e:
        print_err(f"Failed to call procedure: {name} {args}\n{e}")
        return None
    return cur

def is_valid_identifier(name):
    """Validate whether a name is a valid SQL identifier.

    Only alphanumeric and underscores are valid.

    Args:
        name (str): the name to validate

    Returns:
        bool: True if valid. False otherwise.

    """
    return bool(re.match(r'^\w+$', name))

def insert_rows(cur, rows, table_name, replace=False):
    """Insert some rows into some table.

    Args:
        cur (cursor): cursor for the database connection.
        rows (dict, list): singular or list of kv dict where keys are column
            names.
        table_name (str): table to insert into.
        replace (bool, optional): whether to replace existing rows
            when conflicting. Default is False.

    Returns:
        bool: True on success. False otherwise.

    """
    if not is_valid_identifier(table_name):
        print_err(f"Invalid table_name: {table_name}")
        return False

    if not isinstance(rows, list):
        rows = [rows]

    # Use the first row as a reference for keys/columns
    row_keys = rows[0].keys()
    for key in row_keys:
        if not is_valid_identifier(key):
            print_err(f"Invalid column name: {key}")
            return False

    insert_keyword = "REPLACE" if replace else "INSERT"

    sql = f"""
        {insert_keyword} INTO {table_name}
        ({','.join(row_keys)})
        VALUES
        ({','.join((' ? ' for key in row_keys))})"""
    values = []
    for row in rows:
        # Append a tuple for each row and ensure the values are in the
        # same order.
        values.append(
            tuple((row[key] if row[key] else None for key in row_keys)))
    if not execute_many(cur, sql, values):
        return False
    return True

def get_insertable_columns(conn, table_name):
    """Get a list of columns that can be inserted for a table.

    Args:
        conn (connection): database connection object.
        table_name (str): table to get columns for.

    Returns:
        list: the columns that can be set on INSERT.
              None on error.

    """
    if not is_valid_identifier(table_name):
        print_err(f"Invalid table_name: {table_name}")
        return None

    cur = conn.cursor()
    sql = """
        SELECT column_name
          FROM information_schema.columns
          WHERE table_schema = ?
            AND table_name = ?
            AND is_generated != "ALWAYS"
          ORDER BY ordinal_position"""
    values = (conn.database, table_name)
    if not execute(cur, sql, values):
        return None
    return [row[0] for row in cur]

def get_procedures(conn, name=None):
    """Get database procedures and arguments.

    Args:
        conn (connection): database connection object.
        name (str, optional): filter by procedure name.

    Returns:
        dict: dictionary where each key is a procedure name, each value is a
            list of parameters, and each parameter is a dictionary of
            parameter_mode, parameter_name, data_type.
            None on failure.

    """
    if not name:
        name = "%"
    proc_dict = {}
    cur = conn.cursor()
    sql = """
        SELECT routine_name
          FROM information_schema.routines
          WHERE routine_type = 'PROCEDURE'
            AND routine_schema = ?
            AND routine_name like ?
          ORDER BY routine_name"""
    values = (conn.database, name)
    if not execute(cur, sql, values):
        return None

    for name_row in list(cur):
        name = name_row[0]
        proc_dict[name] = []
        sql = """
            SELECT parameter_mode, parameter_name, data_type
              FROM information_schema.parameters
              WHERE specific_name=?
              ORDER BY ordinal_position"""
        values = (name,)
        if not execute(cur, sql, values):
            return None

        for arg_row in cur:
            proc_dict[name].append({
                "parameter_mode": arg_row[0],
                "parameter_name": arg_row[1],
                "data_type": arg_row[2]})

    return proc_dict

def cur_iter(cur):
    """Iterator for a cursor's header row + data rows.

    Args:
        cur (cursor): cursor for the database connection that contains the
            rows.

    Returns:
        generator: generator for the header + data rows.

    """
    yield tuple((details[0] for details in cur.description))
    for row in cur:
        yield row
