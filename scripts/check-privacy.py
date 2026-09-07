#!/usr/bin/env python3
"""Check the working snapshot and every reachable commit without printing matches."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RULES = {
    "absolute personal directory": re.compile(r"/(?:home|Users)/[A-Za-z0-9_.-]+|[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9_.-]+"),
    "email address": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "credential in URL": re.compile(r"https?://[^\s/:]+:[^\s/@]+@"),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}
FORBIDDEN_PARTS = {".aws", ".azure", ".ssh", ".codex", ".claude", ".gemini", ".opencode", ".cache", ".local"}
FORBIDDEN_NAMES = {".gitconfig", ".git-credentials", ".netrc", "hosts.yml", ".claude.json", ".bashrc.local", ".bash_profile.local"}


def issues(name, content):
    found = []
    path = Path(name)
    if (set(path.parts) & FORBIDDEN_PARTS or path.name in FORBIDDEN_NAMES
            or path.name.startswith(".env") or path.name.endswith(("_history", ".pem", ".key"))):
        found.append("private filename")
    try:
        content = content.decode("utf-8")
    except UnicodeDecodeError:
        return found + ["unexpected binary file"]
    for label, pattern in RULES.items():
        for match in pattern.finditer(content):
            if label == "email address":
                email = match.group().lower()
                if email.endswith(("@users.noreply.github.com", ".invalid")):
                    continue
            found.append(label)
            break
    return found


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def main():
    failures = []
    names = git("ls-files", "--cached", "--others", "--exclude-standard", "-z").decode().split("\0")
    for name in sorted(set(filter(None, names))):
        path = ROOT / name
        if path.is_symlink():
            failures.append((name, ["repository symlink"]))
        elif path.is_file():
            problems = issues(name, path.read_bytes())
            if problems:
                failures.append((name, problems))
    seen = set()
    for commit in git("rev-list", "--all").decode().splitlines():
        metadata = git("show", "-s", "--format=%B%n%an <%ae>%n%cn <%ce>", commit)
        problems = issues("commit metadata", metadata)
        if problems:
            failures.append((commit[:8] + " metadata", problems))
        for entry in git("ls-tree", "-rz", commit).split(b"\0"):
            if not entry:
                continue
            attributes, raw_name = entry.split(b"\t", 1)
            mode, kind, oid = attributes.split()
            name = raw_name.decode()
            key = (name, oid)
            if key in seen:
                continue
            seen.add(key)
            if mode == b"120000" or kind != b"blob":
                failures.append((name, ["symlink or submodule in history"]))
                continue
            problems = issues(name, git("cat-file", "blob", oid.decode()))
            if problems:
                failures.append((commit[:8] + ":" + name, problems))
    for location, problems in failures:
        print(f"Privacy check failed: {location}: {', '.join(problems)}", file=sys.stderr)
    if failures:
        return 1
    print("Privacy checks passed for working files and all reachable history.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
