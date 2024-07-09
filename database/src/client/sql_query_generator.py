import re

try:
    from ClusterShell.NodeSet import NodeSet
except:
    NodeSet = None

class SQLQuery():
    VALID_AGGREGATES = ['MAX', 'MIN', 'SUM', 'JSON_ARRAYAGG', 'GROUP_CONCAT']

    def __init__(
        self, select=None, table=None, where=None, groupby=None, orderby=None, limit=None,
        bind_pattern='?'):
        '''Initialize SQLQuery.
        
        Args:
            select (list, optional): list of columns to select.
                Optionally, each element as a list of column, alias, aggregate
            table (str, optional): table to select from
            where (list, optional): list with each element being a list containing the column, value,
                and optionally match type. Match types are:
                    = Default. Match using LIKE.
            groupby (list, optional): list of columns to group by.
            orderby (list, optional): list of cols to order by.
                Optionally, each element is a list of column, direction.
                E.g.: ["col1", "col2"]
                E.g.: [["col1, "ASC"], ["col2", "DESC"]]
            limit (int, optional): limit of rows
            bind_pattern (str, optional): Pattern for binding dynamic values.
                Default is ?

        '''
        self._select = []
        self._table = []
        self._where = []
        self._groupby = []
        self._orderby = []
        self._limit = []
        self.bind_pattern = bind_pattern

        self.select(select, table)
        self.where(where)
        self.groupby(groupby)
        self.orderby(orderby)
        self.limit(limit)

    def select(self, select, table):
        '''Set the SELECT clause.

        Args:
            select (list): see __init__
            table (str): see __init__

        Raises:
            ValueError: on invalid column or table names

        '''
        if not table:
            self._table = []
        elif not self.is_valid_identifier(table):
            raise ValueError(f'Invalid table name {table}')
        else:
            self._table = table

        if not select:
            self._select = []
            return

        if select == '*' or '*' in [s[0] for s in select]:
            self._select = '*'
            return

        self._select = []
        for col in select:
            if isinstance(col, (list, tuple)):
                col = list(col)
            else:
                col = [col]
            if not self.is_valid_identifier(col[0]):
                raise ValueError(f'Invalid column name {col[0]}')
            if len(col) > 1:
                if not col[1]:
                    # Set alias to column name to simplify parsing later
                    col[1] = col[0]
                elif not self.is_valid_identifier(col[1]):
                    raise ValueError(f'Invalid column alias {col[1]}')
                # Quote alias
                col[1] = f'"{col[1]}"'
            if len(col) > 2:
                col[2] = col[2].upper()
                if not self.is_valid_aggregate(col[2]):
                    raise ValueError(f'Invalid aggregate {col[2]}')
            self._select.append(col)

    def _select_to_sql(self):
        '''Convert select list to SQL.

        Returns:
            str: SQL for SELECT clause

        '''
        select_list = []
        if self._groupby:
            # Always SELECT COUNT(*) too
            select_list.append('COUNT(*) AS Count')
        for col in self._select:
            if len(col) > 2:
                # Aggregate on column
                select_list.append(f'{col[2]}({col[0]}) AS {col[1]}')
            else:
                select_list.append(' AS '.join(col[:2]))
        return f'SELECT {",".join(select_list)} FROM {self._table}'

    def where(self, where):
        '''Set the WHERE clause.
        
        Args:
            where (list): see __init__

        Raises:
            ValueError: on invalid where values

        '''
        if not where:
            self._where = []
            return
        self._where = where.copy()
        for w in self._where:
            if len(w) < 2:
                raise ValueError('Each element should contain the column and value')
            if len(w) < 3:
                w.append('=')
            elif w[2] not in ('=',):
                raise ValueError(f'Unsupported match type {w[2]}')
            if not self.is_valid_identifier(w[0]):
                raise ValueError(f'Invalid column name {w[0]}')

    @staticmethod
    def _where_to_sql(where, bind_pattern, first_where=True):
        '''Convert where list to SQL.
        
        Returns:
            (str, list): SQL for WHERE clause, bind values

        '''
        sql = ''
        values = []

        if not where:
            return sql, values

        first_where_str = 'WHERE' if first_where else 'AND'

        sql += ' '

        for where_col, where_val, _ in where:
            # TODO handle where_type
            # TODO support OR for columns other other "node"
            sql += f'{first_where_str if len(values) == 0 else " AND"} ('
            for idx, _val in enumerate(SQLQuery.split_key(where_val) if where_col == 'node' else [where_val]):
                sql += f'{"" if idx == 0 else " OR "}{where_col} LIKE {bind_pattern}'
                values.append(_val)
            sql += ')'
        return sql, values

    @staticmethod
    def kv_to_where(kv):
        '''Convert one or more KV strings to a where list.

        Args:
            kv (list/str): one or more where strings to convert.

        Returns:
            list: properly formatted list to be passed to where().

        Raises:
            ValueError: on invalid where values

        '''
        out = []
        if not isinstance(kv, (list,tuple)):
            kv = [kv]
        for _kv in kv:
            valid = False
            for match_type in ['=']:
                try:
                    out.append(list(re.search(f'^([0-9a-zA-Z_.]+)({match_type})(.*)$', _kv, re.MULTILINE).group(1,3,2)))
                    valid = True
                    break
                except AttributeError:
                    continue
            if not valid:
                raise ValueError(f'Invalid KV string: {_kv}')
        return out

    def groupby(self, groupby):
        '''Set the GROUP BY clause.
        
        Args:
            groupby (list): see __init__

        Raises:
            ValueError: on invalid column names

        '''
        if not groupby:
            self._groupby = []
            return
        if isinstance(groupby, (list, tuple)):
            self._groupby = groupby.copy()
        else:
            self._groupby = [groupby]

        for col in self._groupby:
            if not self.is_valid_identifier(col):
                raise ValueError(f'Invalid column name {col}')

        select_cols = [s[0] for s in self._select] if self._select else ['*']
        if '*' in select_cols:
            # Set SELECT to match GROUP BY columns
            self._select = [[g] for g in self._groupby]
        else:
            # Verify SELECT and GROUP BY are compatible
            cols_not_in_groupby = list(set([s[0] for s in self._select if len(s) < 3]) - set(self._groupby))
            if cols_not_in_groupby:
                raise ValueError(f'Columns in SELECT should be in GROUP BY {cols_not_in_groupby}')


    def orderby(self, orderby):
        '''Set the ORDER BY clause.
        
        Args:
            orderby (list): see __init__

        Raises:
            ValueError: on invalid orderby column name or alias

        '''
        if not orderby:
            self._orderby = []
            return
        if isinstance(orderby, (list, tuple)):
            self._orderby = orderby.copy()
        else:
            self._orderby = [orderby]

        for idx, o in enumerate(self._orderby):
            if not isinstance(o, (list, tuple)):
                o = [o]
            if not self.is_valid_identifier(o[0]):
                raise ValueError(f'Invalid orderby column name {col}')
            elif len(o) > 1:
                o[1] = o[1].upper()
                if o[1] not in ('ASC', 'DESC'):
                    raise ValueError(f'Invalid orderby direction. Expected "ASC" or "DESC": {o[1]}')
            self._orderby[idx] = o

    def limit(self, limit):
        '''Set the LIMIT clause.
        
        Args:
            limit (int): see __init__

        Raises:
            ValueError: on invalid limit value

        '''
        if not limit:
            self._limit = []
            return
        try:
            self._limit = int(limit)
        except Exception as e:
            raise ValueError(f'Invalid limit {limit}') from e

    def generate(self):
        '''Generate the query.
        
        Returns:
            (str, list): the generated query and list of bind values

        Raises:
            Exception: on error

        '''
        if not self._select:
            raise Exception('select is required')
        if not self._table:
            raise Exception('table is required')

        sql = ''
        values = []

        # SELECT
        sql = self._select_to_sql()

        # WHERE
        _sql, _values = self._where_to_sql(self._where, self.bind_pattern)
        sql += _sql
        values += _values

        # GROUP BY
        if self._groupby:
            sql += f' GROUP BY {",".join(self._groupby)}'

        # ORDER BY
        if self._orderby:
            sql += f' ORDER BY {",".join([" ".join(o) for o in self._orderby])}'

        # LIMIT
        if self._limit:
            sql += f' LIMIT {self.bind_pattern}'
            values.append(self._limit)

        return (sql, values)

    @staticmethod
    def is_valid_identifier(name):
        '''Validate whether a name is a valid SQL identifier.

        Only alphanumeric and underscores are valid.

        Args:
            name (str): the name to validate

        Returns:
            bool: True if valid. False otherwise

        '''
        return bool(re.match(r'^\w+$', name))

    @staticmethod
    def is_valid_aggregate(name):
        '''Validate whether a name is in VALID_AGGREGATES.

        Args:
            name (str): the name to validate

        Returns:
            bool: True if valid. False otherwise

        '''
        return name in SQLQuery.VALID_AGGREGATES

    @staticmethod
    def split_key(key):
        '''Split a key and try to parse a NodeSet.

        TODO cleaner implementation
        
        Args:
            key (str): the key to split.
            
        Returns:
            list: list of split values.

        '''
        if NodeSet is not None:
            return list(NodeSet(key))
        return key.split(',')
