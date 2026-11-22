#!/usr/bin/env python3
"""Draw Catch's cast bar textures (numpy -> 32-bit TGA). Re-run to regenerate Catch/Textures/*.tga.

The cast bar as a strip of dusk water with a bobber riding the head (user, 2026-11-21: "maximum cozy"). Shapes are
drawn in the bar's own layout pixels (CastBar.lua's WIDTH × HEIGHT) and sampled onto power-of-two textures, so the
rounded ends stay round once WoW stretches them back. Greyscale where the bar tints them (water, glow, ripple).
"""
import os

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "Catch", "Textures")
W, H = 440, 20          # CastBar.lua: WIDTH, HEIGHT
PAD = 16                # the shadow reaches this far past the bar
TILE = 80               # CastBar.lua: TILE, the water texture's width on screen


def write_tga(name, rgba):
    """rgba: float array (h, w, 4) in 0..1, top row first"""
    h, w, _ = rgba.shape
    px = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    bgra = px[:, :, [2, 1, 0, 3]]
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + bgra.tobytes())


def grid(tw, th, lw, lh):
    """layout coordinates (x, y) of each texel's centre, for a tw × th texture shown at lw × lh"""
    x = (np.arange(tw) + 0.5) * lw / tw
    y = (np.arange(th) + 0.5) * lh / th
    return np.meshgrid(x, y)


def pill_sdf(x, y, w, h, ox=0.0, oy=0.0):
    """signed distance (layout px) to a pill of w × h whose top-left is (ox, oy); negative inside"""
    r = h / 2
    cx = np.clip(x - ox, r, w - r)
    return np.hypot(x - ox - cx, y - oy - r) - r


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def solid(alpha, rgb=(1, 1, 1)):
    out = np.zeros(alpha.shape + (4,))
    out[..., 0], out[..., 1], out[..., 2] = rgb
    out[..., 3] = alpha
    return out


def mask():
    x, y = grid(512, 32, W, H)
    d = pill_sdf(x, y, W, H)
    return solid(np.clip(0.5 - d, 0, 1))


def rim():
    """a thin warm edge, brighter on top (light from above), fading towards the bottom"""
    x, y = grid(512, 32, W, H)
    d = pill_sdf(x, y, W, H)
    band = np.clip(1 - np.abs(d + 0.6) / 0.9, 0, 1)
    light = 1 - 0.55 * (y / H)
    return solid(band * light)


def shadow():
    """the bar sits in a soft dark pool"""
    x, y = grid(512, 64, W + 2 * PAD, H + 2 * PAD)
    d = pill_sdf(x, y, W, H, PAD, PAD)
    return solid(0.85 * (1 - smooth(-4, PAD, d)), (0, 0, 0))


def water():
    """tileable greyscale water: lighter at the surface, two soft swells and a few glints, wraps horizontally"""
    tw, th = 128, 32
    x, y = grid(tw, th, TILE, H)
    u = x / TILE * 2 * np.pi
    v = 0.62 + 0.30 * (1 - y / H) ** 1.5
    for k, phase, centre, amp, strength in ((1, 0.0, 6.0, 1.6, 0.20), (2, 1.3, 12.5, 1.1, 0.12)):
        line = centre + amp * np.sin(k * u + phase)
        v += strength * np.exp(-((y - line) / 1.3) ** 2)
    glint = np.exp(-((y - (4.5 + 0.8 * np.sin(3 * u))) / 0.7) ** 2) * np.clip(np.sin(3 * u + 0.7), 0, 1) ** 6
    v += 0.35 * glint
    v = np.clip(v, 0, 1)
    return solid(np.ones_like(v), (0, 0, 0)) + np.stack([v, v, v, np.zeros_like(v)], -1)


def glow():
    x, y = grid(64, 64, 2, 2)
    r = np.hypot(x - 1, y - 1)
    return solid(np.exp(-(r / 0.42) ** 2) * (r < 1))


def band():
    """the bite window: flat in the middle, soft at both ends, a touch brighter at the surface"""
    x, y = grid(128, 32, 1, 1)
    edge = smooth(0, 0.22, x) * smooth(0, 0.22, 1 - x)
    return solid(edge * (0.75 + 0.25 * (1 - y)))


def ring():
    """the lure's timer ring: a soft-edged band, swept by a Cooldown frame"""
    x, y = grid(64, 64, 2, 2)
    r = np.hypot(x - 1, y - 1)
    return solid(np.clip((0.97 - r) * 32, 0, 1) * np.clip((r - 0.80) * 32, 0, 1))


def ripple():
    x, y = grid(64, 64, 2, 2)
    r = np.hypot(x - 1, y - 1)
    ring = np.exp(-((r - 0.78) / 0.07) ** 2) + 0.35 * np.exp(-((r - 0.55) / 0.06) ** 2)
    return solid(np.clip(ring, 0, 1) * (r < 1))


def bobber():
    """a quill float: a slim stick with a red tip, a tapered body (red cap fading into warm cork, wider low down),
    lit from the left, its foot sinking into the water. 32 × 64, shown at 20 × 40; the waterline is at y = 48."""
    tw, th = 32, 64
    x, y = grid(tw, th, tw, th)
    cx, top, bottom = 16.0, 24.0, 56.0
    t = np.clip((y - top) / (bottom - top), 0, 1)
    half = 8.0 * np.sin(np.pi * t) ** 0.7 * (0.45 + 0.55 * t)           # narrow shoulder, round belly
    dx = (x - cx) / np.maximum(half, 1e-3)
    body = np.clip((half - np.abs(x - cx)) + 0.5, 0, 1) * ((y > top) & (y < bottom))
    red = np.array([0.84, 0.32, 0.20])
    cork = np.array([0.82, 0.66, 0.44])
    mix = smooth(0.30, 0.55, t)[..., None]                               # the cap fades into cork, no seam
    base = (1 - mix) * red + mix * cork
    light = np.clip(0.55 + 0.45 * np.sqrt(np.clip(1 - dx * dx, 0, 1)) - 0.25 * dx, 0, 1.1)
    rgb = base * light[..., None]
    streak = np.exp(-((dx + 0.45) / 0.18) ** 2) * smooth(0.1, 0.3, t) * (1 - smooth(0.6, 0.8, t))
    rgb = rgb + 0.30 * streak[..., None]
    # the quill: a thin dark stick, its tip painted red
    stick = np.clip(1.3 - np.abs(x - cx), 0, 1) * ((y > 5) & (y <= top + 2))
    srgb = np.where((y < 12)[..., None], red * 1.05, np.array([0.30, 0.22, 0.16]))
    rgb = rgb * (1 - stick[..., None]) + srgb * stick[..., None]
    alpha = np.maximum(body, stick)
    # a soft dark outline, so it stands out on the amber fill as well as on the water
    halo = np.zeros_like(alpha)
    for ox in range(-2, 3):
        for oy in range(-2, 3):
            if ox * ox + oy * oy <= 5:
                halo = np.maximum(halo, np.roll(np.roll(alpha, oy, 0), ox, 1) * (0.9 if ox * ox + oy * oy <= 2 else 0.45))
    out_a = alpha + (1 - alpha) * halo * 0.75
    rgb = rgb * (alpha / np.maximum(out_a, 1e-3))[..., None] + np.array([0.08, 0.05, 0.03]) * (1 - alpha / np.maximum(out_a, 1e-3))[..., None]
    out_a = out_a * (1 - 0.7 * smooth(48, 55, y))                        # below the waterline it fades away
    return np.concatenate([np.clip(rgb, 0, 1), out_a[..., None]], -1)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("mask", mask), ("rim", rim), ("shadow", shadow), ("water", water), ("glow", glow), ("band", band), ("ring", ring),
                     ("ripple", ripple), ("bobber", bobber)):
        write_tga(name + ".tga", fn())
        print("wrote", name + ".tga")


if __name__ == "__main__":
    main()
