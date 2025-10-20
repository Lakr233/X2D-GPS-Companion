import json
import os
import sys

# Default path to the Localizable.xcstrings file
default_file_path = os.path.join(os.path.dirname(__file__), '..', 'Localizable.xcstrings')

# Allow overriding the file path via command line argument
file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path

# Read the file
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"File not found: {file_path}")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"JSON decode error in {file_path}: {e}")
    sys.exit(1)

strings = data['strings']
languages = ['en', 'de', 'fr', 'ja', 'zh-Hans']
incomplete = []

for key, value in strings.items():
    locs = value.get('localizations', {})
    for lang in languages:
        if lang not in locs:
            incomplete.append((key, lang, 'missing localization'))
        elif locs[lang]['stringUnit']['state'] != 'translated':
            incomplete.append((key, lang, f"state: {locs[lang]['stringUnit']['state']}"))
        elif not locs[lang]['stringUnit'].get('value', '').strip():
            incomplete.append((key, lang, 'empty value'))

if incomplete:
    print(f"Incomplete translations in {file_path}:")
    for item in incomplete:
        print(f"  {item[0]} - {item[1]}: {item[2]}")
else:
    print(f"All translations are complete in {file_path}.")