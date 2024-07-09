'''
    mdtest_easy tests to compare EC to rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': None, # placeholder
    'n_file': '10000000',
    'mdtest_flags': '-C -T -r -u -L',
    'bytes_read': '0',
    'bytes_write': '0',
    'sw_time': '30',
    'ppc': 32
}

# List of oclass, chunk_size, scale
condensed_tests = [
    #[[('S2', 'SX')],            '1MiB',  [(3, 12, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(6, 24, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(12, 48, 6)]],

    #[[('S2', 'SX')],            '1MiB',  [(3, 16, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(6, 16, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(12, 16, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(18, 16, 6)]],
    #[[('S2', 'SX')],            '1MiB',  [(24, 16, 6)]],

    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(3, 12, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(6, 24, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(12, 48, 6)]],

    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(3, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(6, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(12, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(18, 16, 6)]],
    [[('EC_2P1G1', 'RP_2GX')],  '2MiB',  [(24, 16, 6)]],

    #[[('S4', 'SX')],            '1MiB',  [(6, 24, 6)]],
    #[[('S4', 'SX')],            '1MiB',  [(12, 48, 6)]],

    #[[('S4', 'SX')],            '1MiB',  [(6, 16, 6)]],
    #[[('S4', 'SX')],            '1MiB',  [(12, 16, 6)]],
    #[[('S4', 'SX')],            '1MiB',  [(18, 16, 6)]],
    #[[('S4', 'SX')],            '1MiB',  [(24, 16, 6)]],
    #[[('S4', 'SX')],            '1MiB',  [(36, 16, 6)]],

    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(6, 24, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(12, 48, 6)]],

    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(6, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(12, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(18, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(24, 16, 6)]],
    [[('EC_4P2G1', 'RP_3GX')],  '4MiB',  [(36, 16, 6)]],

    #[[('S8', 'SX')],            '1MiB',  [(10, 40, 6)]],

    #[[('S8', 'SX')],            '1MiB',  [(10, 16, 6)]],
    #[[('S8', 'SX')],            '1MiB',  [(20, 16, 6)]],
    #[[('S8', 'SX')],            '1MiB',  [(30, 16, 6)]],

    [[('EC_8P2G1', 'RP_3GX')],  '8MiB',  [(10, 40, 6)]],

    [[('EC_8P2G1', 'RP_3GX')],  '8MiB',  [(10, 16, 6)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8MiB',  [(20, 16, 6)]],
    [[('EC_8P2G1', 'RP_3GX')],  '8MiB',  [(30, 16, 6)]],

    #[[('S16', 'SX')],           '1MiB',  [(18, 16, 6)]],
    #[[('S16', 'SX')],           '1MiB',  [(36, 16, 6)]],

    [[('EC_16P2G1', 'RP_3GX')], '16MiB', [(18, 16, 6)]],
    [[('EC_16P2G1', 'RP_3GX')], '16MiB', [(36, 16, 6)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_easy',
        'oclass': _oclass,
        'ec_cell_size': '131072', # 128KiB
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk),
        'enabled': True
    }
    for _oclass, _chunk, _scale in condensed_tests
]
