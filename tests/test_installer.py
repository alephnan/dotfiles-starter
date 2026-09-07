"""Filesystem and failure tests; never install packages or touch the real home."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("privacy", ROOT / "scripts/check-privacy.py")
privacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(privacy)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.source = self.root / "source with spaces"
        self.source.write_text("shared configuration\n")
        self.env = dict(os.environ, HOME=str(self.home), SOURCE=str(self.source), REPO=str(ROOT))
        for key in ("XDG_CONFIG_HOME", "STARSHIP_CONFIG", "NVIM_APPNAME", "BASH_ENV", "ENV"):
            self.env.pop(key, None)

    def run_bash(self, script, success=True):
        result = subprocess.run(["bash", "--noprofile", "--norc", "-c",
                                 'source "$REPO/bootstrap.sh"\n' + script],
                                env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def backups(self):
        return list(self.home.glob(".dotfiles-backup-*"))

    def test_new_link_and_repeat_do_not_create_backups(self):
        self.run_bash('link_file "$SOURCE" .bashrc\nlink_file "$SOURCE" .bashrc')
        self.assertEqual((self.home / ".bashrc").resolve(), self.source)
        self.assertEqual(self.backups(), [])

    def test_regular_file_is_preserved(self):
        target = self.home / ".bashrc"
        target.write_text("private original")
        self.run_bash('link_file "$SOURCE" .bashrc')
        self.assertEqual((self.backups()[0] / ".bashrc").read_text(), "private original")
        self.assertEqual(target.resolve(), self.source)

    def test_existing_directory_is_preserved(self):
        target = self.home / ".config/nvim"
        target.mkdir(parents=True)
        (target / "init.lua").write_text("original")
        self.run_bash('link_file "$SOURCE" .config/nvim')
        self.assertEqual((self.backups()[0] / ".config/nvim/init.lua").read_text(), "original")

    def test_symlink_is_preserved_without_touching_its_target(self):
        original = self.root / "original"
        original.write_text("keep")
        (self.home / ".bashrc").symlink_to(original)
        self.run_bash('link_file "$SOURCE" .bashrc')
        backup = self.backups()[0] / ".bashrc"
        self.assertTrue(backup.is_symlink())
        self.assertEqual(os.readlink(backup), str(original))
        self.assertEqual(original.read_text(), "keep")

    def test_broken_symlink_is_preserved(self):
        (self.home / ".bashrc").symlink_to("missing-original")
        self.run_bash('link_file "$SOURCE" .bashrc')
        self.assertEqual(os.readlink(self.backups()[0] / ".bashrc"), "missing-original")

    def test_backup_preserves_relative_layout(self):
        (self.home / ".config").mkdir()
        (self.home / ".config/starship.toml").write_text("nested")
        (self.home / "starship.toml").write_text("top")
        self.run_bash('link_file "$SOURCE" .config/starship.toml\nlink_file "$SOURCE" starship.toml')
        backup = self.backups()[0]
        self.assertEqual((backup / ".config/starship.toml").read_text(), "nested")
        self.assertEqual((backup / "starship.toml").read_text(), "top")

    def test_separate_runs_cannot_overwrite_a_backup(self):
        for value in ("first", "second"):
            target = self.home / ".bashrc"
            if target.is_symlink():
                target.unlink()
            target.write_text(value)
            self.run_bash('link_file "$SOURCE" .bashrc')
        self.assertEqual(sorted((p / ".bashrc").read_text() for p in self.backups()), ["first", "second"])

    def test_dry_run_never_invokes_package_or_network_commands(self):
        result = self.run_bash('sudo() { exit 91; }; curl() { exit 92; }; git() { exit 93; }; main --dry-run --with-dev-tools')
        self.assertIn("Optional Python/Rust tooling: 1", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_override_rejected_before_linking(self):
        for variable, value in (("XDG_CONFIG_HOME", "/tmp/custom-config"), ("NVIM_APPNAME", "custom"),
                                ("STARSHIP_CONFIG", "/tmp/custom-prompt")):
            with self.subTest(variable=variable):
                self.run_bash(f'export {variable}={value}; main --dry-run', success=False)
                self.assertEqual(list(self.home.iterdir()), [])

    def test_unknown_flag_is_an_error(self):
        self.run_bash('main --unknown', success=False)

    def test_download_failure_stops_before_installing(self):
        self.run_bash('curl() { return 22; }; download_verified https://example.invalid/archive deadbeef "$HOME/download"', success=False)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_corrupt_download_is_rejected(self):
        result = self.run_bash('curl() { printf corrupted > "${@: -1}"; }; download_verified https://example.invalid/archive '
                               + '0' * 64 + ' "$HOME/download"', success=False)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertFalse((self.home / ".local").exists())

    def test_plugin_conflict_is_not_overwritten(self):
        plugin = self.home / "plugin"
        plugin.mkdir()
        (plugin / "keep").write_text("original")
        self.run_bash('clone_pinned https://example.invalid/plugin "$HOME/plugin" abc', success=False)
        self.assertEqual((plugin / "keep").read_text(), "original")

    def test_path_entries_do_not_accumulate(self):
        self.run_bash('prepend_bin "$HOME/.local/bin"; prepend_bin "$HOME/.local/bin"; '
                      '[[ "$PATH" != *"$HOME/.local/bin:$HOME/.local/bin"* ]]')

    def test_missing_dependency_fails_before_config_linking(self):
        result = self.run_bash('nvim() { printf "NVIM v0.9.0\\n"; }; tree-sitter() { printf "tree-sitter 0.26.3\\n"; }; '
                              'starship() { :; }; tmux() { :; }; rg() { :; }; fd() { :; }; check_dependencies', success=False)
        self.assertIn("Neovim 0.12+", result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])


class PrivacyTests(unittest.TestCase):
    def test_detects_personal_paths_without_exposing_values(self):
        value = ("/" + "home/" + "example-user/private").encode()
        self.assertIn("absolute personal directory", privacy.issues("README.md", value))

    def test_detects_private_email(self):
        value = ("someone" + "@" + "personal.test").encode()
        self.assertIn("email address", privacy.issues("README.md", value))

    def test_rejects_private_file_even_without_secret_pattern(self):
        self.assertIn("private filename", privacy.issues(".git-credentials", b"anything"))


if __name__ == "__main__":
    unittest.main()
