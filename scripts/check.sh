#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
cd "$project_dir"
zsh "$project_dir/build.sh"
python3 - <<'PY'
from pathlib import Path
import ast
sources = list(Path("Tests").glob("*.py")) + list(Path("scripts").glob("*.py"))
for source in sorted(sources):
    ast.parse(source.read_text(), filename=str(source))
print("PASS Python test-tool syntax")
PY
