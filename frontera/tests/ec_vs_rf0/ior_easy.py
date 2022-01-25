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
    ['S32',      '1M',   '2M', [(3, 12, 10)]],
    ['S32',      '1M',   '2M', [(3, 16, 10)]],
    ['S64',      '1M',   '2M', [(6, 12, 10)]],
    ['S64',      '1M',   '2M', [(6, 16, 10)]],
    ['S128',     '1M',   '2M', [(12, 16, 10)]],
    ['S192',     '1M',   '2M', [(18, 16, 10)]],
    ['S256',     '1M',   '2M', [(24, 16, 10)]],

    ['EC_2P1GX', '2M',   '2M', [(3, 12, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(3, 16, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(6, 12, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(6, 16, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(12, 16, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(18, 16, 10)]],
    ['EC_2P1GX', '2M',   '2M', [(24, 16, 10)]],

    ['S64',      '1M',   '4M', [(6, 12, 10)]],
    ['S64',      '1M',   '4M', [(6, 16, 10)]],
    ['S128',     '1M',   '4M', [(12, 16, 10)]],
    ['S192',     '1M',   '4M', [(18, 16, 10)]],
    ['S256',     '1M',   '4M', [(24, 16, 10)]],
    ['S384',     '1M',   '4M', [(36, 16, 10)]],

    ['EC_4P2GX', '4M',   '4M', [(6, 12, 10)]],
    ['EC_4P2GX', '4M',   '4M', [(6, 16, 10)]],
    ['EC_4P2GX', '4M',   '4M', [(12, 16, 10)]],
    ['EC_4P2GX', '4M',   '4M', [(18, 16, 10)]],
    ['EC_4P2GX', '4M',   '4M', [(24, 16, 10)]],
    ['EC_4P2GX', '4M',   '4M', [(36, 16, 10)]],

    ['S128',     '1M',   '8M', [(10, 16, 10)]],
    ['S256',     '1M',   '8M', [(20, 16, 10)]],
    ['S384',     '1M',   '8M', [(30, 16, 10)]],

    ['EC_8P2GX', '8M',   '8M', [(10, 16, 10)]],
    ['EC_8P2GX', '8M',   '8M', [(20, 16, 10)]],
    ['EC_8P2GX', '8M',   '8M', [(30, 16, 10)]],

    ['S256',     '1M',   '16M', [(18, 16, 10)]],
    ['S512',     '1M',   '16M', [(36, 16, 10)]],

    ['EC_16P2GX', '16M', '16M', [(18, 16, 10)]],
    ['EC_16P2GX', '16M', '16M', [(36, 16, 10)]],
]

# List of tests, generated from condensed_tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': _oclass,
        'ec_cell_size': '1048576',
        'scale': _scale,
        'env_vars': dict(env_vars, chunk_size=_chunk, xfer_size=_xfer),
        'enabled': True
    }
    for _oclass, _chunk, _xfer, _scale in condensed_tests
]
