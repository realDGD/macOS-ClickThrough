#!/usr/bin/env python3
"""Check pinned-source inputs and the actual Homebrew DSL round trip without installing apps."""
import json
import os
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'app/scripts'))
from source_cask import BUILD, render_source_cask


class SourceCaskTests(unittest.TestCase):
    def test_committed_recipe_matches_the_checked_template(self):
        content = (ROOT / 'Casks/clickthrough.rb').read_text()
        version = re.search(r"^  version '([^']+)'$", content, re.MULTILINE).group(1)
        digest = re.search(r"^  sha256 '([^']+)'$", content, re.MULTILINE).group(1)
        commit = re.search(r'/archive/([0-9a-f]{40})\.tar\.gz', content).group(1)
        self.assertEqual(content, render_source_cask(version, digest, commit))

    def test_invalid_source_identifiers_are_rejected(self):
        for version, digest, commit in [('0.1;bad', 'a' * 64, 'b' * 40),
                                        ('0.1.3', 'a' * 63, 'b' * 40),
                                        ('0.1.3', 'a' * 64, 'main'),
                                        ('0.1.3', 'A' * 64, 'b' * 40)]:
            with self.subTest(version=version, digest=digest, commit=commit):
                with self.assertRaises(ValueError):
                    render_source_cask(version, digest, commit)

    @unittest.skipUnless(shutil.which('brew'), 'Homebrew required for the DSL round trip')
    def test_homebrew_delivers_the_exact_shell_command(self):
        ruby = 'require "cask/cask_loader"; require "json"; puts JSON.generate(Cask::CaskLoader.load(File.read(ARGV.fetch(0))).to_h)'
        cask = json.loads(subprocess.check_output(['brew', 'ruby', '-e', ruby, '--', str(ROOT / 'Casks/clickthrough.rb')],
                         text=True, env=dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1', HOMEBREW_NO_ANALYTICS='1')))
        step = next(a['preflight_steps'][0]['steps'][0] for a in cask['artifacts'] if 'preflight_steps' in a)
        self.assertEqual(step['args'][1], BUILD)
        self.assertEqual(step['env']['DEVELOPER_DIR'], '/Library/Developer/CommandLineTools')
        subprocess.run(['bash', '-n'], input=step['args'][1], text=True, check=True)


if __name__ == '__main__':
    unittest.main()
