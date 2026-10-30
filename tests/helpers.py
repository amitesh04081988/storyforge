"""Shared test helpers: find a real Git Bash on Windows, where a bare "bash" may be the WSL launcher."""
import os
from pathlib import Path
import shutil


def find_bash():
    if os.environ.get("STORYFORGE_BASH"):
        return os.environ["STORYFORGE_BASH"]
    found = shutil.which("bash")
    if os.name == "nt" and (not found or "system32" in found.lower()):
        for candidate in (r"C:\Program Files\Git\bin\bash.exe", r"C:\Program Files (x86)\Git\bin\bash.exe"):
            if Path(candidate).exists():
                return candidate
    return found or "bash"


BASH = find_bash()
