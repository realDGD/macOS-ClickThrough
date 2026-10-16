#!/usr/bin/env python3
"""Rasterize the checked-in SVG and produce the macOS ICNS using system tools."""
import shutil
import subprocess
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    artwork = root / "Resources/Artwork"
    output = root / "Resources/AppIcon.icns"
    with tempfile.TemporaryDirectory(prefix="clickthrough-icon-") as directory:
        temporary = Path(directory)
        master = temporary / "AppIcon.png"
        subprocess.run(["sips", "-s", "format", "png", str(artwork / "AppIcon.svg"),
                        "--out", str(master)], check=True, capture_output=True)
        iconset = temporary / "AppIcon.iconset"
        iconset.mkdir()
        for points in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                pixels = points * scale
                suffix = "@2x" if scale == 2 else ""
                target = iconset / f"icon_{points}x{points}{suffix}.png"
                subprocess.run(["sips", "-z", str(pixels), str(pixels), str(master),
                                "--out", str(target)], check=True, capture_output=True)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(output)], check=True)
        shutil.copy2(master, artwork / "AppIcon.png")
    print(output)


if __name__ == "__main__":
    main()
