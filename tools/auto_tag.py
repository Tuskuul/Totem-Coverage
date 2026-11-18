#!/usr/bin/env python3
"""Create immutable version tags for validated Totem Coverage branch pushes."""
import os
from pathlib import Path
import re
import subprocess
import sys

def git(*args, check=True):
    return subprocess.run(["git", *args], text=True, capture_output=True, check=check)

def version_at(revision):
    if revision:
        raw = git("show", revision + ":TotemCoverage.toc").stdout
    else:
        raw = Path("TotemCoverage.toc").read_text(encoding="utf-8")
    matches = re.findall(r"^## Version:\s*(\S+)\s*$", raw, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError("Expected one TOC version")
    return matches[0]

def remote(ref):
    p = git("ls-remote", "--exit-code", "origin", ref, check=False)
    if p.returncode == 2:
        return None
    if p.returncode:
        raise ValueError("Could not check remote refs")
    return p.stdout.split()[0] if p.stdout.strip() else None

def main():
    branch = os.environ["GITHUB_REF_NAME"]
    sha = os.environ["GITHUB_SHA"]
    previous = os.environ.get("PREVIOUS_COMMIT", "")
    if branch not in ("main", "beta"):
        return
    if git("rev-parse", "HEAD").stdout.strip() != sha:
        raise ValueError("Checkout does not match event commit")
    version = version_at(None)
    pattern = r"\d+\.\d+\.\d+" if branch == "main" else r"\d+\.\d+\.\d+-beta\.\d+"
    if not re.fullmatch(pattern, version):
        raise ValueError("Incorrect version format for branch: " + version)
    if not Path("Core.lua").is_file() or not Path("Offensive.lua").is_file() or not Path("Settings.lua").is_file():
        raise ValueError("Missing addon source files")
    if not Path("TotemCoverage.toc").read_text(encoding="utf-8").endswith("Offensive.lua\n"):
        raise ValueError("TOC load list unexpected")
    if ('local VERSION = "' + version + '"') not in Path("Core.lua").read_text(encoding="utf-8"):
        raise ValueError("Core and TOC versions differ")
    tag = "v" + version
    ref = "refs/tags/" + tag
    if remote(ref):
        print("Tag already exists; leaving immutable tag alone: " + tag)
        return
    if branch == "main" and re.fullmatch(r"[a-f0-9]{40}", previous) and previous != "0" * 40:
        if version_at(previous) == version:
            print("Stable version unchanged; no release tag created")
            return
    if remote("refs/heads/" + branch) != sha:
        print("Branch advanced; skipping outdated run")
        return
    git("tag", "--no-sign", tag, sha)
    pushed = git("push", "origin", ref + ":" + ref, check=False)
    if pushed.returncode and not remote(ref):
        raise ValueError("Unable to push version tag")
    print("Published " + tag + " from " + branch + " at " + sha)

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print("Auto-tag failed:", error, file=sys.stderr)
        sys.exit(1)
