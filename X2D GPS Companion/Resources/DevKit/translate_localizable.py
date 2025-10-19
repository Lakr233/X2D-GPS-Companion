import json
import os
import sys

# Default path to the Localizable.xcstrings file
default_file_path = os.path.join(os.path.dirname(__file__), '..', 'Localizable.xcstrings')

# Allow overriding the file path via command line argument
file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path

# Dictionary of translations to add or update
# Format: {key: {lang: value, ...}}
translations_to_add = {
    # Example: Add translations for new or missing strings here
    # "NEW_KEY": {
    #     "en": "New Key",
    #     "de": "Neuer Schlüssel",
    #     "fr": "Nouvelle Clé",
    #     "ja": "新しいキー",
    #     "zh-Hans": "新键"
    # }
}

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Update translations
strings = data['strings']

# Add or update translations from the dictionary
for key, langs in translations_to_add.items():
    if key not in strings:
        strings[key] = {"localizations": {}}
    locs = strings[key]['localizations']
    for lang, value in langs.items():
        locs[lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value
            }
        }

# Change 'needsReview' or 'new' states to 'translated' for all languages
for key, value in strings.items():
    if 'localizations' in value:
        for lang, loc in value['localizations'].items():
            if loc['stringUnit']['state'] in ['needsReview', 'new']:
                loc['stringUnit']['state'] = 'translated'

# Write back to the file
with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Translation updates completed for {file_path}.")