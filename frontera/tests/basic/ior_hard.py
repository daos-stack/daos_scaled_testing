'''
    Basic IOR hard tests with rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '470080',
    'segments': '10000000',
    'xfer_size': '47008',
    'block_size': '47008',
    'sw_time': '60',
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'IOR',
        'test_name': 'ior_hard',
        'oclass': 'SX',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (1, 4, 10),
            (2, 8, 10),
            (4, 16, 10),
            (8, 32, 10),
            #(16, 64, 10),
            #(32, 128, 10),
            #(64, 256, 10),
            #(128, 512, 10),
            #(256, 1024, 10),

            # c16, (num_servers, num_clients, timeout_minutes)
            (1, 16, 10),
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
]
