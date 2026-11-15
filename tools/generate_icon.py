#!/usr/bin/env python3
"""Generate FABLEBRINK's original pixel icon assets using Pillow only."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)
S = 48

PALETTE = {
    "night": (18, 37, 43, 255),
    "deep": (24, 52, 57, 255),
    "mid": (43, 81, 73, 255),
    "hill": (58, 105, 75, 255),
    "grass": (126, 166, 94, 255),
    "gold": (231, 190, 112, 255),
    "gold_light": (250, 221, 157, 255),
    "stone": (99, 122, 119, 255),
    "water": (102, 173, 177, 255),
    "white": (239, 239, 216, 255),
    "shadow": (10, 23, 29, 255),
}


def base_canvas():
    im = Image.new("RGBA", (S, S), PALETTE["night"])
    d = ImageDraw.Draw(im)
    # Distant dusk banding and stepped hills.
    d.rectangle((0, 0, 47, 47), fill=PALETTE["night"])
    d.rectangle((0, 27, 47, 47), fill=PALETTE["deep"])
    d.polygon([(0, 31), (8, 26), (15, 30), (24, 24), (33, 29), (41, 25), (48, 29), (48, 47), (0, 47)], fill=PALETTE["mid"])
    d.polygon([(0, 36), (10, 33), (19, 37), (29, 32), (38, 35), (48, 31), (48, 47), (0, 47)], fill=PALETTE["hill"])
    d.rectangle((0, 42, 47, 47), fill=PALETTE["grass"])
    # Pixel sun and small star.
    d.rectangle((34, 7, 38, 11), fill=PALETTE["gold_light"])
    d.rectangle((33, 8, 39, 10), fill=PALETTE["gold"])
    d.rectangle((8, 9, 9, 10), fill=PALETTE["white"])
    d.rectangle((10, 8, 10, 11), fill=PALETTE["white"])
    return im


def draw_symbol(im, monochrome=False):
    d = ImageDraw.Draw(im)
    if monochrome:
        fg = (255, 255, 255, 255)
        shadow = (255, 255, 255, 255)
        accent = fg
        floor = fg
    else:
        fg = PALETTE["gold"]
        shadow = PALETTE["shadow"]
        accent = PALETTE["water"]
        floor = PALETTE["grass"]
    # A stepped stone gateway: an open path into a world beyond.
    d.rectangle((13, 13, 14, 34), fill=shadow)
    d.rectangle((34, 13, 35, 34), fill=shadow)
    d.rectangle((15, 11, 17, 14), fill=fg)
    d.rectangle((30, 11, 33, 14), fill=fg)
    d.rectangle((18, 9, 29, 11), fill=fg)
    d.rectangle((16, 13, 18, 16), fill=fg)
    d.rectangle((30, 13, 33, 16), fill=fg)
    d.rectangle((16, 16, 18, 33), fill=fg)
    d.rectangle((30, 16, 32, 33), fill=fg)
    # Dark inner doorway with a cool luminous threshold.
    d.rectangle((19, 14, 29, 33), fill=shadow)
    d.rectangle((21, 19, 27, 32), fill=(18, 44, 53, 255) if not monochrome else shadow)
    d.rectangle((22, 24, 26, 32), fill=accent)
    d.rectangle((23, 21, 25, 23), fill=fg)
    # Path tiles leading into the gate.
    d.rectangle((20, 35, 28, 37), fill=floor)
    d.rectangle((22, 38, 26, 40), fill=floor)
    # Highlight the doorway's stone edge in a deliberately pixelated rhythm.
    if not monochrome:
        d.rectangle((14, 19, 15, 21), fill=PALETTE["gold_light"])
        d.rectangle((33, 25, 34, 27), fill=PALETTE["gold_light"])
        d.rectangle((19, 12, 21, 13), fill=PALETTE["gold_light"])


def upscale(im, size):
    return im.resize((size, size), Image.Resampling.NEAREST)


def main():
    # Main icon has a dark square background, matching the app's pixel palette.
    main = base_canvas()
    draw_symbol(main)
    upscale(main, 192).save(ASSETS / "icon-main-192.png", optimize=True)

    # Adaptive foreground contains only the centered symbol in Android's safe zone.
    foreground = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_symbol(foreground)
    upscale(foreground, 432).save(ASSETS / "icon-adaptive-foreground-432.png", optimize=True)

    # Adaptive background is supplied as a separate opaque layer.
    background = Image.new("RGBA", (S, S), PALETTE["night"])
    bg_draw = ImageDraw.Draw(background)
    bg_draw.rectangle((0, 34, 47, 47), fill=PALETTE["deep"])
    bg_draw.polygon([(0, 39), (13, 34), (25, 39), (36, 34), (48, 38), (48, 48), (0, 48)], fill=PALETTE["mid"])
    upscale(background, 432).save(ASSETS / "icon-adaptive-background-432.png", optimize=True)

    monochrome = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_symbol(monochrome, monochrome=True)
    upscale(monochrome, 432).save(ASSETS / "icon-adaptive-monochrome-432.png", optimize=True)

    # A small preview file is useful in repository README previews and issue reports.
    main.save(ASSETS / "icon-preview-48.png", optimize=True)


if __name__ == "__main__":
    main()
