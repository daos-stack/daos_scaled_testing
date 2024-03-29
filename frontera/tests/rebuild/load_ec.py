'''
    Rebuild EC tests with pool load.
    Defines a list 'tests' containing dictionary items of tests.
'''

# Default environment variables used by each test
env_vars = {
    'number_of_pools': '1',
    'pool_size': '85G',
    'chunk_size': '1MiB',
    'segments': '1',
    'xfer_size': '1MiB',
    'block_size': None, # placeholder
    'iterations': '1',
    'ppc': 32
}

# List of tests
tests = [
    {
        'test_group': 'SWIM_IOR',
        'test_name': 'rebuild_pool_load',
        'oclass': 'EC_16P2GX',
        'ec_cell_size': 65536, # 1M chunk / 16
        'scale': [
            # (num_servers, num_clients, timeout_minutes)
            (128, 30, 10),
        ],
        'env_vars': dict(
            env_vars,
            cont_prop='dedup:memcmp,rf:2',
            ppc=16,
            block_size='8G'),
        'enabled': True
    },
]
