'''
    IOR full stripe EC tests.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '32M',
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
        'test_name': 'ec_ior_full_stripe_EC_2P1GX',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 8, 10)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_2P1GX',
        'env_vars': dict(env_vars, xfer_size='2M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ec_ior_full_stripe_EC_4P2GX',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (6, 12, 10)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_4P2GX',
        'env_vars': dict(env_vars, xfer_size='4M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ec_ior_full_stripe_EC_8P2GX',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (10, 20, 10)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_8P2GX',
        'env_vars': dict(env_vars, xfer_size='8M'),
        'enabled': False
    },
    {
        'test_group': 'IOR',
        'test_name': 'ec_ior_full_stripe_EC_16P2GX',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (18, 36, 10)
        ],
        'ec_cell_size': [
            (65536),
            (1048576)
        ],
        'oclass': 'EC_16P2GX',
        'env_vars': dict(env_vars, xfer_size='16M'),
        'enabled': False
    },
]
