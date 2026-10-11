#!/bin/sh
#  make-icon-font.sh – Create an icon font from poietic-assets icons.
#  Usage:
#
#      make-icon-font.sh [--validate] [--icons ICONS_DIR] [--manifest MANIFEST_FILE] [FONT_FILE]
#
#  Variables to override:
#
#      SOURCE_ICONS: Path to source icons (single-stroke). Default: Icons/
#      MANIFEST: Path to icons manifest. Default: SOURCE_ICONS/manifest.json
#      FONT_FILE: File to be generated. Default: dist/fonts/poietic-icons.ttf
#      VALIDATE: Flag whether to run validation (requires xmllint). Default 1.
#
#  Created by Stefan Urbanek on 09/10/2026.
#

set -eu

# Initialise
# ----------------------------------------------------------------

SCRIPTS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON=${PYTHON:-python3}

SOURCE_ICONS=${SOURCE_ICONS:-Icons}
MANIFEST=${MANIFEST:-"$SOURCE_ICONS"/manifest.json}
FONT_FILE=${FONT_FILE:-dist/fonts/poietic-icons.ttf}
VALIDATE=${VALIDATE:-1}

die() { printf 'make-icon-font: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Create icon font from SVG icons.
    
    make-icon-font.sh [--validate] [--icons ICONS_DIR] [--manifest MANIFEST_FILE] [FONT_FILE]
        
OPTIONS

    --icons ICONS_DIR         Directory with SVG images of icons, default: Icons/
    --manifest MANIFEST       Manifest JSON file. Default: ICONS_DIR/manifest.json
    --validate/--no-validate  Validate the output (uses xmllint)
    FONT_FILE                 Output font file. Default: dist/fonts/poietic-icons.ttf

REQUIREMENTS

The script requires inkscape, python and python package fontTools.

EOF
}

# Parse Arguments
# ----------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --icons)    SOURCE_ICONS="$2"; shift 2 ;;
        --manifest) MANIFEST="$2"; shift 2 ;;
        --validate) VALIDATE=1; shift ;;
        --no-validate) VALIDATE=0; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          break ;;
    esac
done

if [ $# -gt 0 ]; then
    FONT_FILE="$1"
    shift
fi

[ $# -eq 0 ] || die "ERROR: Too many arguments"

# Initial checks
# ----------------------------------------------------------------

"$PYTHON" -c 'import fontTools' 2>/dev/null \
    || die "$PYTHON has no fontTools -- activate your environment with fontTools package installed"


[ -d "$SOURCE_ICONS" ] || die "Source icons path not found"
[ -f "$MANIFEST" ] || die "Manifest ${MANIFEST} not found"

# Create outlines
# ----------------------------------------------------------------

OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/poietic-assets-icons.XXXXXX")

for icon in "$SOURCE_ICONS"/*.svg; do
    name=$(basename $icon)
    echo "== Creating outline for $name"
    "$SCRIPTS/make-icon-outline.sh" $icon "$OUTPUT_DIR"/$name > /dev/null

    if [ "$VALIDATE" = 1 ]; then
        "$SCRIPTS/validate-icon-outline.sh" "$OUTPUT_DIR"/$name
    fi
done

# Create font
# ----------------------------------------------------------------

mkdir -p "$(dirname "$FONT_FILE")"

echo "== Creating font"
"$PYTHON" "$SCRIPTS/outline-to-font.py" "$OUTPUT_DIR" "$MANIFEST" "$FONT_FILE"

echo "== Font created: $FONT_FILE"
