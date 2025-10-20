#!/bin/zsh

set -euo pipefail

cd "$(dirname "$0")/../.."

MAIN_TARGET="X2D GPS Companion"
WIDGET_TARGET="X2D GPS Companion WidgetsExtension"

PROJECT_FILE="X2D GPS Companion.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Error: Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "Extracting configuration IDs from project file..."

MAIN_CONFIG_LIST_ID=$(grep "Build configuration list for PBXNativeTarget \"$MAIN_TARGET\"" "$PROJECT_FILE" | \
    grep -o '[A-F0-9]\{24\}' | head -1)

WIDGET_CONFIG_LIST_ID=$(grep "Build configuration list for PBXNativeTarget \"$WIDGET_TARGET\"" "$PROJECT_FILE" | \
    grep -o '[A-F0-9]\{24\}' | head -1)

if [[ -z "$MAIN_CONFIG_LIST_ID" ]] || [[ -z "$WIDGET_CONFIG_LIST_ID" ]]; then
    echo "Error: Failed to extract configuration list IDs"
    echo "  Main Config List ID: $MAIN_CONFIG_LIST_ID"
    echo "  Widget Config List ID: $WIDGET_CONFIG_LIST_ID"
    exit 1
fi

MAIN_DEBUG_ID=$(awk -v list_id="$MAIN_CONFIG_LIST_ID" '
    $0 ~ list_id " /\\* Build configuration list" { in_list=1; next }
    in_list && /Debug/ {
        match($0, /[A-F0-9]{24}/)
        print substr($0, RSTART, RLENGTH)
        exit
    }
' "$PROJECT_FILE")

WIDGET_DEBUG_ID=$(awk -v list_id="$WIDGET_CONFIG_LIST_ID" '
    $0 ~ list_id " /\\* Build configuration list" { in_list=1; next }
    in_list && /Debug/ {
        match($0, /[A-F0-9]{24}/)
        print substr($0, RSTART, RLENGTH)
        exit
    }
' "$PROJECT_FILE")

WIDGET_RELEASE_ID=$(awk -v list_id="$WIDGET_CONFIG_LIST_ID" '
    $0 ~ list_id " /\\* Build configuration list" { in_list=1; next }
    in_list && /Release/ {
        match($0, /[A-F0-9]{24}/)
        print substr($0, RSTART, RLENGTH)
        exit
    }
' "$PROJECT_FILE")

if [[ -z "$MAIN_DEBUG_ID" ]] || [[ -z "$WIDGET_DEBUG_ID" ]] || [[ -z "$WIDGET_RELEASE_ID" ]]; then
    echo "Error: Failed to extract configuration IDs"
    echo "  Main Debug ID: $MAIN_DEBUG_ID"
    echo "  Widget Debug ID: $WIDGET_DEBUG_ID"
    echo "  Widget Release ID: $WIDGET_RELEASE_ID"
    exit 1
fi

echo "Configuration IDs:"
echo "  Main Debug: $MAIN_DEBUG_ID"
echo "  Widget Debug: $WIDGET_DEBUG_ID"
echo "  Widget Release: $WIDGET_RELEASE_ID"
echo ""

MAIN_MARKETING_VERSION=$(awk -v id="$MAIN_DEBUG_ID" '
    $0 ~ id " /\\* Debug \\*/" { in_config=1; next }
    in_config && /MARKETING_VERSION = / { 
        match($0, /MARKETING_VERSION = [^;]+/)
        version = substr($0, RSTART, RLENGTH)
        sub(/MARKETING_VERSION = /, "", version)
        print version
        exit
    }
    in_config && /^[ \t]*};$/ { exit }
' "$PROJECT_FILE")

MAIN_BUILD_VERSION=$(awk -v id="$MAIN_DEBUG_ID" '
    $0 ~ id " /\\* Debug \\*/" { in_config=1; next }
    in_config && /CURRENT_PROJECT_VERSION = / { 
        match($0, /CURRENT_PROJECT_VERSION = [^;]+/)
        version = substr($0, RSTART, RLENGTH)
        sub(/CURRENT_PROJECT_VERSION = /, "", version)
        print version
        exit
    }
    in_config && /^[ \t]*};$/ { exit }
' "$PROJECT_FILE")

if [[ -z "$MAIN_MARKETING_VERSION" ]] || [[ -z "$MAIN_BUILD_VERSION" ]]; then
    echo "Error: Failed to extract version numbers from main app"
    echo "  MARKETING_VERSION: $MAIN_MARKETING_VERSION"
    echo "  CURRENT_PROJECT_VERSION: $MAIN_BUILD_VERSION"
    exit 1
fi

echo "Main app version:"
echo "  MARKETING_VERSION: $MAIN_MARKETING_VERSION"
echo "  CURRENT_PROJECT_VERSION: $MAIN_BUILD_VERSION"
echo ""

WIDGET_MARKETING_VERSION=$(awk -v id="$WIDGET_DEBUG_ID" '
    $0 ~ id " /\\* Debug \\*/" { in_config=1; next }
    in_config && /MARKETING_VERSION = / { 
        match($0, /MARKETING_VERSION = [^;]+/)
        version = substr($0, RSTART, RLENGTH)
        sub(/MARKETING_VERSION = /, "", version)
        print version
        exit
    }
    in_config && /^[ \t]*};$/ { exit }
' "$PROJECT_FILE")

WIDGET_BUILD_VERSION=$(awk -v id="$WIDGET_DEBUG_ID" '
    $0 ~ id " /\\* Debug \\*/" { in_config=1; next }
    in_config && /CURRENT_PROJECT_VERSION = / { 
        match($0, /CURRENT_PROJECT_VERSION = [^;]+/)
        version = substr($0, RSTART, RLENGTH)
        sub(/CURRENT_PROJECT_VERSION = /, "", version)
        print version
        exit
    }
    in_config && /^[ \t]*};$/ { exit }
' "$PROJECT_FILE")

echo "Widget Extension current version:"
echo "  MARKETING_VERSION: $WIDGET_MARKETING_VERSION"
echo "  CURRENT_PROJECT_VERSION: $WIDGET_BUILD_VERSION"
echo ""

if [[ "$MAIN_MARKETING_VERSION" == "$WIDGET_MARKETING_VERSION" ]] && \
   [[ "$MAIN_BUILD_VERSION" == "$WIDGET_BUILD_VERSION" ]]; then
    echo "✅ Versions are already synchronized, no changes needed"
    echo ""
    echo "Sync complete!"
    exit 0
fi

echo "Updating Widget Extension versions..."

TMP_FILE=$(mktemp)

awk -v marketing="$MAIN_MARKETING_VERSION" \
    -v build="$MAIN_BUILD_VERSION" \
    -v widget_debug="$WIDGET_DEBUG_ID" \
    -v widget_release="$WIDGET_RELEASE_ID" '
    $0 ~ widget_debug " /\\* Debug \\*/" { in_widget_debug=1 }
    $0 ~ widget_release " /\\* Release \\*/" { in_widget_release=1 }
    
    (in_widget_debug || in_widget_release) && /MARKETING_VERSION = / {
        sub(/MARKETING_VERSION = [^;]+;/, "MARKETING_VERSION = " marketing ";")
    }
    
    (in_widget_debug || in_widget_release) && /CURRENT_PROJECT_VERSION = / {
        sub(/CURRENT_PROJECT_VERSION = [^;]+;/, "CURRENT_PROJECT_VERSION = " build ";")
    }
    
    /^[ \t]*};$/ && (in_widget_debug || in_widget_release) {
        in_widget_debug=0
        in_widget_release=0
    }
    
    { print }
' "$PROJECT_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$PROJECT_FILE"

echo "✅ Widget Extension versions synchronized successfully"
echo ""
echo "Sync complete!"


