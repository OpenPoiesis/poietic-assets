#!/bin/sh
# make-pictograms.sh - Extract pictograms from SVG files into a pictogram catalog.
#
#   INPUT:  Directory with SVG files, one pictogram per file. The pictogram
#           name is the file name without the `.svg` extension.
#   OUTPUT: Pictogram collection file, optionally accompanied by an SVG
#           catalog preview of that collection.
#
#   Documentation of the pictogram SVG format:
#
#       https://github.com/OpenPoiesis/poietic-diagram
#
# TODO: Replace this whole script with 'pictogram' tool command (to be created).
set -eu

SCRIPT_NAME=${0##*/}

die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

if ! command -v pictogram >/dev/null 2>&1; then
    cat >&2 <<EOF
$SCRIPT_NAME: command 'pictogram' not found
HINT: Follow the installation instructions in the PoieticDiagram package
HINT: Get the tool at https://github.com/OpenPoiesis/poietic-diagram
HINT: Make sure you have '~/.swiftpm/bin' in your PATH.
EOF
    exit 1
fi

# Help
# ----------------------------------------------------------------

usage() {
    cat <<'EOF'
Create a pictogram collection from a directory of pictogram SVG images.

    make-pictograms.sh [--out RESULT_FILE] [--preview PREVIEW_FILE] SOURCE

OPTIONS

    --out RESULT_FILE        File to write the pictogram collection into.
                             Default: pictograms.json
    --preview PREVIEW_FILE   SVG file to write a catalog preview of the
                             pictogram collection into.
    -h, --help               This message.

ARGUMENTS

    SOURCE                   Directory with pictogram SVG images.

EOF
}

# Parse Arguments
# ----------------------------------------------------------------

RESULT_FILE="pictograms.json"
PREVIEW_FILE=

while [ $# -gt 0 ]; do
    case "$1" in
        --out)      [ $# -ge 2 ] || die "--out needs a file name"
                    RESULT_FILE="$2"; shift 2 ;;
        --preview)  [ $# -ge 2 ] || die "--preview needs a file name"
                    PREVIEW_FILE="$2"; shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        -*)         die "unknown option: $1 (try --help)" ;;
        *)          break ;;
    esac
done

[ $# -ge 1 ] || die "no source directory given (try --help)"
[ $# -le 1 ] || die "unexpected argument: $2 (try --help)"

SOURCE_PATH="$1"

[ -d "$SOURCE_PATH" ] || die "$SOURCE_PATH: no such directory"

# Extract
# ----------------------------------------------------------------

TMP_DIR=$(mktemp -d /tmp/pictogram-XXXXXX)

cleanup() {
    rm -f "$TMP_DIR"/*.json
    rmdir "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "Extracting pictograms from: $SOURCE_PATH"

for svgfile in "$SOURCE_PATH"/*.svg; do
    [ -e "$svgfile" ] || die "no SVG files found in: $SOURCE_PATH"

    svg_name=$(basename "$svgfile")
    picto_name=${svg_name%.svg}
    json_file="$TMP_DIR/$picto_name.json"

    echo "    $picto_name"
    pictogram extract -o "$json_file" "$svgfile"
done

# Collect
# ----------------------------------------------------------------

# The temporary directory contains exactly the pictograms extracted above.
echo "Creating pictogram collection: $RESULT_FILE"
pictogram collect --pretty -o "$RESULT_FILE" "$TMP_DIR"/*.json

if [ -n "$PREVIEW_FILE" ]; then
    echo "Creating catalog preview: $PREVIEW_FILE"
    pictogram catalog -o "$PREVIEW_FILE" "$TMP_DIR"/*.json
fi
