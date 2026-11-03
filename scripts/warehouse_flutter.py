"""Optional APK verification only. Ordinary Flutter builds do not use this script."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('verify',), nargs='?', default='verify')
    parser.add_argument('--apk', type=Path, default=ROOT / 'build/app/outputs/flutter-apk/app-release.apk')
    args = parser.parse_args()
    try:
        source = (ROOT / 'lib/warehouse_photo_config.local.dart').read_text(encoding='utf-8')
        values = []
        for key in ('warehousePhotoBase', 'warehousePhotoToken', 'warehousePhotoCa'):
            literal = re.search(r'const String ' + key + r' = ("(?:\\.|[^"\\])*");', source).group(1)
            values.append(json.loads(literal.replace(r'\$', '$')))
        if any(not v for v in values) or len(values[1]) < 32:
            raise ValueError()
    except (OSError, ValueError, AttributeError):
        raise SystemExit('Missing or invalid local photo configuration. No values printed.') from None
    with zipfile.ZipFile(args.apk) as archive:
        libraries = [n for n in archive.namelist() if n.startswith('lib/') and n.endswith('/libapp.so')]
        if not libraries:
            libraries = [n for n in archive.namelist() if n.endswith('/kernel_blob.bin')]
        if not libraries:
            raise SystemExit('No Dart libraries or debug kernel in APK.')
        for name in libraries:
            data = archive.read(name)
            if not all(v.encode() in data for v in values):
                raise SystemExit(f'Configuration mismatch in {name}. Do not install this APK.')
    print(f'Photo configuration verified in {len(libraries)} Dart artifacts. No secrets printed.')
    print('APK:', args.apk.resolve())
    print('SHA-256:', hashlib.sha256(args.apk.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
