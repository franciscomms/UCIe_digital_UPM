#!/usr/bin/env python3
"""Check the delivered source snapshot against its SHA-256 manifest."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'source_manifest.json').read_text())
failures=[]
for item in manifest['files']:
    path=root/item['path']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
        failures.append(item['path'])
if failures:
    raise SystemExit('Changed or missing snapshot files:\n'+'\n'.join(failures))
print(f"PASS: {len(manifest['files'])} source hashes; Berkeley {manifest['berkeley_commit']}")
