'''
    Rebuild EC tests with empty pool(s).
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'number_of_pools': '1',
    'pool_size': '85G',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'SWIM',
        'test_name': 'rebuild_pool_single',
        'oclass': 'EC_16P2GX',
        'ec_cell_size': 65536, # 1M chunk / 16
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (64, 1, 10),
        ],
        'env_vars': dict(
            env_vars,
            cont_prop='dedup:memcmp,rf:2'),
        'enabled': True
    },
    {
        'test_group': 'SWIM',
        'test_name': 'rebuild_pool_multi',
        'oclass': 'EC_16P2GX',
        'ec_cell_size': 65536, # 1M chunk / 16
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (64, 1, 15),
        ],
        'env_vars': dict(
            env_vars,
            cont_prop='dedup:memcmp,rf:2',
            number_of_pools=73,
            pool_size='256MiB', # Minimum 16MiB per rank
        ),
        'enabled': True
    },
]
