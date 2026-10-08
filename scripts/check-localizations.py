"""Validate translation keys, placeholders and shipped bundle resources."""
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys

project = Path(__file__).resolve().parent.parent
bundle_resources = Path(sys.argv[1]) if len(sys.argv) > 1 else None

def table(path):
    return json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))

def placeholders(value):
    tokens = re.findall(r"%(?:([0-9]+)\$)?([@diufFeEgG])", value.replace("%%", ""))
    return Counter((int(index) if index else position + 1, kind) for position, (index, kind) in enumerate(tokens))

locales = sorted((project / "Resources").glob("*.lproj"))
reference = {name: table(project / "Resources/en.lproj" / name) for name in ["Localizable.strings", "InfoPlist.strings"]}
for locale in locales:
    for name, english in reference.items():
        translated = table(locale / name)
        assert translated.keys() == english.keys(), f"Translation keys differ: {locale.name}/{name}"
        for key, text in translated.items():
            assert text.strip(), f"Empty translation: {locale.name}/{key}"
            assert placeholders(text) == placeholders(english[key]), f"Placeholder mismatch: {locale.name}/{key}"
        if bundle_resources:
            assert table(bundle_resources / locale.name / name) == translated, f"Stale or missing bundle resource: {locale.name}/{name}"

known = reference["Localizable.strings"].keys()
prefixes = "app|menu|keys|state|volume|accessibility|hud|detail"
for source in (project / "Sources").iterdir():
    if source.suffix not in [".swift", ".mm"]:
        continue
    text = source.read_text()
    for key in re.findall(r'"((?:' + prefixes + r')\.[A-Za-z]+)"', text):
        assert key in known, f"Untranslated source key: {source.name}/{key}"
    assert not re.search(r'[\u4e00-\u9fff]', text), f"Move Chinese UI literals into Resources: {source.name}"
print(f"PASS localization tables: {len(known)} UI keys, matching placeholders, source references and packaged en / zh-Hans resources")
