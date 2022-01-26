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
    ['SX',        '1M',  [(3, 16, 10)]],
    ['SX',        '1M',  [(6, 16, 10)]],
    ['SX',        '1M',  [(12, 16, 10)]],
    ['SX',        '1M',  [(18, 16, 10)]],
    ['SX',        '1M',  [(24, 16, 10)]],
    ['SX',        '1M',  [(36, 16, 10)]],

    ['SX',        '1M',  [(10, 16, 10)]],
    ['SX',        '1M',  [(20, 16, 10)]],
    ['SX',        '1M',  [(30, 16, 10)]],

    ['EC_2P1GX',  '2M',  [(3, 16, 10)]],
    ['EC_2P1GX',  '2M',  [(6, 16, 10)]],
    ['EC_2P1GX',  '2M',  [(12, 16, 10)]],
    ['EC_2P1GX',  '2M',  [(18, 16, 10)]],
    ['EC_2P1GX',  '2M',  [(24, 16, 10)]],

    ['EC_4P2GX',  '4M',  [(6, 16, 10)]],
    ['EC_4P2GX',  '4M',  [(12, 16, 10)]],
    ['EC_4P2GX',  '4M',  [(18, 16, 10)]],
    ['EC_4P2GX',  '4M',  [(24, 16, 10)]],
    ['EC_4P2GX',  '4M',  [(36, 16, 10)]],

    ['EC_8P2GX',  '8M',  [(10, 16, 10)]],
    ['EC_8P2GX',  '8M',  [(20, 16, 10)]],
    ['EC_8P2GX',  '8M',  [(30, 16, 10)]],

    ['EC_16P2GX', '16M', [(18, 16, 10)]],
    ['EC_16P2GX', '16M', [(36, 16, 10)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_hard',
        'oclass': _oclass,
        'ec_cell_size': '1048576',
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk),
        'enabled': True
    }
    for _oclass, _chunk, _scale in condensed_tests
]
