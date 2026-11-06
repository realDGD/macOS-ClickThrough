#!/usr/bin/env python3
"""Check update identities on disposable bundles; never launch apps or change permissions."""
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, default=root / 'build/ClickThrough.app')
args = parser.parse_args()
signer = root / 'scripts/sign-app.sh'
records = []


def run(*command, success=True, env=None):
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result


def sign(app, stable='0', identity='-', success=True):
    environment = dict(os.environ, CLICKTHROUGH_STABLE_ADHOC_IDENTITY=stable,
                       CLICKTHROUGH_SIGN_IDENTITY=identity)
    run('bash', str(signer), str(app), success=success, env=environment)


def requirement(app):
    result = run('codesign', '--display', '--requirements', '-', str(app))
    return next(line.removeprefix('# ').removeprefix('designated => ')
                for line in (result.stdout + result.stderr).splitlines()
                if line.startswith(('designated => ', '# designated => ')))


def code_hash(app):
    result = run('codesign', '--display', '--verbose=3', str(app))
    return re.search(r'^CDHash=(\w+)$', result.stderr, re.MULTILINE).group(1)


with tempfile.TemporaryDirectory(prefix='clickthrough-signing-') as temporary:
    first = Path(temporary) / 'first version/ClickThrough.app'
    second = Path(temporary) / 'second version/ClickThrough.app'
    shutil.copytree(args.app, first)
    sign(first)
    old_requirement = requirement(first)
    assert old_requirement.startswith('cdhash H"'), old_requirement
    shutil.copytree(first, second)
    info = second / 'Contents/Info.plist'
    metadata = plistlib.loads(info.read_bytes())
    metadata['CFBundleVersion'] = str(int(metadata['CFBundleVersion']) + 1)
    info.write_bytes(plistlib.dumps(metadata))
    sign(second)
    assert code_hash(first) != code_hash(second)
    run('codesign', '--verify', '--strict', '-R', '=' + old_requirement, str(second), success=False)
    records.append('default hash identity rejects changed version')

    for app in (first, second):
        sign(app, stable='1')
        assert requirement(app) == 'identifier "local.clickthrough.app"'
        run('codesign', '--verify', '--strict', '-R', '=identifier "local.clickthrough.app"', str(app))
    assert code_hash(first) != code_hash(second)
    run('codesign', '--verify', '--strict', '-R', '=' + old_requirement, str(first), success=False)
    records.append('different code hashes satisfy the same explicit identity; migration changes identity')

    before = hashlib.sha256((first / 'Contents/MacOS/ClickThrough').read_bytes()).hexdigest()
    sign(first, stable='invalid', success=False)
    sign(first, stable='1', identity='nonexistent-test-certificate', success=False)
    assert hashlib.sha256((first / 'Contents/MacOS/ClickThrough').read_bytes()).hexdigest() == before
    run('codesign', '--verify', '--strict', str(first))
    records.append('invalid signing options reject without changing signature')

    metadata['CFBundleIdentifier'] = 'local.clickthrough.signing-test-other'
    info.write_bytes(plistlib.dumps(metadata))
    sign(second, stable='1', success=False)
    run('codesign', '--force', '--sign', '-', '--identifier', metadata['CFBundleIdentifier'],
        '--requirements', '=designated => identifier "local.clickthrough.signing-test-other"', str(second))
    run('codesign', '--verify', '--strict', '-R', '=identifier "local.clickthrough.app"', str(second), success=False)
    records.append('another application identifier is rejected')

    info = first / 'Contents/Info.plist'
    metadata = plistlib.loads(info.read_bytes())
    metadata['CFBundleVersion'] = str(int(metadata['CFBundleVersion']) + 2)
    info.write_bytes(plistlib.dumps(metadata))
    run('codesign', '--verify', '--strict', str(first), success=False)
    records.append('tampered sealed content fails integrity verification')

print(json.dumps({'cases': records, 'failures': 0,
                  'scope': 'disposable copies; no app launch, installation, or TCC changes'}, indent=2))
