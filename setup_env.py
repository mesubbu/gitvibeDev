import secrets

def generate_secret():
    return secrets.token_hex(32)

env_file = '.env'
placeholders = [
    'CHANGE_ME_SECRET_KEY',
    'CHANGE_ME_APP_ENCRYPTION_KEY',
    'CHANGE_ME_BOOTSTRAP_ADMIN_TOKEN',
    'CHANGE_ME_POSTGRES_PASSWORD',
    'CHANGE_ME_REDIS_PASSWORD'
]

with open(env_file, 'r') as f:
    content = f.read()

for placeholder in placeholders:
    new_secret = generate_secret()
    content = content.replace(placeholder, new_secret)
    print(f"Replaced {placeholder} with {new_secret[:6]}...")

# Set APP_MODE to demo
content = content.replace('APP_MODE=development', 'APP_MODE=demo')
print("Set APP_MODE=demo")

with open(env_file, 'w') as f:
    f.write(content)

print(f"Updated {env_file} successfully")
