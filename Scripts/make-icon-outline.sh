#!/bin/sh
# make-icon-outline.sh - Convert an icon SVG with strokes into an outline suitable for a font glyph.
#
#   Output of this script is further processed by outline-to-font.py script.
#
#   INPUT: SVG - stroked centre lines of shapes (rect/circle/ellipse/line/polygon/polyline/path),
#                can contain groups and transforms.
#   OUTPUT: Single <path>, absolute coordinates (no transforms), stroke expanded to a fill,
#           union shapes, appropriated winding.
#
# The Inkscape actions performed:
#   select-all:ALL        selects all with groups too; plain select-all would leave the
#                         top-level <g> alone and then nothing would happen
#   object-to-path        rect/circle/ellipse/line/polygon/polyline -> <path>
#   object-stroke-to-path converts stroke to filled outline
#   path-union            boolean union into one path, normalised winding
set -eu

INKSCAPE=${INKSCAPE:-inkscape}
INPUT=${1:-}
OUTPUT=${2:-}

die() { printf 'make-icon-outline: %s\n' "$*" >&2; exit 1; }
[ -n "$INPUT" ] && [ -n "$OUTPUT" ] || die "usage: $0 <input.svg> <output.svg>"
[ "$INPUT" != "$OUTPUT" ] || die "input and output are the same file"
command -v "$INKSCAPE" >/dev/null || die "inkscape not found (set INKSCAPE=...)"

[ -s "$INPUT" ] || die "$INPUT: missing or empty"

rm -f "$OUTPUT"

# Inkscape Actions
# ----------------------------------------------------------------
"$INKSCAPE" "$INPUT" --export-overwrite --actions="select-all:all;\
object-to-path;\
selection-ungroup;\
selection-ungroup;\
selection-ungroup;\
object-stroke-to-path;\
path-union;\
export-filename:$OUTPUT;\
export-plain-svg;\
export-do" >/dev/null 2>&1

# Output
# ----------------------------------------------------------------
[ -s "$OUTPUT" ] || die "$INPUT: inkscape produced no output (bad input?)"

echo "Created $OUTPUT"
