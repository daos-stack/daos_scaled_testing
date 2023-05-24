'''
    Max configuration.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1MiB',
    'segments': '1',
    'xfer_size': '1MiB',
    'block_size': '150G',
    'sw_time': '60',
    'iterations': '1',
    'ppc': 8
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': 'SX',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (128, 256, 10),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
