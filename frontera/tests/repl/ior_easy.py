'''
    Standard IOR easy replication tests.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1M',
    'segments': '1',
    'xfer_size': '1M',
    'block_size': '150G',
    'sw_time': '60',
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': 'RP_2GX',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (2, 8, 10),
            (4, 16, 10),
            (8, 32, 10),
            #(16, 64, 10),
            #(32, 128, 10),
            #(64, 256, 10),
            #(128, 512, 10),
            #(256, 1024, 10),

            # c16, (num_servers, num_clients, timeout_minutes)
            (2, 16, 10),
            #(4, 16, 10), # duplicate of 1to4
            (8, 16, 10),
            (16, 16, 10),
            (32, 16, 10),
            (64, 16, 10),
            #(128, 16, 10),
            #(256, 16, 10),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': 'RP_3GX',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (4, 16, 10),
            (8, 32, 10),
            #(16, 64, 10),
            #(32, 128, 10),
            #(64, 256, 10),
            #(128, 512, 10),
            #(256, 1024, 10),

            # c16, (num_servers, num_clients, timeout_minutes)
            #(4, 16, 10), # duplicate of 1to4
            (8, 16, 10),
            (16, 16, 10),
            (32, 16, 10),
            (64, 16, 10),
            #(128, 16, 10),
            #(256, 16, 10),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
