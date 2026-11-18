"""Build an immutable content asset and an Ed25519-signed catalog. No network."""
import argparse
import base64
import hashlib
import json
import os
import re
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization


def validate(pack):
    if pack.get('schema') != 1 or pack.get('id') != 'temel' or type(pack.get('version')) is not int or pack['version'] < 1:
        raise ValueError('Invalid schema/id/version')
    guides = pack.get('guides')
    if not isinstance(guides, list) or not 1 <= len(guides) <= 10000:
        raise ValueError('Invalid guide count')
    ids = set()
    for guide in guides:
        for field in ('id', 'title', 'category', 'summary', 'body', 'updated', 'source', 'license'):
            if not isinstance(guide.get(field), str) or not guide[field].strip() or len(guide[field]) > 100000:
                raise ValueError(f'Invalid {field}')
        if not re.fullmatch(r'[a-z0-9-]{1,80}', guide['id']) or guide['id'] in ids:
            raise ValueError('Invalid/duplicate ID')
        ids.add(guide['id'])
    return pack


def build(source, output, repository, seed):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid repository')
    pack = validate(json.loads(Path(source).read_text()))
    raw = (json.dumps(pack, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
    if len(raw) > 20 * 1024 * 1024:
        raise ValueError('Text pack exceeds 20 MiB client limit')
    key = Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed, validate=True))
    public = base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode()
    config = json.loads(Path('config/release.json').read_text())
    if public != config['AZIK_PUBLIC_KEY']:
        raise ValueError('Signing key does not match the app trust key')
    v = pack['version']
    payload = json.dumps(dict(schema=1, id='temel', version=v, minAppBuild=1,
        bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
        url=f'https://github.com/{repository}/releases/download/content-v{v}/temel.json'), separators=(',', ':')).encode()
    envelope = dict(payload=base64.b64encode(payload).decode(), signature=base64.b64encode(key.sign(payload)).decode())
    output = Path(output); output.mkdir(parents=True, exist_ok=True)
    (output / 'temel.json').write_bytes(raw)
    (output / 'catalog.json').write_text(json.dumps(envelope, indent=2) + '\n')
    print(f'Built content-v{v}: {len(raw)} bytes, {len(pack["guides"])} guides')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='assets/content/temel.json')
    parser.add_argument('--output', default='build/content')
    parser.add_argument('--repository', default='reputasyon/azik')
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    if args.validate_only:
        validate(json.loads(Path(args.source).read_text()))
        print('Content valid')
    else:
        build(args.source, args.output, args.repository, os.environ['AZIK_SIGNING_KEY'])
