#!/usr/bin/env python3
"""Generate the VolumeBridge app icon SVG renditions.

Design: the Golden Gate Bridge in side elevation, international orange on a clear-sky blue
squircle. In side view the near tower leg hides the far one, so the tower is a solid column
that steps in at each portal-strut level; the main cable rides over the saddle at the tower
top and continues down the side span. The main-span cable is a parabola, the same curve as
VolumeBridge's squared gain mapping, and its hangers rise like a volume meter.

Every rendition is drawn on the 1024-unit macOS icon grid (824-unit continuous-corner
squircle at 100,100). Small renditions snap key edges and stroke widths to their target
pixel grid (1 px = 1024 / size units) so box-filter downscaling stays crisp:

  AppIcon.svg     master, used for 128-1024 px (8-unit grid)
  AppIcon-64.svg  64 px: four 2 px hangers, three tower steps, two water rows
  AppIcon-32.svg  32 px: four 1 px hangers, 1.5 px cable, 2 px tower, one water row
  AppIcon-16.svg  16 px: hand-placed pixel cable, two hangers, no water or sun

scripts/build-icon.sh renders these files and packs Resources/AppIcon.icns.
Usage: python3 design/icon/icon.py [output-directory]
"""
import pathlib
import sys

X0, Y0, SIZE, RADIUS = 100.0, 100.0, 824.0, 185.4

PALETTE = dict(
    bg=[(0, "#5DB0FF"), (1, "#2A74E0")],      # clear-sky blue
    ink=("#FF7347", "#D8402A"),              # international orange, top to bottom
    sun=("#FFFFFF", "#E8F5FF", 0.85, 0.3),   # soft sun glow: inner/outer colour and opacity
    water=("#FFFFFF", 0.32),
    lift=("#0B3D91", 0.28),                  # bridge drop shadow
    edge=("#FFFFFF", 0.18))                  # inner squircle edge highlight

# 128 px and up: the approved design snapped to the 8-unit grid (1 px at 128 px).
MASTER = dict(
    vertex=(206, 588), apex=(736, 208), cable_w=16, cable_start=170,
    deck=(616, 32), deck_x=(160, 892), deck_rx=16,
    hangers=tuple(range(664, 220, -40)), hanger_w=16,
    side=(888, 608, 10), side_hangers=(808, 848),
    tower=((216, 344, 32), (344, 480, 48), (480, 808, 64)), shade=0.10,
    water=((800, 8, ((236, 430), (478, 676))), (832, 8, ((300, 360), (404, 620))), (864, 8, ((372, 450), (490, 544)))),
    sun=(404, 390, 200), lift=(12, 14))

# 64 px (16-unit grid).
M64 = dict(
    vertex=(208, 576), apex=(736, 224), cable_w=32, cable_start=176,
    deck=(608, 48), deck_x=(176, 880), deck_rx=24,
    hangers=(304, 416, 528, 640), hanger_w=32,
    side=(864, 592, 8), side_hangers=(),
    tower=((240, 352, 32), (352, 512, 64), (512, 768, 96)), shade=0.12,
    water=((752, 16, ((240, 432), (480, 656))), (800, 16, ((304, 368), (400, 592)))),
    sun=(404, 390, 200), lift=(8, 8))

# 32 px (32-unit grid). A 1 px cable is too faint; 2 px merges with the deck near mid-span.
S32 = dict(
    vertex=(224, 576), apex=(736, 224), cable_w=48, cable_start=192,
    deck=(608, 64), deck_x=(192, 864), deck_rx=32,
    hangers=(336, 432, 528, 624), hanger_w=32,
    side=(864, 592, 6), side_hangers=(),
    tower=((248, 768, 64),), shade=0.14,
    water=((736, 32, ((256, 448), (512, 640))),),
    sun=(404, 390, 190), lift=None)

# 16 px (64-unit grid). An anti-aliased cable turns into muddy purple pixels at this size,
# so the cable is drawn as whole solid pixels (column, row) of the 16 x 16 grid.
XS16 = dict(
    vertex=(224, 544), apex=(768, 224), cable_w=64, cable_start=192,
    cable_cells=((3, 8), (4, 8), (5, 8), (6, 7), (7, 7), (8, 6), (9, 5), (10, 4), (11, 3), (12, 3)), cells_size=16,
    deck=(640, 64), deck_x=(192, 896), deck_rx=0,
    hangers=(480, 608), hanger_w=64,
    side=None, side_hangers=(),
    tower=((256, 768, 128),), shade=0.16,
    water=(), sun=None, lift=None)

RENDITIONS = {"AppIcon.svg": MASTER, "AppIcon-64.svg": M64, "AppIcon-32.svg": S32, "AppIcon-16.svg": XS16}


def fmt(*values):
    return " ".join(f"{v:.2f}" for v in values)


def squircle(x, y, w, h, r):
    """Continuous-corner rounded rectangle used by macOS app icons."""
    a, b, c, d, e, f, g = (r * k for k in (1.52866483, 1.08849323, 0.86840689, 0.66993427,
                                           0.06549600, 0.37282392, 0.16842370))
    x1, y1 = x + w, y + h
    return " ".join([
        f"M{fmt(x + a, y)}", f"L{fmt(x1 - a, y)}",
        f"C{fmt(x1 - b, y, x1 - c, y, x1 - d, y + e)}",
        f"C{fmt(x1 - f, y + g, x1 - g, y + f, x1 - e, y + d)}",
        f"C{fmt(x1, y + c, x1, y + b, x1, y + a)}",
        f"L{fmt(x1, y1 - a)}",
        f"C{fmt(x1, y1 - b, x1, y1 - c, x1 - e, y1 - d)}",
        f"C{fmt(x1 - g, y1 - f, x1 - f, y1 - g, x1 - d, y1 - e)}",
        f"C{fmt(x1 - c, y1, x1 - b, y1, x1 - a, y1)}",
        f"L{fmt(x + a, y1)}",
        f"C{fmt(x + b, y1, x + c, y1, x + d, y1 - e)}",
        f"C{fmt(x + f, y1 - g, x + g, y1 - f, x + e, y1 - d)}",
        f"C{fmt(x, y1 - c, x, y1 - b, x, y1 - a)}",
        f"L{fmt(x, y + a)}",
        f"C{fmt(x, y + b, x, y + c, x + e, y + d)}",
        f"C{fmt(x + g, y + f, x + f, y + g, x + d, y + e)}",
        f"C{fmt(x + c, y, x + b, y, x + a, y)}", "Z"])


SQ = squircle(X0, Y0, SIZE, SIZE, RADIUS)


def frame(defs, art, background, edge, edge_opacity):
    """Squircle body with the standard drop shadow; artwork is clipped to the body."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>
<filter id="drop" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">
<feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000000" flood-opacity="0.28"/>
</filter>
<clipPath id="body"><path d="{SQ}"/></clipPath>
{defs}
</defs>
<path d="{SQ}" fill="{background}" filter="url(#drop)"/>
<g clip-path="url(#body)">
{art}
<path d="{SQ}" fill="none" stroke="{edge}" stroke-opacity="{edge_opacity}" stroke-width="6"/>
</g>
</svg>
"""


def shadow(name, dy, deviation, color, opacity):
    return (f'<filter id="{name}" x="-30%" y="-30%" width="160%" height="170%">'
            f'<feDropShadow dx="0" dy="{dy}" stdDeviation="{deviation}" flood-color="{color}" '
            f'flood-opacity="{opacity}"/></filter>')


def vgrad(gid, spec, y1=100, y2=924):
    stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in spec)
    return (f'<linearGradient id="{gid}" x1="0" y1="{y1}" x2="0" y2="{y2}" '
            f'gradientUnits="userSpaceOnUse">{stops}</linearGradient>')


def radial(gid, inner, outer, inner_opacity, outer_opacity):
    return (f'<radialGradient id="{gid}" cx="0.5" cy="0.5" r="0.5">'
            f'<stop offset="0" stop-color="{inner}" stop-opacity="{inner_opacity}"/>'
            f'<stop offset="0.55" stop-color="{outer}" stop-opacity="{outer_opacity}"/>'
            f'<stop offset="1" stop-color="{outer}" stop-opacity="0"/></radialGradient>')


def polyline(f, xs):
    return "M" + " L".join(f"{x},{f(x):.1f}" for x in xs)


def quad(p0, p1, p2, n=240):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return pts


def y_at(points, x):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if min(x0, x1) <= x <= max(x0, x1) and x0 != x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    raise ValueError(x)


def bridge(spec, p=PALETTE):
    (vx, vy), (cx, apex) = spec["vertex"], spec["apex"]
    a = (vy - apex) / (cx - vx) ** 2
    cable_y = lambda x: vy - a * (x - vx) ** 2
    deck_y, deck_h = spec["deck"]
    hw = spec["hanger_w"]
    bar = lambda x, top: f'<rect x="{x - hw / 2}" y="{top:.1f}" width="{hw}" height="{deck_y + 2 - top:.1f}"/>'
    hangers = "".join(bar(x, cable_y(x)) for x in spec["hangers"])
    cable = polyline(cable_y, range(spec["cable_start"], cx, 4)) + f" L{cx},{apex}"
    cells = spec.get("cable_cells")
    if cells:
        # Hand-hinted pixel cable replaces the stroked cable; it has no side span.
        assert not spec["side"], "pixel cable renditions have no side span"
        unit = 1024 / spec["cells_size"]
        hangers += "".join(f'<rect x="{c * unit}" y="{r * unit}" width="{unit}" height="{unit}"/>' for c, r in cells)
        cable = ""
    if spec["side"]:
        ex, ey, sag = spec["side"]
        side = quad((cx, apex), ((cx + ex) / 2 - sag, (apex + ey) / 2 + sag * 1.4), (ex, ey))
        cable += " " + " ".join(f"L{x:.1f},{y:.1f}" for x, y in side[1:])
        hangers += "".join(bar(x, y_at(side, x)) for x in spec["side_hangers"])
    # Tower: one solid stepped column; the right half is darkened for volume.
    tower = "".join(f'<rect x="{cx - w / 2}" y="{y0}" width="{w}" height="{y1 - y0}" fill="url(#ink)"/>'
                    f'<rect x="{cx}" y="{y0}" width="{w / 2}" height="{y1 - y0}" fill="#000000" opacity="{spec["shade"]}"/>'
                    for y0, y1, w in spec["tower"])
    x0, x1 = spec["deck_x"]
    water = "".join(f'<rect x="{d0}" y="{y}" width="{d1 - d0}" height="{h}" rx="{h / 2}"/>'
                    for y, h, dashes in spec["water"] for d0, d1 in dashes)
    sun = ""
    if spec["sun"]:
        sx, sy, sr = spec["sun"]
        sun = f'<circle cx="{sx}" cy="{sy}" r="{sr}" fill="url(#sun)"/>'
    lift_filter, lift_open, lift_close = "", "<g>", "</g>"
    if spec["lift"]:
        dy, dev = spec["lift"]
        lift_filter = shadow("lift", dy, dev, *p["lift"])
        lift_open = '<g filter="url(#lift)">'
    defs = f"""
{vgrad("bg", p["bg"])}
{vgrad("ink", [(0, p["ink"][0]), (1, p["ink"][1])], apex, spec["tower"][-1][1])}
{radial("sun", *p["sun"])}
{lift_filter}"""
    art = f"""
<rect width="1024" height="1024" fill="url(#bg)"/>
{sun}
<g fill="{p["water"][0]}" fill-opacity="{p["water"][1]}">{water}</g>
{lift_open}
<g fill="url(#ink)">{hangers}</g>
<rect x="{x0}" y="{deck_y}" width="{x1 - x0}" height="{deck_h}" rx="{spec["deck_rx"]}" fill="url(#ink)"/>
{f'<path d="{cable}" fill="none" stroke="url(#ink)" stroke-width="{spec["cable_w"]}" stroke-linecap="round" stroke-linejoin="round"/>' if cable else ""}
{tower}
{lift_close}"""
    return frame(defs, art, p["bg"][0][1], p["edge"][0], p["edge"][1])


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent
    out.mkdir(parents=True, exist_ok=True)
    for name, spec in RENDITIONS.items():
        (out / name).write_text(bridge(spec))
    print(f"wrote {', '.join(RENDITIONS)} to {out}")
