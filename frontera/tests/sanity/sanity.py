'''
    Sanity tests.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1M',
    'segments': '1',
    'xfer_size': '1M',
    'block_size': '150G',
    'n_file': '1000000',
    'bytes_read': '0',
    'bytes_write': '0',
    'tree_depth': '0',
    'sw_time': '5',
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_sanity',
        'oclass': 'SX',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (1, 1, 1),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_sanity',
        'oclass': [('S1', 'SX')],
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (1, 1, 1),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
