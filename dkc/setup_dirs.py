import os

base_dir = '/Users/blackbird/Everything/dev/DKC/protiti/lib'

directories = [
    'data/models',
    'data/repositories',
    'data/services',
    'domain/models',
    'domain/use_cases',
    'ui/core/theme',
    'ui/core/widgets',
    'ui/features/auth',
    'ui/features/vault',
    'ui/features/evidence',
    'ui/features/complaint',
    'ui/features/panic',
    'ui/features/contacts',
    'ui/features/support',
    'ui/features/settings'
]

for d in directories:
    os.makedirs(os.path.join(base_dir, d), exist_ok=True)
