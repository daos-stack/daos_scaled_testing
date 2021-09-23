'''
    self_test test cases.
    Defines a list 'tests' containing dictionary items of tests.
'''

# List of tests
tests = [
    {
        'test_group': 'SELF_TEST',
        'test_name': 'st_1tomany_cli2srv_inf1',
        'scale': [
            # 1to4, (num_servers, num_clients, timeout_minutes)
            (2, 1, 15),
            (4, 1, 15),
            (8, 1, 15),
            (16, 1, 15),
            (32, 1, 15),
            (64, 1, 15),
            (128, 1, 15),
            (256, 1, 15),
            (512, 1, 15),
        ],
        'env_vars': {
            'inflight': 1,
            'ppc': 1
        },
        'enabled': False
    },
    {
        'test_group': 'SELF_TEST',
        'test_name': 'st_1tomany_cli2srv_inf16',
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (2, 1, 15),
            (4, 1, 15),
            (8, 1, 15),
            (16, 1, 15),
            (32, 1, 15),
            (64, 1, 15),
            (128, 1, 15),
            (256, 1, 15),
            (512, 1, 15)
        ],
        'env_vars': {
            'inflight': 16,
            'ppc': 1
        },
        'enabled': False
    },
]
