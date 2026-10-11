#!/bin/sh
# validate-icon-outline.sh - Validate generated icon outlines
#
set -eu

OUTLINE=${1:-}

die() { printf 'validate-icon-outline: %s\n' "$*" >&2; exit 1; }

[ -n "$OUTLINE" ] || die "usage: $0 <outline.svg>"
command -v "xmllint" >/dev/null || die "xmllint not found"

# Validation

[ -s "$OUTLINE" ] || die "$OUTLINE: no outline file found"

[ "$(xmllint --xpath 'count(//@transform)' "$OUTLINE")" = 0 ] \
    || die "$OUTLINE: a transform survived -- raise the number of selection-ungroup steps"

n_paths=$(xmllint --xpath 'count(/*[local-name()="svg"]/*[local-name()="path"])' "$OUTLINE")
n_kids=$(xmllint  --xpath 'count(/*[local-name()="svg"]/*)' "$OUTLINE")
n_inert=$(xmllint --xpath 'count(/*[local-name()="svg"]/*[local-name()="defs" or local-name()="title" or local-name()="desc" or local-name()="metadata"])' "$OUTLINE")
[ "$n_paths" = 1 ]                       || die "$OUTLINE: expected exactly 1 <path> under <svg>, got $n_paths"
[ "$n_paths" = "$((n_kids - n_inert))" ] || die "$OUTLINE: <svg> has a child that is not <path>"
[ "$(xmllint --xpath 'count(//*[local-name()="path"][contains(@style,"stroke-width")])' "$OUTLINE")" = 0 ] \
    || die "$OUTLINE: a stroke-width survived -- the stroke was not expanded"

d=$(xmllint --xpath 'string(/*[local-name()="svg"]/*[local-name()="path"]/@d)' "$OUTLINE")
[ -n "$d" ] || die "$OUTLINE: the path has no d"
contours=$(printf '%s' "$d" | tr -cd 'Mm' | wc -c | tr -d ' ')

name=$(basename "$OUTLINE")
echo "Outline $name is valid. Contours: $contours"
