# Icon sources

The design sources for the application's UI icons. These are **not** shipped: the
application ships a font built from them.

    Assets/Icons/
        README.md           this file: the design rules
        manifest.json       icon -> codepoint -> IconKey case
        *.svg               one icon per file

    Scripts/build-icon-font.py      generates the font and the Swift table

Generated, and committed:

    Sources/PoieticPlayground/Resources/fonts/poietic-icons.ttf
    Sources/PoieticPlayground/Application/IconKey+Codepoints.swift

A normal build needs none of this: it needs only the two generated files above.
The script needs `fontTools`, and is run by hand when the icon set changes:

    python3 Scripts/build-icon-font.py build            # regenerate
    python3 Scripts/build-icon-font.py build --check    # validate only, write nothing

`--check` fails on every way the set can drift: an icon with no codepoint, a duplicated
codepoint, a duplicated name, a missing file, disagreement with the `IconKey`
enumeration in either direction, artwork a glyph cannot carry, and artwork that does not
sit inside its canvas. Run it before committing an icon change.

The script also carries an `extract` subcommand, which split the original single-file
atlas into these per-icon files. It is **temporary**: once the icons here have been
reviewed and are being edited directly, both the subcommand and the "TEMPORARY: atlas
extraction" section it lives in should be deleted. It is not part of the workflow.


## Adding or changing an icon

1. Draw it in Inkscape using the template below.
2. Save it as `Assets/Icons/<name>.svg`, where `<name>` is the `IconKey` case in
   kebab-case (`arrowComment` → `arrow-comment.svg`).
3. Add an entry to `manifest.json` with an unused codepoint. Codepoints are assigned
   explicitly and are **never reassigned** — the manifest is append-only in that sense,
   so a reordering cannot silently change what a codepoint means.
4. Run `Scripts/build-icon-font.py`, then build the app.

## Design rules

### Canvas and boxes

The design canvas is **1000 × 1000**, which is exactly 1 font unit per design unit:
1 design unit is 1 font unit and the em is 1000, so there is no conversion factor to
remember anywhere. Every number below is therefore both a drawing measurement and a
font measurement.

| box | extent | meaning |
|---|---|---|
| canvas | 0 … 1000 | the whole file, the em box |
| content box | 100 … 900 | where the centre lines are fitted |
| ink box | 68 … 932 | where the ink actually lands once stroked |

Draw your centre lines inside the content box; the 64-unit stroke then adds 32 units on
each side, so the ink finishes 68 units from the canvas edge — **6.8 % padding**. That
is inside the documented band, which runs from 6.25 % (IBM Carbon, 2 px on a 32 px grid)
through 8.33 % (Material, 2 dp on a 24 dp grid) to 12.5 % (Fluent, measured). Padding is
measured from the *ink*, not from the nominal box, because ink is what a reader sees —
but pad the *box*, not each icon: a deliberately wide icon should fill the content box
and let its ink sit closer to the edge, and both Material and Carbon explicitly allow
that for optical weight.

Icons are centred on the canvas by their ink, and scaled uniformly, so aspect ratio is
preserved and a wide icon is not stretched to fill a square.

### Stroke

All icons use one stroke weight: **64 units**, i.e. 6.4 % of the canvas, or 8 % of the
content box. One weight across the whole family is what makes a set look like a set; it
is also what stops a large icon reading heavier than a small one.

Set it on the stroke, not per shape:

    stroke-width: 64
    stroke-linecap: round
    stroke-linejoin: round

Two documented house styles exist and either is defensible: **8.33 %** (Lucide, Feather,
Tabler, Material's 2/24) and **6.25 %** (Heroicons, IBM Carbon's 2/32, Phosphor).
64 units sits at the lighter of the two, which is also what the original artwork was
drawn at — a 6-unit stroke against a 128-unit box is 4.7 %. 64 units also lands on
whole pixels at 16 px (1.0 px) and 24 px (1.5 px), where 80 units would be 1.28 px and
1.92 px and would blur slightly at the small size. If the set ever reads too light,
`STROKE` in `Scripts/build-icon-font.py` is the single value to change.

### Corner radius

Rounded on the outside, square on the inside — the house style of both Material and
Carbon:

- **Outer corners of a silhouette: 80 units** where the shape is large enough. Since
  the font stores baked outlines, the drawn radius is exactly what you set. (If you
  author with a live stroke, the visual outer radius is the path radius plus half the
  stroke: use 48 units of path radius with the 64-unit stroke to get the same result.)
- **Interior corners stay square.** Rounding an inside corner of a 64-unit stroke is
  not distinguishable from the stroke's own join, so it only adds noise.
- **Never round below 32 units** — that is ½ stroke, the point at which a radius
  becomes indistinguishable from the join.
- **Ladder: 32 / 64 / 160**, doubling, so radii relate to each other deliberately
  rather than being chosen one icon at a time.
- **Do not round a stroke.** Shapes 64 units wide or less — a chevron's spine, a tick,
  a divider — get their rounding from `stroke-linecap` and `stroke-linejoin` only.
- **Stroke terminals are fully round**, radius = ½ stroke = 32 units; `linecap: round`
  does this for you. Carbon makes an exception and uses square caps; we do not, because
  the round cap is what the stroke expansion implements exactly.

Where two straight lines meet at a shallow angle — the point of a chevron, an arrow
head — round the join and leave the tip alone.

### Keylines and optical centring

Material's keyline set is the reference for how much room a shape of a given kind
should take inside the content box, because a circle looks smaller than a square of the
same size. On our 800-unit content box:

| shape | size |
|---|---|
| square | 720 × 720 |
| circle | Ø 800 |
| horizontal rectangle | 800 × 640 |
| vertical rectangle | 640 × 800 |

Round shapes get the full box; square and rectangular shapes are inset about 10 %,
which is what makes them read as the same weight. The build script centres every icon by
its own ink and scales it uniformly, so these keylines are guidance for the drawing, not
something the generator enforces.

Keep at least **80 units** between two separate elements of an icon, or they will merge
at small sizes.

### Vertical metrics

The glyphs are drawn in a design box of 0…1000 above the baseline. The font declares:

| metric | value |
|---|---|
| units per em | 1000 |
| hhea / sTypo ascender | 1100 |
| hhea / sTypo descender | −100 |
| line gap | 0 |
| winAscent / winDescent | 1010 / 110 |
| fsSelection | USE_TYPO_METRICS (bit 7) |

The design box is therefore **centred in the line box**, with 100 units above and below
it — the pattern Material Symbols uses (a 960 design box centred in a 1152 line box).
Most icon fonts do not bother: Lucide is 1000/0, Font Awesome 459/−75, Phosphor
960/−64. Centring is worth it here because the caller then only has to position the
line and the glyph is already optically centred in it.

### Allowed artwork

Draw only what a font can carry. The canvas may contain:

- `<path>`, and the primitives `rect`, `circle`, `ellipse`, `line`, `polygon`, `polyline`
- strokes and fills
- `stroke-linecap="round"` and `stroke-linejoin="round"`; arcs and Bézier curves

and nothing else. In particular, **no** text, no raster images (`<image>`), no
gradients or patterns, no filters, no masks or clipping paths, no `stroke-dasharray`,
no `<use>`, `<symbol>` or `<marker>`, and no embedded CSS. These all have no equivalent
in a monochrome glyph, and each fails silently — the icon simply renders wrong.

Keep the structure flat: one `<g id="<name>">` at the root and shapes inside it. Nested
groups are permitted but each nested `transform` is one more chance to be applied twice
by some tool in the chain. Prefer a single transform on the root group, or none at all.

### Monochrome

Icons are drawn in a single colour and coloured at draw time by the interface style, so
do not bake colour in: use `stroke:black` (or no colour attribute) and let the
application tint it. There is one file per icon, not one per colour.

## Why strokes are allowed in the source

The sources are a stroked wire frame; a glyph is a filled outline. The build script
expands the stroke itself — each flattened segment contributes a quad at half width and
each vertex a disc, whose union under the non-zero winding rule is exactly the
round-joined, round-capped stroke. That is why the rules above insist on round caps and
joins: they are the case the expansion implements exactly.

The expansion fits the *centre lines* to the content box before stroking, so the
stroke-to-size ratio is the same for every icon. Fitting the expanded outline instead
would make a wide icon come out with a visibly thinner line than a square one.

## Not in the application repository

`poietic-assets` holds the pictogram sources, which are canvas artwork for the
diagramming notation and an unrelated concern. UI icons live here, with the code that
uses them, so that an icon change and the `IconKey` it must match are reviewed together.
