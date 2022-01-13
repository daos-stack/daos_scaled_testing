'''
    MdTest sanity tests.
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
    'sw_time': '5',
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'MDTEST',
        'test_name': 'mdtest_sanity',
        'oclass': [('S1', 'SX')],
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (1, 1, 1),
        ],
        'env_vars': dict(env_vars),
        'enabled': True
    },
]
