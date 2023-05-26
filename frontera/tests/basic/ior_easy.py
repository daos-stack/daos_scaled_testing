'''
    Basic IOR easy tests with rf0.
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
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_easy',
        'oclass': 'SX',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (1, 4, 6),
            (2, 8, 6),
            (4, 16, 6),
            (8, 32, 6),
            (16, 64, 6),
            #(32, 128, 6),
            #(64, 256, 6),
            #(128, 512, 6),
            #(256, 1024, 6),

            # c16, (num_servers, num_clients, timeout_minutes)
            (1, 16, 6),
            (2, 16, 6),
            #(4, 16, 6), # duplicate of 1to4
            (8, 16, 6),
            (16, 16, 6),
            (32, 16, 6),
            (64, 16, 6),
            (128, 16, 6),
            #(256, 16, 6),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
