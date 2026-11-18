"""Give compiled JS immutable names so an existing tab cannot mix deployments."""
import hashlib
from pathlib import Path

root = Path('build/web')
main = root / 'main.dart.js'
fingerprint = hashlib.sha256(main.read_bytes()).hexdigest()[:16]
main_name = f'main.{fingerprint}.dart.js'
main.rename(root / main_name)
bootstrap = root / 'flutter_bootstrap.js'
text = bootstrap.read_text().replace('main.dart.js', main_name)
bootstrap_name = f'flutter_bootstrap.{fingerprint}.js'
(root / bootstrap_name).write_text(text)
index = root / 'index.html'
index.write_text(index.read_text().replace('flutter_bootstrap.js', bootstrap_name))
print(f'Versioned web assets: {fingerprint}')
