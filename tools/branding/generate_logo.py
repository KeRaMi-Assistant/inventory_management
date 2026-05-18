#!/usr/bin/env python3
"""Generate all CanLogistics brand raster assets from a single source design.

Run from repo root:
    python3 tools/branding/generate_logo.py

Outputs (overwrite-safe):
    assets/branding/logo_1024.png             — App-Icon master (transparent bg, rounded square)
    assets/branding/logo_512.png
    assets/branding/logo_192.png
    assets/branding/logo_maskable_1024.png    — Safe-zone version for Android adaptive icons
    assets/branding/logo_mark_white_1024.png  — Mark on transparent (white-on-clear, for dark splashes)
    assets/branding/wordmark_light.png        — "CanLogistics" wordmark on transparent (dark text on light bg)
    assets/branding/wordmark_dark.png         — Wordmark in light text (for dark bg)
    assets/branding/favicon_512.png           — Web favicon source (square, rounded mark)
    web/icons/Icon-192.png, Icon-512.png, Icon-maskable-*.png — Direct web overrides

The script is deterministic; no external network calls. PIL (Pillow) is the only dependency.
"""
from __future__ import annotations

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---------------------------------------------------------------- Brand tokens
INDIGO_700 = (67, 56, 202, 255)   # #4338CA — primary brand
INDIGO_500 = (99, 102, 241, 255)  # #6366F1 — gradient highlight
INDIGO_900 = (49, 46, 129, 255)   # #312E81 — gradient deep
SLATE_900 = (15, 23, 42, 255)     # #0F172A — wordmark on light
SLATE_500 = (100, 116, 139, 255)  # #64748B — "Logistics" tone on light
SLATE_300 = (203, 213, 225, 255)  # #CBD5E1 — "Logistics" tone on dark
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

ROOT = Path(__file__).resolve().parents[2]
OUT_BRAND = ROOT / "assets" / "branding"
OUT_WEB_ICONS = ROOT / "web" / "icons"
OUT_BRAND.mkdir(parents=True, exist_ok=True)
OUT_WEB_ICONS.mkdir(parents=True, exist_ok=True)


# ----------------------------------------------------------------- Primitives
def rounded_rect_mask(size: int, radius_ratio: float = 0.22) -> Image.Image:
    """Returns a single-channel mask (L) with a rounded square at full alpha."""
    radius = int(size * radius_ratio)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    """Vertical gradient image, RGBA."""
    grad = Image.new("RGBA", (size, size), top)
    base = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        a = int(top[3] * (1 - t) + bottom[3] * t)
        base.putpixel((0, y), (r, g, b, a))
    return base.resize((size, size))


def stylized_c(size: int, fill=WHITE, padding_ratio: float = 0.20,
               stroke_ratio: float = 0.16, mouth_ratio: float = 0.32) -> Image.Image:
    """A bold geometric "C" with a slight arrow-tail in its lower-right mouth,
    suggesting outbound logistics flow. Returns an RGBA canvas, transparent bg.
    """
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    pad = int(size * padding_ratio)
    box = (pad, pad, size - pad, size - pad)
    stroke = int(size * stroke_ratio)

    # Outer ring (filled circle)
    draw.ellipse(box, fill=fill)

    # Inner cut-out (transparent circle) → "ring" shape
    inner_pad = pad + stroke
    inner_box = (inner_pad, inner_pad, size - inner_pad, size - inner_pad)
    draw.ellipse(inner_box, fill=TRANSPARENT)

    # Mouth: rectangular cut on the right side → turns "O" into "C"
    mouth_h = int((size - 2 * pad) * mouth_ratio)
    mouth_w = int((size - 2 * pad) * 0.60)
    mouth_top = size // 2 - mouth_h // 2
    mouth_box = (size - pad - mouth_w, mouth_top, size, mouth_top + mouth_h)
    draw.rectangle(mouth_box, fill=TRANSPARENT)

    # Logistics-flow arrow inside the mouth (rightward-pointing chevron, in fill color)
    cx = size - pad - int(stroke * 0.4)
    cy = size // 2
    arm = int(stroke * 0.95)
    thick = max(2, int(stroke * 0.32))
    # Two diagonal lines forming ">"
    draw.line(
        [(cx - arm, cy - arm), (cx, cy), (cx - arm, cy + arm)],
        fill=fill,
        width=thick,
        joint="curve",
    )

    return img


# ------------------------------------------------------------------ Composers
def render_app_icon(size: int, maskable: bool = False) -> Image.Image:
    """Indigo gradient rounded-square + stylized white C centered."""
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    gradient = vertical_gradient(size, INDIGO_500, INDIGO_900)

    if maskable:
        # Maskable: paint the FULL square so the launcher can crop it into any shape.
        # The "safe zone" is the centered 80% inscribed circle (Material spec).
        canvas.paste(gradient, (0, 0))
        mark_size = int(size * 0.50)  # mark sits in 50% of canvas → inside 80% safe zone
    else:
        # Standard: rounded square with transparent corners (legacy iOS / generic Android).
        mask = rounded_rect_mask(size, radius_ratio=0.22)
        canvas.paste(gradient, (0, 0), mask)
        mark_size = int(size * 0.62)

    mark = stylized_c(mark_size, fill=WHITE)
    off = (size - mark_size) // 2
    canvas.alpha_composite(mark, (off, off))
    return canvas


def render_mark_white(size: int) -> Image.Image:
    """Pure white mark on transparent — for dark splashes / dark login headers."""
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    mark = stylized_c(size, fill=WHITE)
    canvas.alpha_composite(mark, (0, 0))
    return canvas


def render_mark_indigo(size: int) -> Image.Image:
    """Indigo mark on transparent — for light splashes / light login headers."""
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    mark = stylized_c(size, fill=INDIGO_700)
    canvas.alpha_composite(mark, (0, 0))
    return canvas


def render_wordmark(height: int, light_bg: bool = True) -> Image.Image:
    """Renders 'CanLogistics' wordmark.

    "Can" bold in INDIGO_700 (or INDIGO_500 on dark), "Logistics" in slate.
    Auto-sizes width based on text metrics; transparent background.
    """
    # Try to load Inter bold (bundled by macOS via Google Fonts cache?) — fall back to default.
    font_can = _load_font(height, bold=True)
    font_log = _load_font(int(height * 0.94), bold=False)

    can_color = INDIGO_700 if light_bg else INDIGO_500
    log_color = SLATE_900 if light_bg else SLATE_300

    # Measure
    tmp = Image.new("RGBA", (8, 8))
    d = ImageDraw.Draw(tmp)
    can_bbox = d.textbbox((0, 0), "Can", font=font_can)
    log_bbox = d.textbbox((0, 0), "Logistics", font=font_log)
    can_w = can_bbox[2] - can_bbox[0]
    log_w = log_bbox[2] - log_bbox[0]
    spacing = int(height * 0.04)
    total_w = can_w + spacing + log_w
    canvas_h = int(height * 1.25)  # padding for descenders
    canvas = Image.new("RGBA", (total_w + 4, canvas_h), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    baseline_y = (canvas_h - height) // 2 - can_bbox[1]
    d.text((0, baseline_y), "Can", font=font_can, fill=can_color)
    d.text(
        (can_w + spacing, baseline_y - (log_bbox[1] - can_bbox[1])),
        "Logistics",
        font=font_log,
        fill=log_color,
    )
    return canvas


def _load_font(size: int, bold: bool):
    """Try Inter → SF Pro → Helvetica Neue → PIL default."""
    candidates_bold = [
        "/System/Library/Fonts/SFCompactDisplay.ttf",   # macOS system, bold via face
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    candidates_reg = [
        "/System/Library/Fonts/SFCompactDisplay.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    candidates = candidates_bold if bold else candidates_reg
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size=size, index=1 if bold and path.endswith(".ttc") else 0)
            except Exception:
                continue
    return ImageFont.load_default()


# ----------------------------------------------------------------------- Main
def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  wrote {path.relative_to(ROOT)}  ({img.size[0]}x{img.size[1]})")


def main() -> None:
    print("Rendering CanLogistics brand assets…")

    # App-Icon masters
    save(render_app_icon(1024), OUT_BRAND / "logo_1024.png")
    save(render_app_icon(512), OUT_BRAND / "logo_512.png")
    save(render_app_icon(192), OUT_BRAND / "logo_192.png")

    # Maskable (Android adaptive + web)
    save(render_app_icon(1024, maskable=True), OUT_BRAND / "logo_maskable_1024.png")
    save(render_app_icon(512, maskable=True), OUT_BRAND / "logo_maskable_512.png")
    save(render_app_icon(192, maskable=True), OUT_BRAND / "logo_maskable_192.png")

    # Pure marks (for in-app widgets / native splash overlays)
    save(render_mark_white(1024), OUT_BRAND / "logo_mark_white_1024.png")
    save(render_mark_indigo(1024), OUT_BRAND / "logo_mark_indigo_1024.png")

    # Wordmarks
    save(render_wordmark(96, light_bg=True), OUT_BRAND / "wordmark_light.png")
    save(render_wordmark(96, light_bg=False), OUT_BRAND / "wordmark_dark.png")

    # Favicon source
    save(render_app_icon(512), OUT_BRAND / "favicon_512.png")
    save(render_app_icon(48), OUT_BRAND / "favicon_48.png")

    # Direct web overrides (consumed by Flutter web at runtime)
    save(render_app_icon(192), OUT_WEB_ICONS / "Icon-192.png")
    save(render_app_icon(512), OUT_WEB_ICONS / "Icon-512.png")
    save(render_app_icon(192, maskable=True), OUT_WEB_ICONS / "Icon-maskable-192.png")
    save(render_app_icon(512, maskable=True), OUT_WEB_ICONS / "Icon-maskable-512.png")

    # Web favicon
    save(render_app_icon(48), ROOT / "web" / "favicon.png")

    # ── iOS LaunchImage.imageset — white mark on transparent.
    # Storyboard sets background to indigo, image is centered.
    ios_launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    save(render_mark_white(96), ios_launch / "LaunchImage.png")
    save(render_mark_white(192), ios_launch / "LaunchImage@2x.png")
    save(render_mark_white(288), ios_launch / "LaunchImage@3x.png")

    # ── Android native splash logo — white mark on transparent, drawable scope.
    android_drawable = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable"
    save(render_mark_white(192), android_drawable / "launch_logo.png")

    print("Done.")


if __name__ == "__main__":
    main()
