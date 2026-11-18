"""One-time maintainer setup. Private seed is passed to gh on stdin, never stored."""
import base64
import json
import subprocess
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

config_path = Path('config/release.json')
config = json.loads(config_path.read_text())
if config['AZIK_PUBLIC_KEY']:
    raise SystemExit('A trust key already exists. Refusing implicit key rotation.')
key = Ed25519PrivateKey.generate()
seed = base64.b64encode(key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()))
subprocess.run(['gh', 'secret', 'set', 'AZIK_SIGNING_KEY', '--repo', config['AZIK_REPOSITORY']], input=seed, check=True)
config['AZIK_PUBLIC_KEY'] = base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode()
config_path.write_text(json.dumps(config, indent=2) + '\n')
print('GitHub signing secret configured; only public key saved locally.')
