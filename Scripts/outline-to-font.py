#!/usr/bin/env python3
"""Build the icon font from a directory of outline SVGs and a manifest.

    outline-to-font.py <icons-directory> <manifest.json> <output.ttf>

- **INPUT**: Directory with SVG files created by Scripts/make-icon-outline.sh.
- **OUTPUT**: Font file.

Input requirements (produced by the script):

- one or more `<path>` elements per file, no other kinds of strokes
- absolute path data, no transform
- paths are treated as a bare list of closed contours


## Manifest

The manifest supplies the family name and one entry per icon.  Its "name" is
both the SVG file stem and the PostScript glyph name written to the font's
`post` table, so a glyph can still be found by name after its codepoint has
been looked up.

All of the geometry is fontTools pens:

    parse_path          SVG path data -> pen calls
      TransformPen      SVG user space -> em square (the y flip)
        Cu2QuPen        cubic Bezier -> quadratic
          TTGlyphPen    the glyph outline
"""

# NOTE: File created with assistance of LLM. Verified by human.

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any, NoReturn, Sequence

from fontTools.fontBuilder import FontBuilder # type: ignore
from fontTools.misc.timeTools import timestampSinceEpoch # type: ignore
from fontTools.misc.transform import Transform # type: ignore
from fontTools.pens.cu2quPen import Cu2QuPen # type: ignore
from fontTools.pens.transformPen import TransformPen # type: ignore
from fontTools.pens.ttGlyphPen import TTGlyphPen # type: ignore
from fontTools.svgLib.path import parse_path # type: ignore
from fontTools.ttLib.tables._g_l_y_f import Glyph # type: ignore

SVG_NAMESPACE = "http://www.w3.org/2000/svg"

STYLE_NAME = "Regular"
FALLBACK_FAMILY_NAME = "Poietic Icons"
UNITS_PER_EM = 1000
ADVANCE_WIDTH = UNITS_PER_EM
TYPO_ASCENDER = 1100          # the design box 0..1000 sits centred in a 1200-unit line box
TYPO_DESCENDER = -100
USE_TYPO_METRICS = 0x80
REGULAR = 0x40

QUADRATIC_ERROR = 0.5         # largest cubic->quadratic error, in font units (0.05% of the em)
# head.created from the clock would make every build differ byte for byte.
# timestampNow() would honour SOURCE_DATE_EPOCH instead; a constant is stabler here.
FIXED_TIMESTAMP = timestampSinceEpoch(1_700_000_000)   # 2023-11-14, in fontTools' 1904 epoch

# Path commands that carry relative coordinates.  "z" is deliberately absent:
# closepath has no coordinates to be relative about.
RELATIVE_COMMANDS = frozenset("mlhvcsqta")


def fail(message: str) -> NoReturn:
    """Report a problem and stop, before anything has been written."""
    raise SystemExit(f"outline-to-font: {message}")


def parse_codepoint(text: str) -> int:
    digits = text.strip().removeprefix("U+").removeprefix("u+")
    try:
        value = int(digits, 16)
    except ValueError:
        fail(f"codepoint {text!r} is not hexadecimal")
    if not 0 <= value <= 0x10FFFF:
        fail(f"codepoint {text!r} is outside the Unicode range")
    return value


def read_manifest(manifest_path: Path) -> dict[str, Any]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except OSError as error:
        fail(f"{manifest_path}: {error.strerror}")
    except json.JSONDecodeError as error:
        fail(f"{manifest_path}: not valid JSON ({error})")
    if not isinstance(manifest, dict):
        fail(f"{manifest_path}: the manifest is not a JSON object")
    return manifest

def validate_codepoint(codepoint: str) -> bool:
    """Validate whether a string is a codepoint with format 'U+XXXX'"""
    return isinstance(codepoint, str) and codepoint.upper().startswith('U+')

def is_continuous(codepoints: list[str]) -> bool:
    """
    Return True if the given Unicode codepoints form a continuous run
    with no gaps. Order is ignored.
    """
    if not codepoints:
        return True

    values = [int(cp.removeprefix("U+"), 16) for cp in codepoints]
    values.sort()

    return all(b - a == 1 for a, b in zip(values, values[1:]))

def kebab_to_camel(s: str) -> str:
    """
    Convert a kebab-case string to CamelCase (UpperCamelCase).
    """
    return "".join(part.capitalize() for part in s.split("-") if part)

def validate_manifest(manifest: dict[str, Any]) -> bool:
    """Validate the manifest.  Return False to stop before anything is built.

    Not implemented -- the caller owns this.  Whatever else it checks, the font
    cannot be built without all of the following holding, and each of them
    produces a broken or silently wrong font rather than an error:

      * every entry in "icons" has a "name", unique across the manifest; it
        becomes the PostScript glyph name in the font's `post` table, and it
        also has to match the SVG file stem
      * every entry has a "codepoint", parseable as hexadecimal (with or
        without a U+ prefix) and unique across the manifest
      * every entry corresponds to an SVG file in the icons directory
    """
    errors: list[str] = []
    seen_names: list[str] = []
    seen_codepoints : list[str] = []
    index: int = -1
    
    first_codepoint = manifest.get("first_codepoint")
    if first_codepoint is None:
        raise SystemExit("Missing first_codepoint key in the manifest")

    if not validate_codepoint(first_codepoint):
        raise SystemExit("First code point is not in form U+XXXX")


    icon_infos: Any = manifest.get("icons")
    if icon_infos is None:
        raise SystemExit("Manifest is missing icon list")

    for info in icon_infos:
        index += 1

        if "name" not in info:
            errors.append(f"Icon at {index} is missing name")
            continue
        name = info.get("name")
        if name in seen_names:
            errors.append(f"Duplicate icon name '{name}' at index {index}")
            continue
        seen_names.append(name)
        
        if "codepoint" not in info:
            errors.append(f"Icon '{name}' at {index} is missing codepoint")
            continue
        codepoint = info.get("codepoint")
        
        if codepoint in seen_codepoints:
            errors.append(f"Duplicate codepoint {codepoint} for icon '{name}' at index {index}")
            continue
            
        if not validate_codepoint(codepoint):
            errors.append(f"Invalid codepoint {codepoint} for icon '{name}' at index {index}")
            continue

        seen_codepoints.append(codepoint)

    if not is_continuous(seen_codepoints):
        errors.append(f"Codepoints are not continuous without gaps")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit("Manifest contains errors")

    return True


def canvas_transform(root: ElementTree.Element) -> Transform:
    """The SVG user space -> em square transform.

    The canvas is required to be square and exactly one em, which is the
    documented design rule (1 design unit = 1 font unit).  That leaves a pure
    y flip, so there is no scaling arithmetic anywhere in this script.
    """
    view_box = root.get("viewBox")
    if view_box is None:
        fail("the <svg> has no viewBox")
    numbers = [float(number) for number in re.split(r"[\s,]+", view_box.strip())]
    if len(numbers) != 4:
        fail(f"unusable viewBox {view_box!r}")
    min_x, min_y, width, height = numbers
    if width != UNITS_PER_EM or height != UNITS_PER_EM:
        fail(f"canvas is {width:g}x{height:g}, expected {UNITS_PER_EM}x{UNITS_PER_EM}: "
             "this script flips the canvas into the em square, it does not scale it")
    return Transform(1, 0, 0, -1, -min_x, min_y + height)


def read_path_data(svg_path: Path) -> tuple[list[str], Transform]:
    """Check that the file is the kind of SVG this script claims to handle, and
    return its path data together with the canvas transform."""
    try:
        root = ElementTree.parse(svg_path).getroot()
    except ElementTree.ParseError as error:
        fail(f"{svg_path}: not well-formed XML ({error})")
    if root.tag != f"{{{SVG_NAMESPACE}}}svg":
        fail(f"{svg_path}: the root element is not <svg>")

    for element in root.iter():
        if element.get("transform"):
            fail(f"{svg_path}: <{element.tag.split('}')[-1]}> carries a transform; "
                 "run Scripts/icon-outline.sh first -- this script does not compose transforms")

    path_data = [element.get("d", "") for element in root.iter(f"{{{SVG_NAMESPACE}}}path")]
    if not path_data:
        fail(f"{svg_path}: no <path> element")
    for d in path_data:
        if not d.strip():
            fail(f"{svg_path}: a <path> has an empty d attribute")
        relative = RELATIVE_COMMANDS.intersection(d)
        if relative:
            fail(f"{svg_path}: path data is relative ('{' '.join(sorted(relative))}'), not absolute; "
                 "run Scripts/icon-outline.sh first")
    return path_data, canvas_transform(root)


def build_glyph(path_data: Sequence[str], to_em: Transform) -> Glyph:
    """Draw every path of one icon through one pen stack."""
    glyph_pen = TTGlyphPen(None)
    quadratic_pen = Cu2QuPen(glyph_pen, QUADRATIC_ERROR, all_quadratic=True)
    em_pen = TransformPen(quadratic_pen, to_em)
    for d in path_data:
        parse_path(d, em_pen)
    glyph = glyph_pen.glyph()
    glyph.recalcBounds(None)      # xMin/yMin/xMax/yMax, rounded as the compiler will round them
    return glyph


def warn_if_ink_escapes(glyph_name: str, glyph: Glyph) -> None:
    """The canvas is the em box, so ink outside it is a drawing mistake.  The
    bounds are the glyf header bounds, which include control points, so this is
    the conservative test -- exactly what a rasteriser will use."""
    if glyph.xMin < 0 or glyph.yMin < 0 or glyph.xMax > ADVANCE_WIDTH or glyph.yMax > UNITS_PER_EM:
        print(f"outline-to-font: {glyph_name}: the ink leaves the em box (0..{UNITS_PER_EM}); "
              "it will be clipped or overlap its neighbours", file=sys.stderr)


def build_font(glyphs: dict[str, Glyph], codepoints: dict[str, int],
               family_name: str) -> FontBuilder:
    """Assemble the tables.  FontBuilder does the table work; we supply only the
    decisions a font cannot make for itself."""
    font_builder = FontBuilder(UNITS_PER_EM, isTTF=True)
    font_builder.setupGlyphOrder([".notdef", *glyphs])
    font_builder.setupCharacterMap({codepoints[name]: name for name in glyphs})
    font_builder.setupGlyf({".notdef": TTGlyphPen(None).glyph(), **glyphs})
    font_builder.setupHorizontalMetrics({
        ".notdef": (ADVANCE_WIDTH, 0),
        # the left side bearing has to equal xMin: consumers that honour it would
        # otherwise draw the outline somewhere other than the bounding box says
        **{name: (ADVANCE_WIDTH, glyph.xMin) for name, glyph in glyphs.items()},
    })
    font_builder.setupHorizontalHeader(ascent=TYPO_ASCENDER, descent=TYPO_DESCENDER)
    font_builder.setupNameTable({"familyName": family_name, "styleName": STYLE_NAME})
    font_builder.setupOS2(
        version=4,                # fsSelection bit 7 (USE_TYPO_METRICS) needs OS/2 v4
        sTypoAscender=TYPO_ASCENDER,
        sTypoDescender=TYPO_DESCENDER,
        sTypoLineGap=0,
        usWinAscent=TYPO_ASCENDER,
        usWinDescent=-TYPO_DESCENDER,
        fsSelection=USE_TYPO_METRICS | REGULAR,
    )
    font_builder.setupPost()      # format 2.0: this is what carries the glyph names
    head = font_builder.font["head"]
    head.created = head.modified = FIXED_TIMESTAMP
    return font_builder


def collect_glyphs(icons_directory: Path, manifest_path: Path,
                   manifest: dict[str, Any]) -> tuple[dict[str, Glyph], dict[str, int]]:
    """One glyph per SVG in the directory, looked up in the manifest by file stem."""
    entries = manifest.get("icons")
    if not isinstance(entries, list):
        fail(f"{manifest_path}: no 'icons' list")
    by_name = {entry.get("name"): entry for entry in entries if isinstance(entry, dict)}

    svg_paths = sorted(icons_directory.glob("*.svg"))
    if not svg_paths:
        fail(f"{icons_directory}: no .svg files")

    glyphs: dict[str, Glyph] = {}
    codepoints: dict[str, int] = {}
    for svg_path in svg_paths:
        glyph_name = svg_path.stem
        entry = by_name.get(glyph_name)
        if entry is None:
            fail(f"{svg_path}: no '{glyph_name}' entry in {manifest_path}")
        if not entry.get("codepoint"):
            fail(f"{svg_path}: the '{glyph_name}' entry has no codepoint")

        path_data, to_em = read_path_data(svg_path)
        glyph = build_glyph(path_data, to_em)
        warn_if_ink_escapes(glyph_name, glyph)
        glyphs[glyph_name] = glyph
        codepoints[glyph_name] = parse_codepoint(str(entry["codepoint"]))
    return glyphs, codepoints


def report(icons_directory: Path, manifest_path: Path, font_path: Path,
           glyphs: dict[str, Glyph], codepoints: dict[str, int], family_name: str) -> None:
    print(f"{icons_directory} + {manifest_path} -> {font_path}")
    print(f"  family      {family_name}")
    print(f"  glyphs      {len(glyphs)} + .notdef")
    print(f"  codepoints  U+{min(codepoints.values()):04X}..U+{max(codepoints.values()):04X}")
    print(f"  size        {font_path.stat().st_size} bytes")
    print()
    for glyph_name, glyph in glyphs.items():
        print(f"  {glyph_name:<16s} U+{codepoints[glyph_name]:04X}  "
              f"{glyph.numberOfContours:2d} contour(s)  "
              f"x {glyph.xMin:4d}..{glyph.xMax:<4d} y {glyph.yMin:4d}..{glyph.yMax:<4d}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build the icon font from a directory of outline SVGs and a manifest.")
    parser.add_argument("icons", type=Path, help="directory of outline SVGs")
    parser.add_argument("manifest", type=Path, help="manifest JSON")
    parser.add_argument("font", type=Path, help="font file to write")
    arguments = parser.parse_args()

    if not arguments.icons.is_dir():
        fail(f"{arguments.icons}: not a directory")

    manifest = read_manifest(arguments.manifest)
    if not validate_manifest(manifest):
        fail(f"{arguments.manifest}: the manifest did not validate")
    family_name = manifest.get("family") or FALLBACK_FAMILY_NAME

    glyphs, codepoints = collect_glyphs(arguments.icons, arguments.manifest, manifest)
    font_builder = build_font(glyphs, codepoints, family_name)

    font_builder.save(arguments.font)
    report(arguments.icons, arguments.manifest, arguments.font,
           glyphs, codepoints, family_name)


if __name__ == "__main__":
    main()
