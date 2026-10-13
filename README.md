# Poietic Assets

This repository contains resources for the [OpenPoiesis](https://github.com/openpoiesis/)
project.

Contents:

- `Pictograms`: Sources for diagram pictograms, various styles.
- `Icons`: Sources for icons used in the [Playground application](https://github.com/openpoiesis/poietic-playground)
- `Fonts`: Fonds used by the Playground application

## Building

To build the assets distribution files and archive, needed by other OpenPoiesis packages, run:

```sh
Scripts/build-dist.sh
```

Other scripts:

- `make-icon-font` – create icon font used by the Application from `Icons/`
- `make-pictograms.sh` – create pictogram collections (for notations) from `Pictograms/`

### Requirements

- `pictogram` CLI tool from [poietic-diagram](https://github.com/openpoiesis/poietic-diagram) - for pictogram creation
- [Inkscape](https://inkscape.org) – used without GUI for SVG manipulation for the icon font
- `python3` with [fontTools](https://fonttools.readthedocs.io/en/latest/)
- `xmllint`


## Pictograms

Pictograms are stored as SVG files, one file per pictogram.
The SVG must contain elements (groups) with the following IDs:

- `pictogram` (required) - Pictogram path
    - Can be a `<g>` group element or any direct graphic element, no `<use>`, no `<text>`.
    - All style, such as fill or line, is ignored
    - Path is considered a *stroke/wire*, never a filled shape.
- `collision` (required) - Collision shape
    - Must be either a group `<g>` element or a simple shape element.
    - Allowed shapes: `<circle>`, `<ellipse>` (converted to rectangle), `<rectangle>`,
      `<polygon>`, `<polyline>` (treated as polygon), `<path>` (must contain only line-to elements)
    - Path is considered a *filled* curve
- `origin` (optional) – Origin point
    - Must be a `<circle>` element, where the origin will be the circle center
    - Specifies pictogram origin. If not provided, then centroid of the collision shape is used.
- `mask` – Selection outline mask
    - Can be a `<g>` group element or any direct graphic element, no `<use>`, no `<text>`.
    - All style (fill, line) is ignored
    - Path is considered a *filled* curve

Any other, non-recognized elements are ignored.

Run `Scripts/make-pictograms.sh` to create pictogram collections from the SVG files.

## Icon Font

Icons for the icon font are stored as SVG files. Icon name is equal to the file name.

Rules:

- Allowed shapes: `<circle>`, `<ellipse>` (converted to rectangle), `<rectangle>`,
  `<polygon>`, `<polyline>` (treated as polygon), `<path>`
- No `<use>` or `<text>` is allowed.
- All shapes are treated as *strokes/wires*, never filled.
- All shapes will be converted to a `<path>`.

Run the `Scripts/make-icon-font.sh` to create the icon font from the SVG files.

## License

The content is licensed under the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) License.

Third-party content has its license notice included in the `Notices/` directory.

## Author

- Stefan Urbanek, stefan.urbanek@gmail.com
