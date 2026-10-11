#!/bin/sh
#  build-dist.sh – Build the distribution resources package.
#
#  Created by Stefan Urbanek on 09/10/2026.
#
set -eu

SCRIPTS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

DIST_DIR=${DIST_DIR:-dist/}
ASSETS_DIR=${ASSETS_DIR:-.}

# Parse Arguments
# ----------------------------------------------------------------

usage() {
    cat <<'EOF'
Create a distribution directory of poietic-assets for poietic-playground application.
    
    build-dist.sh [--assets ASSETS_DIR] [--dist DIST_DIR]
        
OPTIONS

    --assets ASSETS_DIR   Directory with assets. Default: ./
    --dist DIST_DIR       Directory to which generate and copy output. Default: ./dist

REQUIREMENTS

The script requires inkscape, python and python package fontTools.

EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --assets)   ASSETS_DIR="$2"; shift 2 ;;
        --dist)     DIST_DIR="$2"; shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        *)          break ;;
    esac
done

[ $# -eq 0 ] || die "ERROR: Too many arguments"

# Main
# ----------------------------------------------------------------

echo "== Creating dist directory structure in $DIST_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"/fonts
mkdir -p "$DIST_DIR"/notations

# echo "== Building notations"
# TODO: Build notations here

echo "== Copying fonts"
cp "$ASSETS_DIR"/Fonts/* "$DIST_DIR"/fonts

echo "== Building icon font"
"$SCRIPTS"/make-icon-font.sh
