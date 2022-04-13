'''
    ior_hard tests to compare EC to rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': None, # placeholder
    'segments': '2000000',
    'xfer_size': '47008',
    'block_size': '47008',
    'sw_time': '60',
    'iterations': '1',
    'ppc': 32
}

# List of oclass, chunk_size, scale
condensed_tests = [
    ['SX',        '470080',  [(3, 12, 6)]],
    ['SX',        '470080',  [(6, 24, 6)]],
    ['SX',        '470080',  [(12, 48, 6)]],

    ['SX',        '470080',  [(3, 16, 6)]],
    ['SX',        '470080',  [(6, 16, 6)]],
    ['SX',        '470080',  [(12, 16, 6)]],
    ['SX',        '470080',  [(18, 16, 6)]],
    ['SX',        '470080',  [(24, 16, 6)]],

    ['EC_2P1GX',  '470080',  [(3, 12, 6)]],
    ['EC_2P1GX',  '470080',  [(6, 24, 6)]],
    ['EC_2P1GX',  '470080',  [(12, 48, 6)]],

    ['EC_2P1GX',  '470080',  [(3, 16, 6)]],
    ['EC_2P1GX',  '470080',  [(6, 16, 6)]],
    ['EC_2P1GX',  '470080',  [(12, 16, 6)]],
    ['EC_2P1GX',  '470080',  [(18, 16, 6)]],
    ['EC_2P1GX',  '470080',  [(24, 16, 6)]],

    ['SX',        '470080',  [(6, 24, 6)]],
    ['SX',        '470080',  [(12, 48, 6)]],

    ['SX',        '470080',  [(6, 16, 6)]],
    ['SX',        '470080',  [(12, 16, 6)]],
    ['SX',        '470080',  [(18, 16, 6)]],
    ['SX',        '470080',  [(24, 16, 6)]],
    ['SX',        '470080',  [(36, 16, 6)]],

    ['EC_4P2GX',  '564096',  [(6, 24, 6)]],
    ['EC_4P2GX',  '564096',  [(12, 48, 6)]],

    ['EC_4P2GX',  '564096',  [(6, 16, 6)]],
    ['EC_4P2GX',  '564096',  [(12, 16, 6)]],
    ['EC_4P2GX',  '564096',  [(18, 16, 6)]],
    ['EC_4P2GX',  '564096',  [(24, 16, 6)]],
    ['EC_4P2GX',  '564096',  [(36, 16, 6)]],

    ['SX',        '470080',  [(10, 40, 6)]],

    ['SX',        '470080',  [(10, 16, 6)]],
    ['SX',        '470080',  [(20, 16, 6)]],
    ['SX',        '470080',  [(30, 16, 6)]],

    ['EC_8P2GX',  '1081184',  [(10, 40, 6)]],

    ['EC_8P2GX',  '1081184',  [(10, 16, 6)]],
    ['EC_8P2GX',  '1081184',  [(20, 16, 6)]],
    ['EC_8P2GX',  '1081184',  [(30, 16, 6)]],

    ['SX',        '470080',  [(18, 16, 6)]],
    ['SX',        '470080',  [(36, 16, 6)]],

    ['EC_16P2GX', '2115360', [(18, 16, 6)]],
    ['EC_16P2GX', '2115360', [(36, 16, 6)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_hard',
        'oclass': _oclass,
        'ec_cell_size': '131072', # 128K
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk),
        'enabled': True
    }
    for _oclass, _chunk, _scale in condensed_tests
]
