'''
    IOR sanity tests.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1M',
    'segments': '1',
    'xfer_size': '1M',
    'block_size': '150G',
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
            # (num_servers, num_clients, timeout_minutes)
            (1, 1, 1),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
