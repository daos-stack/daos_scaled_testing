'''
    cart test cases.
    Defines a list 'tests' containing dictionary items of tests.
'''

# List of tests
tests = [
    {
        'test_group': 'CART',
        'test_name': 'cart_test_group_np_srv',
        'scale': [
            #(1, 1, 5),
            (2, 1, 10)
        ],
        'env_vars': {
            'inflight': 32,
            'ppc': 1
        },
        'enabled': True
    },
]
