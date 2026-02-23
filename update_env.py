
import os

keys = {
    "SECRET_KEY": "fb0161f3e9e787e5711822389e9950f27ceeb98559cf38f87ca86dc73b9c29d0",
    "APP_ENCRYPTION_KEY": "31e442d5acf8b67566d6ec5c3751c1ca127b405f33fdb2cd49429d41384f5fab",
    "BOOTSTRAP_ADMIN_TOKEN": "dedd812ca99d505de8185e00302d738e1e9901153296469130754330d2189865",
    "POSTGRES_PASSWORD": "b560fc599e08676c196d924f8e1348a727390f0237ca5e672048b884f08a721f",
    "REDIS_PASSWORD": "fdbfeff04c351892fc69e399f3e1d595793be44396e72f9e8ec5458bb2ddd1af"
}

env_file = ".env"
with open(env_file, "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    updated = False
    for key, value in keys.items():
        if line.startswith(f"{key}="):
            new_lines.append(f"{key}={value}\n")
            updated = True
            break
    if not updated:
        new_lines.append(line)

with open(env_file, "w") as f:
    f.writelines(new_lines)

print("Updated .env successfully")
