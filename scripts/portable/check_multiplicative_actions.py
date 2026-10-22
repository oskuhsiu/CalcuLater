#!/usr/bin/env python3
"""Compile and exhaustively test the production Foundation-free action kernel."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sanitize", action="store_true", help="Also enable address/undefined-behavior sanitizers.")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
compiler = os.environ.get("CC", "cc")
with tempfile.TemporaryDirectory(prefix="calculater-action-core-") as directory:
    executable = Path(directory) / "multiplicative-actions"
    command = [compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2"]
    if args.sanitize:
        command += ["-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"]
    command += ["-I", str(root / "Calcu Later"),
                str(root / "Calcu Later/MultiplicativeTeachingActionCore.c"),
                str(root / "scripts/portable/test_multiplicative_actions.c"), "-o", str(executable)]
    subprocess.run(command, check=True)
    subprocess.run([str(executable)], check=True)
