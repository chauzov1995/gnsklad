"""One-time setup of the ignored Dart configuration. Not part of the build."""
import argparse
import base64
import json
from pathlib import Path
import ssl
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'lib/warehouse_photo_config.local.dart'
BASE = 'https://172.16.4.104:3443'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    # Refuse to write secrets unless Git already ignores this exact path.
    if subprocess.run(['git', 'check-ignore', '--quiet', str(DEST)], cwd=ROOT).returncode:
        raise SystemExit('Local configuration must be excluded from Git before setup.')
    if subprocess.check_output(['git', 'ls-files', '--', str(DEST)], cwd=ROOT).strip():
        raise SystemExit('Local configuration is tracked by Git; setup refused.')
    if DEST.exists():
        raise SystemExit('Local configuration already exists; nothing overwritten.')
    try:
        data = json.loads(args.source.read_text(encoding='utf-8-sig'))
        token, ca = data['PHOTO_TOKEN'], data['PHOTO_CA_B64']
        if not isinstance(token, str) or len(token) < 32 or data.get('PHOTO_BASE', BASE) != BASE:
            raise ValueError()
        pem = base64.b64decode(ca, validate=True).decode('ascii')
        ssl.create_default_context().load_verify_locations(cadata=pem)
    except (OSError, ValueError, TypeError, KeyError, ssl.SSLError):
        raise SystemExit('Invalid or unreadable source configuration. No values printed.') from None
    def literal(value):
        return json.dumps(value, ensure_ascii=True).replace('$', r'\$')
    content = '// Private local configuration. Never commit this file.\n'
    for name, value in [('warehousePhotoBase', BASE), ('warehousePhotoToken', token), ('warehousePhotoCa', ca)]:
        content += f'const String {name} = {literal(value)};\n'
    with DEST.open('x', encoding='utf-8', newline='\n') as output:
        output.write(content)
    print('Local photo configuration created. Ordinary Flutter builds are ready.')


if __name__ == '__main__':
    main()
