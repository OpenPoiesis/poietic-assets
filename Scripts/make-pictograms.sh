#!/bin/sh
#
# Tool to extract pictograms from SVG files into a pictogram catalog.
#
# Usage:
#     make-pictograms SVG_DIRECTORY [OUTPUT]
#
# SVG_DIRECTORY: Directory that contains SVG files with pictogram definition.
# OUTPUT: Name of output file for the pictogram catalog. Default: pictograms.json
#
# Documentation of pictogram SVG format:
#
#     https://github.com/OpenPoiesis/poietic-diagram
#
# TODO: Replace this whole script with 'pictogram' tool command (to be created).

set -eu
die() { printf 'make-pictograms: %s\n' "$*" >&2; exit 1; }

if ! command -v pictogram &> /dev/null
then
    echo "ERROR: Command 'pictogram' not found." 1>&2
    echo "HINT: Follow the installation instructions in the PoieticDiagram package" 1>&2
    echo "HINT: Get the tool at https://github.com/OpenPoiesis/poietic-diagram" 1>&2
    echo "HINT: Make sure you have '~/.swiftpm/bin' in your PATH." 1>&2
    exit 1
fi

usage() {
    cat <<'EOF'
Create pictogram collection from a directory of pictogram SVG images.
    
    make-pictograms.sh [--out RESULT_FILE] [--preview PREVIEW_FILE] SOURCE
        
OPTIONS

    --out RESULT_FILE         Collection file to write to. Default: pictograms.json
    --preview PREVIEW_FILE    SVG file to write pictogram catalog preview into
    SOURCE                    Directory with pictogram SVG images

EOF
}

# Parse Arguments
# ----------------------------------------------------------------

RESULT_FILE="pictograms.json"
PREVIEW_FILE=

while [ $# -gt 0 ]; do
    case "$1" in
        --out)      RESULT_FILE="$2"; shift 2 ;;
        --preview)  PREVIEW_FILE="$2"; shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        *)          break ;;
    esac
done


TMP_DIR=$(mktemp -d /tmp/pictogram-XXXXXX)


if [ $# -eq 1 ]; then
    SOURCE_PATH="$1"
    shift
else
    die "ERROR: Directory which contains a collection of SVG files with pictograms is not specified"
fi

[ $# -eq 0 ] || die "ERROR: Too many arguments"

# Extract
# ----------------------------------------------------------------

echo "Extracting pictograms from: ${SOURCE_PATH}"

pictogram_files=()

for svgfile in ${SOURCE_PATH}/*.svg
do
    base=`basename $svgfile`
    picto_name=${base%*.svg}
    pictogram_files+=(${picto_name}.json)
    echo "    ${picto_name}"
    pictogram extract -o ${TMP_DIR}/${picto_name}.json ${svgfile}
done

echo "Creating pictogram collection: ${RESULT_FILE}"
pictogram collect --pretty -o ${RESULT_FILE} ${pictogram_files/#/${TMP_DIR}\/}

if [ -n "$PREVIEW_FILE" ]; then
    pictogram catalog -o "$PREVIEW_FILE" ${pictogram_files/#/${TMP_DIR}\/}
fi

rm ${TMP_DIR}/*.json
rmdir ${TMP_DIR}


