'''
    mdtest_hard tests to compare EC to rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': None, # placeholder
    'n_file': '10000000',
    'mdtest_flags': '-C -T -r -E -t -X',
    'bytes_read': '3901',
    'bytes_write': '3901',
    'sw_time': '30',
    'ppc': 32
}

# List of oclass, chunk_size, scale
condensed_tests = [
    #[[('S2', 'SX')],            '1M',  [(3, 12, 6)]],
    #[[('S2', 'SX')],            '1M',  [(6, 24, 6)]],
    #[[('S2', 'SX')],            '1M',  [(12, 48, 6)]],

    #[[('S2', 'SX')],            '1M',  [(3, 16, 6)]],
    #[[('S2', 'SX')],            '1M',  [(6, 16, 6)]],
    #[[('S2', 'SX')],            '1M',  [(12, 16, 6)]],
    #[[('S2', 'SX')],            '1M',  [(18, 16, 6)]],
    #[[('S2', 'SX')],            '1M',  [(24, 16, 6)]],

    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(3, 12, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(6, 24, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(12, 48, 6)]],

    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(3, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(6, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(12, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(18, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2M',  [(24, 16, 6)]],

    #[[('S4', 'SX')],            '1M',  [(6, 24, 6)]],
    #[[('S4', 'SX')],            '1M',  [(12, 48, 6)]],

    #[[('S4', 'SX')],            '1M',  [(6, 16, 6)]],
    #[[('S4', 'SX')],            '1M',  [(12, 16, 6)]],
    #[[('S4', 'SX')],            '1M',  [(18, 16, 6)]],
    #[[('S4', 'SX')],            '1M',  [(24, 16, 6)]],
    #[[('S4', 'SX')],            '1M',  [(36, 16, 6)]],

    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(6, 24, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(12, 48, 6)]],

    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(6, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(12, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(18, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(24, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4M',  [(36, 16, 6)]],

    #[[('S8', 'SX')],            '1M',  [(10, 40, 6)]],

    #[[('S8', 'SX')],            '1M',  [(10, 16, 6)]],
    #[[('S8', 'SX')],            '1M',  [(20, 16, 6)]],
    #[[('S8', 'SX')],            '1M',  [(30, 16, 6)]],

    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(10, 40, 6)]],

    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(10, 16, 6)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(20, 16, 6)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8M',  [(30, 16, 6)]],

    #[[('S16', 'SX')],           '1M',  [(18, 16, 6)]],
    #[[('S16', 'SX')],           '1M',  [(36, 16, 6)]],

    [[('EC_16P2G1', 'RP_3GX')], '16M', [(18, 16, 6)]],
    [[('EC_16P2G1', 'RP_3GX')], '16M', [(36, 16, 6)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_hard',
        'oclass': _oclass,
        'ec_cell_size': '131072', # 128K
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk),
        'enabled': True
    }
    for _oclass, _chunk, _scale in condensed_tests
]
