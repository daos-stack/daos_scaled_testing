'''
    Rebuild sanity tests.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'number_of_pools': '1',
    'pool_size': '85G',
    'chunk_size': '1M',
    'segments': '1',
    'xfer_size': '1M',
    'block_size': None, # placeholder
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'SWIM_IOR',
        'test_name': 'rebuild_pool_load_sanity',
        'oclass': 'EC_2P1GX',
        'ec_cell_size': 65536, # 1M chunk / 16
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 1, 5),
        ],
        'env_vars': dict(
            env_vars,
            cont_prop='dedup:memcmp,rf:1',
            block_size='100M'),
        'enabled': True
    },
    {
        'test_group': 'SWIM',
        'test_name': 'rebuild_pool_multi_sanity',
        'oclass': 'EC_2P1GX',
        'ec_cell_size': 65536, # 1M chunk / 16
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (4, 1, 5),
        ],
        'env_vars': dict(
            env_vars,
            cont_prop='dedup:memcmp,rf:1',
            block_size='100M',
            pool_size='256MiB',
            number_of_pools='5'),
        'enabled': False
    },
]
