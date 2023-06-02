'''
    ior_easy tests to compare EC to rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': None, # placeholder
    'segments': '1',
    'xfer_size': None, # placeholder
    'block_size': '150G',
    'sw_time': '60',
    'iterations': '1',
    'ppc': 32
}

# List of oclass, chunk_size, xfer_size, scale
condensed_tests = [
    ['SX',        '1MiB',  '2MiB',  [(3, 12, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(6, 24, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(12, 48, 6)]],

    ['SX',        '1MiB',  '2MiB',  [(3, 16, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(6, 16, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(12, 16, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(18, 16, 6)]],
    ['SX',        '1MiB',  '2MiB',  [(24, 16, 6)]],

    ['EC_2P1GX',  '2MiB',  '2MiB',  [(3, 12, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(6, 24, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(12, 48, 6)]],

    ['EC_2P1GX',  '2MiB',  '2MiB',  [(3, 16, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(6, 16, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(12, 16, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(18, 16, 6)]],
    ['EC_2P1GX',  '2MiB',  '2MiB',  [(24, 16, 6)]],

    ['SX',        '1MiB',  '4MiB',  [(6, 24, 6)]],
    ['SX',        '1MiB',  '4MiB',  [(12, 48, 6)]],

    ['SX',        '1MiB',  '4MiB',  [(6, 16, 6)]],
    ['SX',        '1MiB',  '4MiB',  [(12, 16, 6)]],
    ['SX',        '1MiB',  '4MiB',  [(18, 16, 6)]],
    ['SX',        '1MiB',  '4MiB',  [(24, 16, 6)]],
    ['SX',        '1MiB',  '4MiB',  [(36, 16, 6)]],

    ['EC_4P2GX',  '4MiB',  '4MiB',  [(6, 24, 6)]],
    ['EC_4P2GX',  '4MiB',  '4MiB',  [(12, 48, 6)]],

    ['EC_4P2GX',  '4MiB',  '4MiB',  [(6, 16, 6)]],
    ['EC_4P2GX',  '4MiB',  '4MiB',  [(12, 16, 6)]],
    ['EC_4P2GX',  '4MiB',  '4MiB',  [(18, 16, 6)]],
    ['EC_4P2GX',  '4MiB',  '4MiB',  [(24, 16, 6)]],
    ['EC_4P2GX',  '4MiB',  '4MiB',  [(36, 16, 6)]],

    ['SX',        '1MiB',  '8MiB',  [(10, 40, 6)]],

    ['SX',        '1MiB',  '8MiB',  [(10, 16, 6)]],
    ['SX',        '1MiB',  '8MiB',  [(20, 16, 6)]],
    ['SX',        '1MiB',  '8MiB',  [(30, 16, 6)]],

    ['EC_8P2GX',  '8MiB',  '8MiB',  [(10, 40, 6)]],

    ['EC_8P2GX',  '8MiB',  '8MiB',  [(10, 16, 6)]],
    ['EC_8P2GX',  '8MiB',  '8MiB',  [(20, 16, 6)]],
    ['EC_8P2GX',  '8MiB',  '8MiB',  [(30, 16, 6)]],

    ['SX',        '1MiB',  '16MiB', [(18, 16, 6)]],
    ['SX',        '1MiB',  '16MiB', [(36, 16, 6)]],

    ['EC_16P2GX', '16MiB', '16MiB', [(18, 16, 6)]],
    ['EC_16P2GX', '16MiB', '16MiB', [(36, 16, 6)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': _oclass,
        'ec_cell_size': '131072', # 128KiB
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk, xfer_size=_xfer),
        'enabled': True
    }
    for _oclass, _chunk, _xfer, _scale in condensed_tests
]
