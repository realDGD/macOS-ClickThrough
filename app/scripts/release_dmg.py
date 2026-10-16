"""Read-only, noninteractive DMG inspection; never installs or launches applications."""
from contextlib import contextmanager
from pathlib import Path
import subprocess
import tempfile


@contextmanager
def mounted_dmg(image):
    with tempfile.TemporaryDirectory(prefix='clickthrough-dmg-mount-') as temporary:
        mount = Path(temporary) / 'volume'
        mount.mkdir()
        subprocess.run(['hdiutil', 'attach', '-readonly', '-verify', '-nobrowse', '-noautoopen',
                        '-mountpoint', str(mount), str(image.resolve())],
                       check=True, capture_output=True)
        try:
            yield mount
        finally:
            subprocess.run(['hdiutil', 'detach', '-quiet', str(mount)], check=True)
