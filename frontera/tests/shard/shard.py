'''
    Tests with varying shareds.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1M',
    'segments': '1',
    'xfer_size': None, # placeholder
    'block_size': '1G',
    'fpp': '-F',
    'sw_time': '60',
    'iterations': '2',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy_S2',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 8, 10)
        ],
        'oclass': 'S2',
        'env_vars': dict(env_vars, xfer_size='2M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy_S4',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (6, 12, 10)
        ],
        'oclass': 'S4',
        'env_vars': dict(env_vars, xfer_size='4M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy_S8',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (10, 20, 10)
        ],
        'oclass': 'S8',
        'env_vars': dict(env_vars, xfer_size='8M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy_S16',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (18, 36, 15)
        ],
        'oclass': 'S16',
        'env_vars': dict(env_vars, xfer_size='16M'),
        'enabled': False
    },
]
