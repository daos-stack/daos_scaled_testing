'''
    mdtest_hard tests to compare EC to rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': None, # placeholder
    'ec_cell_size': '1048576',
    'n_file': '1000000',
    'bytes_read': '3901',
    'bytes_write': '3901',
    'tree_depth': '0/20',
    'sw_time': '60', # TODO adjust?
    'ppc': 32
}

# List of oclass, chunk_size, scale
condensed_tests = [
    [[('S2', 'SX')],            '1M',  [(3, 12, 10)]],
    [[('S2', 'SX')],            '1M',  [(3, 16, 10)]],
    [[('S2', 'SX')],            '1M',  [(6, 12, 10)]],
    [[('S2', 'SX')],            '1M',  [(6, 16, 10)]],
    [[('S2', 'SX')],            '1M',  [(12, 16, 10)]],
    [[('S2', 'SX')],            '1M',  [(18, 16, 10)]],
    [[('S2', 'SX')],            '1M',  [(24, 16, 10)]],

    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(3, 12, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(3, 16, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(6, 12, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(6, 16, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(12, 16, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(18, 16, 10)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(24, 16, 10)]],

    [[('S4', 'SX')],            '1M',  [(6, 12, 10)]],
    [[('S4', 'SX')],            '1M',  [(6, 16, 10)]],
    [[('S4', 'SX')],            '1M',  [(12, 16, 10)]],
    [[('S4', 'SX')],            '1M',  [(18, 16, 10)]],
    [[('S4', 'SX')],            '1M',  [(24, 16, 10)]],
    [[('S4', 'SX')],            '1M',  [(36, 16, 10)]],

    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(6, 12, 10)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(6, 16, 10)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(12, 16, 10)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(18, 16, 10)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(24, 16, 10)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(36, 16, 10)]],

    [[('S8', 'SX')],            '1M',  [(10, 16, 10)]],
    [[('S8', 'SX')],            '1M',  [(20, 16, 10)]],
    [[('S8', 'SX')],            '1M',  [(30, 16, 10)]],

    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(10, 16, 10)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(20, 16, 10)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(30, 16, 10)]],

    [[('S16', 'SX')],           '1M',  [(18, 16, 10)]],
    [[('S16', 'SX')],           '1M',  [(36, 16, 10)]],

    [[('EC_16P2G1', 'RP_3GX')], '16M', [(18, 16, 10)]],
    [[('EC_16P2G1', 'RP_3GX')], '16M', [(36, 16, 10)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_hard',
        'oclass': _oclass,
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk),
        'enabled': True
    }
    for _oclass, _chunk, _scale in condensed_tests
]
