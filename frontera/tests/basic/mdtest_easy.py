'''
    Basic MdTest easy tests with rf0.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'pool_size': '85G',
    'chunk_size': '1M',
    'n_file': '10000000',
    'mdtest_flags': '-C -T -r -u -L',
    'bytes_read': '0',
    'bytes_write': '0',
    'sw_time': '60',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_easy',
        'oclass': [('S1', 'SX')],
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
