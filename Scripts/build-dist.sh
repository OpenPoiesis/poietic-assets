#!/bin/sh
#  build-dist.sh – Build the distribution resources package.
#
#  Created by Stefan Urbanek on 09/10/2026.
#
#  The script produces:
#
#      DIST_DIR/
#          contents/                          resources for the application
#              fonts/                         Fonts/ + built icon font
#              notations/                     notation catalogues
#          poietic-assets-VERSION.tar.gz      the release archive of contents/
#
#  `contents/` directory mirrors application's Resources/ directory.
#
#  REQUIREMENTS
#
#  - inkscape, python3 with fontTools, xmllint.
#
set -eu

SCRIPT_NAME=${0##*/}

ASSETS_VERSION=${ASSETS_VERSION:-v0.1}

SCRIPTS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Defaults
# ----------------------------------------------------------------

ASSETS_DIR=${ASSETS_DIR:-$(dirname -- "$SCRIPTS")}
DIST_DIR=${DIST_DIR:-}
CONTENTS_DIR=${CONTENTS_DIR:-}
ARCHIVE=${ARCHIVE:-}
NOTICES_DIR=${NOTICES_DIR:-}

die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

# Help
# ----------------------------------------------------------------

usage() {
    cat <<'EOF'
Create a distribution directory of poietic-assets for poietic-playground application and poietic
CLI tool.
    
    build-dist.sh [--assets ASSETS_DIR] [--dist DIST_DIR]
        
OPTIONS

    --assets ASSETS_DIR    Directory with assets. Default: parent of this script.
    --archive ARCHIVE_DIR  File to write archive
                           Default: DIST_DIR/poietic-assets-ASSETS_VERSION.tar.gz
    --dist DIST_DIR        Directory to generate contents and archive in.
                           Default: ASSETS_DIR/dist
    -h, --help             This message.

OUTPUT

    DIST_DIR/contents/                      installed by the application
    DIST_DIR/poietic-assets-VERSION.tar.gz  the release archive

REQUIREMENTS

    inkscape, python3 with fontTools, xmllint. Set PYTHON to the interpreter
    that has fontTools if that is not python3.

EOF
}

# Parse Arguments
# ----------------------------------------------------------------


while [ $# -gt 0 ]; do
    case "$1" in
        --assets)   [ $# -ge 2 ] || die "--assets needs a directory"
                    ASSETS_DIR="$2"; shift 2 ;;
        --archive)  [ $# -ge 2 ] || die "--archive needs a file name"
                    ARCHIVE="$2"; shift 2 ;;
        --dist)     [ $# -ge 2 ] || die "--dist needs a directory"
                    DIST_DIR="$2"; shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        -*)         die "unknown option: $1 (try --help)" ;;
        *)          die "unexpected argument: $1 (try --help)" ;;
    esac
done

# Set-up Paths
# ----------------------------------------------------------------

[ -d "$ASSETS_DIR" ] || die "$ASSETS_DIR: no such directory"
ASSETS_DIR=$(CDPATH= cd -- "$ASSETS_DIR" && pwd)

DIST_DIR="${DIST_DIR:-$ASSETS_DIR/dist}"

case "$DIST_DIR" in
    *[!/]*) ;;
    *)      die "invalid --dist: '$DIST_DIR' is the filesystem root" ;;
esac
DIST_DIR=${DIST_DIR%/}

CONTENTS_DIR="${CONTENTS_DIR:-$DIST_DIR/contents}"
ARCHIVE="${ARCHIVE:-$DIST_DIR/poietic-assets-$ASSETS_VERSION.tar.gz}"
NOTICES_DIR="${NOTICES_DIR:-$ASSETS_DIR/Notices}"

[ -d "$ASSETS_DIR/Fonts" ] || die "$ASSETS_DIR/Fonts: no such directory"
[ -d "$ASSETS_DIR/Icons" ] || die "$ASSETS_DIR/Icons: no such directory"

# Main
# ----------------------------------------------------------------
# Build and Copy Contents

echo "== Creating content in $CONTENTS_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$CONTENTS_DIR"/fonts
mkdir -p "$CONTENTS_DIR"/notations

# Notations
# ------------------------

echo "== Creating notations"

notations="StockFlow-Standard StockFlow-Jolly"

for notation in $notations; do
    echo "Creating notation $notation"
    "$SCRIPTS"/make-pictograms.sh\
        --out "$CONTENTS_DIR/notations/${notation}.json" \
        "$ASSETS_DIR/Pictograms/$notation"
done

# Fonts
# ------------------------

echo "== Copying fonts"
cp "$ASSETS_DIR"/Fonts/* "$CONTENTS_DIR"/fonts

# Icon Font
# ------------------------

echo "== Building icon font"
ICON_FONT="$CONTENTS_DIR/fonts/poietic-icons.ttf"
"$SCRIPTS"/make-icon-font.sh \
    --icons "$ASSETS_DIR/Icons" \
    --manifest "$ASSETS_DIR/Icons/manifest.json" \
    "$CONTENTS_DIR/fonts/poietic-icons.ttf"

[ -s "$ICON_FONT" ] || die "the icon font was not created: $ICON_FONT"


# Package
# ----------------------------------------------------------------

echo "== Creating archive"

tar -zcf "$ARCHIVE" --no-xattrs -C "$(dirname -- "$CONTENTS_DIR")" "$(basename -- "$CONTENTS_DIR")"

# Report
# ----------------------------------------------------------------

archive_bytes=$(wc -c <"$ARCHIVE" | tr -d '[:space:]')
payload_files=$(find "$CONTENTS_DIR" -type f | wc -l | tr -d '[:space:]')

echo "== Done"
echo "   contents: $CONTENTS_DIR ($payload_files files)"
echo "   archive: $ARCHIVE ($archive_bytes bytes)"
