from .sql_query_generator import SQLQuery

def _percent_diff(str1, str2):
    return f'ROUND(({str2} - {str1}) / {str1} * 100, 2)'

def report_compare_ior(where, bind_pattern, subtype=None, sort_type='default'):
    '''TODO'''
    values = []
    sql = f'''
        SELECT  ior1.slurm_job_id        AS "slurm_job_id1",
                ior2.slurm_job_id        AS "slurm_job_id2",
                ior1.daos_commit         AS "DAOS Commit1",
                ior2.daos_commit         AS "DAOS Commit2",
                ior1.oclass              AS "oclass1",
                ior2.oclass              AS "oclass2",
                ior1.num_servers         AS "#Servers",
                ior1.num_clients         AS "#Clients",
                round(ior1.write_gib, 2) AS "write_gib1",
                round(ior2.write_gib, 2) AS "write_gib2",
                round(ior1.read_gib, 2)  AS "read_gib1",
                round(ior2.read_gib, 2)  AS "read_gib2",
                {_percent_diff('ior1.write_gib', 'ior2.write_gib')} AS "write_gib%",
                {_percent_diff('ior1.read_gib', 'ior2.read_gib')} AS "read_gib%"
        FROM results_ior ior1 JOIN results_ior ior2
        USING (num_servers, num_clients, oclass)
        WHERE ior1.id != ior2.id
    '''
    # TODO orderby
    if subtype == '1to4':
        sql += ' AND ior1.num_clients = (ior1.num_servers * 4)'
    elif subtype == 'c16':
        sql += ' AND ior1.num_clients = 16'
    elif subtype is not None:
        raise ValueError(f'Invalid subtype: {subtype}')
    _sql, _values = SQLQuery._where_to_sql(where, bind_pattern, False)
    sql += _sql
    values += _values
    if sort_type == 'default':
        sql += ' ORDER BY ior1.daos_commit, ior2.daos_commit, oclass_sort(ior1.oclass), oclass_sort(ior2.oclass), ior1.num_servers, ior1.num_clients'
    elif sort_type == 'mixed':
        sql += ' ORDER BY ior1.daos_commit, ior2.daos_commit, oclass_sort(ior1.oclass), oclass_sort(ior2.oclass), server_client_sort(ior1.num_servers, ior1.num_clients)'
    return sql, values

def report_compare_ior_1to4(where, bind_pattern):
    return report_compare_ior(where, bind_pattern, '1to4')

def report_compare_ior_c16(where, bind_pattern):
    return report_compare_ior(where, bind_pattern, 'c16')

def report_compare_ior_ec(where, bind_pattern):
    return report_compare_ior(where, bind_pattern, sort_type='mixed')


def report_compare_mdtest(where, bind_pattern, subtype=None, include_read=True, sort_type='default'):
    '''TODO'''
    values = []
    sql = f'''
        SELECT  mdtest1.slurm_job_id          AS "slurm_job_id1",
                mdtest2.slurm_job_id          AS "slurm_job_id2",
                mdtest1.daos_commit           AS "DAOS Commit1",
                mdtest2.daos_commit           AS "DAOS Commit2",
                mdtest1.oclass                AS "oclass1",
                mdtest2.oclass                AS "oclass2",
                mdtest1.num_servers           AS "#Servers",
                mdtest1.num_clients           AS "#Clients",
                round(mdtest1.create_kops, 2) AS "create_kops1",
                round(mdtest2.create_kops, 2) AS "create_kops2",
                round(mdtest1.stat_kops, 2)   AS "stat_kops1",
                round(mdtest2.stat_kops, 2)   AS "stat_kops2",
                {'round(mdtest1.read_kops, 2)   AS "read_kops1",' if include_read else ''}
                {'round(mdtest2.read_kops, 2)   AS "read_kops2",' if include_read else ''}
                round(mdtest1.remove_kops, 2) AS "remove_kops1",
                round(mdtest2.remove_kops, 2) AS "remove_kops2",
                {_percent_diff('mdtest1.create_kops', 'mdtest2.create_kops')} AS "create%",
                {_percent_diff('mdtest1.stat_kops', 'mdtest2.stat_kops')} AS "stat%",
                {_percent_diff('mdtest1.read_kops', 'mdtest2.read_kops') + ' AS "read%",' if include_read else ''}
                {_percent_diff('mdtest1.remove_kops', 'mdtest2.remove_kops')} AS "remove%"
            FROM results_mdtest mdtest1 JOIN results_mdtest mdtest2
            USING (num_servers, num_clients, oclass)
            WHERE mdtest1.id != mdtest2.id
    '''
    if subtype == '1to4':
        sql += ' AND mdtest1.num_clients = (mdtest1.num_servers * 4)'
    elif subtype == 'c16':
        sql += ' AND mdtest1.num_clients = 16'
    elif subtype is not None:
        raise ValueError(f'Invalid subtype: {subtype}')
    _sql, _values = SQLQuery._where_to_sql(where, bind_pattern, False)
    sql += _sql
    values += _values
    if sort_type == 'default':
        sql += ' ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, oclass_sort(mdtest1.oclass), oclass_sort(mdtest2.oclass), mdtest1.num_servers, mdtest1.num_clients'
    elif sort_type == 'mixed':
        sql += ' ORDER BY mdtest1.daos_commit, mdtest2.daos_commit, oclass_sort(mdtest1.oclass), oclass_sort(mdtest2.oclass), server_client_sort(mdtest1.num_servers, mdtest1.num_clients)'
    return sql, values

def report_compare_mdtest_1to4(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='1to4')

def report_compare_mdtest_easy(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, include_read=False)

def report_compare_mdtest_easy_1to4(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='1to4', include_read=False)

def report_compare_mdtest_easy_ec(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, include_read=False, sort_type='mixed')

def report_compare_mdtest_hard_1to4(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='1to4')

def report_compare_mdtest_hard(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern)

def report_compare_mdtest_hard_ec(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, sort_type='mixed')

def report_compare_mdtest_c16(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='c16')

def report_compare_mdtest_easy_c16(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='c16', include_read=False)

def report_compare_mdtest_hard_c16(where, bind_pattern):
    return report_compare_mdtest(where, bind_pattern, subtype='c16')
