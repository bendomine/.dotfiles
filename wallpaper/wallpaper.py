"""Wallpaper and desktop theme generator.

Renders a domain-warped fBM noise field (main.frag) coloured by a randomly
generated OKLCH gradient, shows it with hyprpaper and derives a matching
desktop theme (quickshell, rofi, hyprland, mako) from the same palette. The
theme's light/dark mode also switches GTK, Qt and KDE apps.

    wallpaper                    render, apply and write the theme
    wallpaper --seed N           same, reproducibly
    wallpaper --preview OUT.png  render wallpaper + palette sheet only
"""
import argparse
import glob
import json
import math
import os
import random
import subprocess
import sys
import tempfile
import time

import moderngl
import numpy as np
from PIL import Image, ImageDraw

FALLBACK_SIZE = (1920, 1080)
LUT_SIZE = 256
HYPRPAPER_WAIT = 15.0

# --- OKLab <-> linear sRGB (Bjorn Ottosson) ---
M_RGB_LMS = np.array([
    [0.4122214708, 0.5363325363, 0.0514459929],
    [0.2119034982, 0.6806995451, 0.1073969566],
    [0.0883024619, 0.2817188376, 0.6299787005],
])
M_LMS_LAB = np.array([
    [0.2104542553, 0.7936177850, -0.0040720468],
    [1.9779984951, -2.4285922050, 0.4505937099],
    [0.0259040371, 0.7827717662, -0.8086757660],
])
M_LAB_LMS = np.linalg.inv(M_LMS_LAB)
M_LMS_RGB = np.linalg.inv(M_RGB_LMS)


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, None)
    return np.where(c <= 0.0031308, c * 12.92,
                    1.055 * c ** (1.0 / 2.4) - 0.055)


def oklab_to_linear(lab):
    return (np.asarray(lab) @ M_LAB_LMS.T) ** 3 @ M_LMS_RGB.T


def linear_to_oklab(rgb):
    return np.cbrt(np.asarray(rgb) @ M_RGB_LMS.T) @ M_LMS_LAB.T


def lch_to_lab(L, C, h):
    r = np.radians(h)
    return np.stack(np.broadcast_arrays(
        L, C * np.cos(r), C * np.sin(r)), axis=-1).astype(np.float64)


def lab_to_lch(lab):
    lab = np.asarray(lab)
    C = np.hypot(lab[..., 1], lab[..., 2])
    h = np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360.0
    return lab[..., 0], C, h


def in_gamut(lab, eps=1e-5):
    rgb = oklab_to_linear(lab)
    return np.all((rgb >= -eps) & (rgb <= 1.0 + eps), axis=-1)


def gamut_map(lab):
    """Pull colours into sRGB by lowering chroma at constant L and hue."""
    lab = np.array(lab, dtype=np.float64)
    lab[..., 0] = np.clip(lab[..., 0], 0.0, 1.0)
    lo = np.zeros(lab.shape[:-1])
    hi = np.ones(lab.shape[:-1])
    for _ in range(24):
        mid = (lo + hi) / 2.0
        test = lab.copy()
        test[..., 1:] *= mid[..., None]
        ok = in_gamut(test)
        lo = np.where(ok, mid, lo)
        hi = np.where(ok, hi, mid)
    scale = np.where(in_gamut(lab), 1.0, lo)
    lab[..., 1:] *= scale[..., None]
    return lab


def lab_to_srgb(lab):
    """OKLab -> gamma encoded sRGB in [0, 1] (gamut mapped)."""
    return np.clip(linear_to_srgb(oklab_to_linear(gamut_map(lab))), 0, 1)


def to_hex(lab):
    r, g, b = (int(round(v * 255)) for v in lab_to_srgb(lab))
    return f"#{r:02x}{g:02x}{b:02x}"


def lch_hex(L, C, h):
    return to_hex(lch_to_lab(L, C, h))


def luminance(hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    r, g, b = srgb_to_linear(rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue_diff(a, b):
    d = (a - b) % 360.0
    return min(d, 360.0 - d)


def hue_delta(a, b):
    """Signed shortest rotation from b to a, in degrees."""
    return (a - b + 180.0) % 360.0 - 180.0


def demud(L, C, h, ref=None):
    """Dark yellows turn olive/khaki: rotate them towards rust or green.

    `ref` (the hue family the colour belongs to) picks the direction, so
    neighbouring stops of one family never split towards both sides.
    """
    h %= 360.0
    ref = h if ref is None else ref % 360.0
    if 60.0 < h < 125.0 and L < 0.72:
        w = min(1.0, (0.72 - L) / 0.3)
        if hue_delta(ref, 95.0) < 0.0:
            h += (45.0 - h) * w
            C *= 1.0 + 0.4 * w
        else:
            h += (145.0 - h) * w
            C *= 1.0 - 0.3 * w
    return L, C, h


def weighted_choice(rng, table):
    total = sum(row[1] for row in table)
    x = rng.uniform(0.0, total)
    for row in table:
        x -= row[1]
        if x <= 0.0:
            return row
    return table[-1]


# --- Palette generation ---
HARMONIES = [
    ("monochromatic", 3.0),
    ("analogous", 4.0),
    ("complementary", 2.0),
    ("split-complementary", 2.0),
    ("triadic", 1.5),
    ("tetradic", 1.0),
]
# name, weight, lightness range of the darkest / lightest stop
LIGHTNESS = [
    ("dark", 3.0, (0.12, 0.20), (0.45, 0.62)),
    ("mid", 2.0, (0.30, 0.42), (0.65, 0.80)),
    ("light", 2.2, (0.62, 0.74), (0.88, 0.96)),
    ("contrast", 1.5, (0.10, 0.20), (0.82, 0.94)),
]
# name, weight, peak chroma range
CHROMA = [
    ("muted", 2.0, (0.03, 0.07)),
    ("soft", 3.0, (0.06, 0.11)),
    ("rich", 3.0, (0.10, 0.16)),
    ("vivid", 1.5, (0.15, 0.26)),
]


def harmony_offsets(rng, name):
    s = rng.uniform(18.0, 40.0)
    offsets = {
        "monochromatic": [0.0],
        "analogous": [-s, 0.0, s],
        "complementary": [0.0, 180.0],
        "split-complementary": [0.0, 180.0 - s, 180.0 + s],
        "triadic": [0.0, 120.0, 240.0],
        "tetradic": [0.0, 2.0 * s, 180.0, 180.0 + 2.0 * s],
    }[name]
    jittered = [offsets[0]] + [o + rng.uniform(-8.0, 8.0)
                               for o in offsets[1:]]
    if rng.random() < 0.5:
        jittered.reverse()
    return jittered


def make_palette(rng):
    n = rng.randint(4, 7)
    base = rng.uniform(0.0, 360.0)
    harmony = weighted_choice(rng, HARMONIES)[0]
    anchors = [base + o for o in harmony_offsets(rng, harmony)]

    light_name, _, lo_range, hi_range = weighted_choice(rng, LIGHTNESS)
    lo, hi = rng.uniform(*lo_range), rng.uniform(*hi_range)
    shape = "ramp" if rng.random() < 0.65 else "arch"
    gamma = rng.uniform(0.7, 1.5)
    flip = rng.random() < 0.5

    chroma_name, _, c_range = weighted_choice(rng, CHROMA)
    c_peak = rng.uniform(*c_range)
    # Contrasting hues need less chroma; one hue dominates, the others
    # support it (60-30-10 rule) so multi-hue harmonies never turn garish.
    c_peak *= {"complementary": 0.9, "split-complementary": 0.85,
               "triadic": 0.75, "tetradic": 0.7}.get(harmony, 1.0)
    dominant = rng.randrange(len(anchors))
    support = [1.0 if g == dominant or harmony == "analogous"
               else rng.uniform(0.5, 0.8) for g in range(len(anchors))]
    # Hue shift with lightness, as painters shift shadows and highlights.
    if harmony == "monochromatic":
        shift = rng.uniform(15.0, 50.0)
    else:
        shift = rng.uniform(0.0, 25.0)
    shift *= rng.choice((-1.0, 1.0))
    pop = rng.randrange(n) if rng.random() < 0.35 else -1

    step = 1.0 / (n - 1)
    pos = [0.0] + [i * step + rng.uniform(-0.25, 0.25) * step
                   for i in range(1, n - 1)] + [1.0]
    groups = [i * len(anchors) // n for i in range(n)]
    drift = [rng.uniform(-8.0, 8.0) for _ in anchors]

    stops = []
    for i, u in enumerate(pos):
        if shape == "ramp":
            f = u ** gamma
        else:
            f = math.sin(math.pi * u) ** gamma
        if flip:
            f = 1.0 - f
        L = lo + (hi - lo) * f

        g = groups[i]
        members = [j for j in range(n) if groups[j] == g]
        centre = (members[0] + members[-1]) / 2.0
        h = anchors[g] + drift[g] * (i - centre) + shift * (L - 0.5)

        envelope = (4.0 * L * (1.0 - L)) ** 0.6
        C = c_peak * support[g] * envelope * rng.uniform(0.85, 1.1)
        if i == pop:
            C *= 1.5
        stops.append(lch_to_lab(*demud(L, C, h, anchors[g])))

    return {
        "stops": gamut_map(np.array(stops)),
        "pos": np.array(pos),
        "desc": f"{harmony}, {light_name} {shape}, {chroma_name}, {n} stops",
    }


def gradient(palette, cdf=None, mix=0.0):
    """Sample the OKLab gradient into a LUT_SIZE x 3 sRGB float array.

    `cdf` (raw value -> rank, sampled on the same grid) partially equalises
    the field so every stop covers a reasonable share of the screen.
    """
    stops, pos = palette["stops"], palette["pos"]
    xs = np.linspace(0.0, 1.0, 1024)
    lab = np.stack([np.interp(xs, pos, stops[:, k]) for k in range(3)], -1)
    # Smooth away the kinks at the stops (they show up as Mach bands).
    sigma = 1023.0 / (len(pos) - 1) * 0.15
    radius = int(3 * sigma)
    kernel = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    kernel /= kernel.sum()
    padded = np.pad(lab, ((radius, radius), (0, 0)), mode="edge")
    lab = np.stack([np.convolve(padded[:, k], kernel, mode="valid")
                    for k in range(3)], -1)

    t = np.linspace(0.0, 1.0, LUT_SIZE)
    if cdf is not None:
        t = (1.0 - mix) * t + mix * cdf
    lut = np.stack([np.interp(t, xs, lab[:, k]) for k in range(3)], -1)
    return lab_to_srgb(lut)


# --- Theme derivation ---
def ensure_contrast(L, C, h, against, ratio):
    """Move L away from `against` until the WCAG ratio is met."""
    direction = 1.0 if luminance(against) < 0.18 else -1.0
    while True:
        color = lch_hex(L, C, h)
        if contrast(color, against) >= ratio or not 0.0 < L < 1.0:
            return color, L
        L = min(1.0, max(0.0, L + 0.005 * direction))


def derive_theme(palette, seed):
    stops = palette["stops"]
    Ls, Cs, Hs = lab_to_lch(stops)
    dark = float(Ls.mean()) <= 0.6
    w = Cs + 1e-4
    hue = math.degrees(math.atan2(
        float((w * np.sin(np.radians(Hs))).sum()),
        float((w * np.cos(np.radians(Hs))).sum()))) % 360.0
    tint = min(0.02, 0.12 * float(Cs.max()) + 0.006)

    if dark:
        neutral = {"background": 0.17, "surface": 0.22,
                   "surfaceVariant": 0.29, "border": 0.38}
        tints = {"background": 0.9, "surface": 1.0,
                 "surfaceVariant": 1.2, "border": 1.4}
        fg_l, muted_l = 0.94, 0.76
    else:
        neutral = {"background": 0.95, "surface": 0.975,
                   "surfaceVariant": 0.92, "border": 0.84}
        tints = {"background": 0.6, "surface": 0.5,
                 "surfaceVariant": 0.9, "border": 1.0}
        fg_l, muted_l = 0.24, 0.47
    theme = {"mode": "dark" if dark else "light"}
    for key, L in neutral.items():
        theme[key] = lch_hex(L, tint * tints[key], hue)
    surface = theme["surface"]

    theme["foreground"] = ensure_contrast(
        fg_l, min(0.5 * tint, 0.012), hue, surface, 7.0)[0]
    theme["foregroundMuted"] = ensure_contrast(
        muted_l, 0.8 * tint, hue, surface, 4.5)[0]

    def accent_color(L, C, h):
        L = min(max(L, 0.70), 0.84) if dark else min(max(L, 0.45), 0.55)
        return ensure_contrast(*demud(L, C, h), surface, 3.0)

    # Most chromatic stop, preferring mid tones over extremes.
    i = int(np.argmax(Cs * (1.0 - 0.5 * np.abs(Ls - 0.6))))
    a_c = min(max(float(Cs[i]) * 1.25, 0.07), 0.2)
    a_h = float(Hs[i])
    theme["accent"], a_l = accent_color(float(Ls[i]), a_c, a_h)

    # Dark text on dark-mode accents and light text on light-mode ones when
    # that passes; otherwise whichever contrasts more.
    candidates = [(0.2, min(0.3 * a_c, 0.04)), (0.985, 0.01)]
    if not dark:
        candidates.reverse()
    ratios = [contrast(lch_hex(L, C, a_h), theme["accent"])
              for L, C in candidates]
    on = candidates[0] if ratios[0] >= 4.5 else max(
        zip(ratios, candidates))[1]
    theme["onAccent"] = ensure_contrast(
        on[0], on[1], a_h, theme["accent"], 4.5)[0]

    others = [j for j in range(len(stops)) if j != i]
    j = max(others, key=lambda k: 0.7 * hue_diff(Hs[k], a_h) / 180.0
            + 0.3 * Cs[k] / (Cs.max() + 1e-9))
    if hue_diff(Hs[j], a_h) < 20.0:
        alt_h, alt_c = a_h + 35.0, 0.85 * a_c
    else:
        alt_h, alt_c = float(Hs[j]), min(max(Cs[j] * 1.25, 0.06), 0.18)
    alt_l = a_l - 0.04 if dark else a_l + 0.04
    theme["accentAlt"] = accent_color(alt_l, alt_c, alt_h)[0]

    for key, base in (("urgent", 25.0), ("success", 145.0)):
        h = base + max(-10.0, min(10.0, 0.15 * hue_delta(a_h, base)))
        theme[key] = accent_color(a_l, min(max(a_c, 0.11), 0.19), h)[0]

    theme["palette"] = [to_hex(s) for s in stops]
    theme["seed"] = seed
    shadow = lch_hex(0.1 if dark else 0.3, tint, hue)
    theme["_shadow"] = ("ee" if dark else "66") + shadow[1:]
    return theme


THEME_KEYS = ["mode", "background", "surface", "surfaceVariant",
              "foreground", "foregroundMuted", "accent", "onAccent",
              "accentAlt", "border", "urgent", "success", "palette", "seed"]
RASI_KEYS = [
    ("wp-background", "background"), ("wp-surface", "surface"),
    ("wp-surface-variant", "surfaceVariant"),
    ("wp-foreground", "foreground"),
    ("wp-foreground-muted", "foregroundMuted"),
    ("wp-accent", "accent"), ("wp-on-accent", "onAccent"),
    ("wp-accent-alt", "accentAlt"), ("wp-border", "border"),
    ("wp-urgent", "urgent"), ("wp-success", "success"),
]


def hypr_colors(theme):
    return {
        "active_border": f"rgba({theme['accent'][1:]}ff)",
        "inactive_border": f"rgba({theme['border'][1:]}aa)",
        "shadow": "0x" + theme["_shadow"],
    }


def theme_files(theme):
    data = {k: theme[k] for k in THEME_KEYS}
    rasi = "* {\n" + "".join(f"    {var}: {theme[key]};\n"
                             for var, key in RASI_KEYS) + "}\n"
    hc = hypr_colors(theme)
    lua = ("return {\n"
           f"    active_border = \"{hc['active_border']}\",\n"
           f"    inactive_border = \"{hc['inactive_border']}\",\n"
           f"    shadow = {hc['shadow']},\n"
           "}\n")
    mako = (f"background-color={theme['surface']}e6\n"
            f"text-color={theme['foreground']}\n"
            f"border-color={theme['accent']}\n"
            f"progress-color=over {theme['surfaceVariant']}\n"
            "\n[urgency=high]\n"
            f"border-color={theme['urgent']}\n")
    return {
        "theme.json": json.dumps(data, indent=2) + "\n",
        "colors.rasi": rasi,
        "hyprland-colors.lua": lua,
        "mako-colors": mako,
    }


# --- Rendering ---
def shader_path():
    path = os.environ.get("WALLPAPER_SHADER")
    if path:
        return os.path.expanduser(path)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "main.frag")


def structure(rng):
    """Seeded parameters that shape the noise field itself."""
    angle = rng.uniform(0.0, 2.0 * math.pi)
    strength = rng.uniform(250.0, 650.0)
    return {
        "u_offset": (rng.uniform(-150.0, 150.0), rng.uniform(-150.0, 150.0)),
        "u_angle": rng.uniform(0.0, 2.0 * math.pi),
        "u_scale": rng.uniform(220.0, 420.0),
        "u_inner": rng.uniform(300.0, 650.0),
        "u_warp": (strength * math.cos(angle), strength * math.sin(angle)),
        "u_equalize": rng.uniform(0.2, 0.5),
    }


def create_context():
    try:
        return moderngl.create_standalone_context(backend="egl")
    except Exception:
        return moderngl.create_standalone_context()


def render(palette, params, size):
    ctx = create_context()
    try:
        with open(shader_path()) as f:
            frag = f.read()
        prog = ctx.program(vertex_shader="""
            #version 330
            in vec2 in_vert;
            void main() { gl_Position = vec4(in_vert, 0.0, 1.0); }
            """, fragment_shader=frag)
        quad = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], "f4"))
        vao = ctx.simple_vertex_array(prog, quad, "in_vert")

        def draw(fbo, res, uniforms):
            for key, value in {**params, **uniforms,
                               "u_resolution": res}.items():
                if key in prog:
                    prog[key].value = value
            fbo.use()
            ctx.viewport = (0, 0, *res)
            vao.render(moderngl.TRIANGLE_STRIP)

        # Statistics pass at low resolution (coordinates are resolution
        # independent) to map the field's actual value range onto the LUT.
        small = (max(1, size[0] // 4), max(1, size[1] // 4))
        stats = ctx.framebuffer(color_attachments=[
            ctx.renderbuffer(small, components=4, dtype="f4")])
        draw(stats, small, {"u_raw": 1})
        raw = np.frombuffer(stats.read(components=1, dtype="f4"), "f4")
        lo, hi = np.percentile(raw, [0.5, 99.5])
        hi = max(hi, lo + 1e-3)
        grid = np.linspace(lo, hi, LUT_SIZE)
        cdf = np.searchsorted(np.sort(raw), grid) / raw.size

        lut = gradient(palette, cdf, params["u_equalize"])
        tex = ctx.texture((LUT_SIZE, 1), 3, lut.astype("f4").tobytes(),
                          dtype="f4")
        tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
        tex.repeat_x = tex.repeat_y = False
        tex.use(0)

        fbo = ctx.framebuffer(color_attachments=[ctx.renderbuffer(size)])
        draw(fbo, size, {"u_raw": 0, "u_range": (lo, hi), "u_palette": 0})
        img = Image.frombytes("RGB", size, fbo.read(components=3))
        return img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    finally:
        ctx.release()


# --- Session integration ---
def run(*cmd, timeout=5.0):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None


def monitors():
    r = run("hyprctl", "monitors", "-j")
    if r is None or r.returncode != 0:
        return []
    try:
        data = json.loads(r.stdout)
    except ValueError:
        return []
    return data if isinstance(data, list) else []


def render_size(mons):
    w = h = 0
    for m in mons:
        mw, mh = int(m.get("width", 0)), int(m.get("height", 0))
        if int(m.get("transform", 0)) % 2:
            mw, mh = mh, mw
        w, h = max(w, mw), max(h, mh)
    return (w, h) if w and h else FALLBACK_SIZE


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    path = os.path.join(base, "wallpaper")
    os.makedirs(path, exist_ok=True)
    return path


def write_atomic(path, text):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def save_wallpaper(img, directory, seed):
    name = time.strftime("wall-%Y%m%d-%H%M%S") + f"-{seed}.png"
    path = os.path.join(directory, name)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".tmp-", suffix=".png")
    try:
        with os.fdopen(fd, "wb") as f:
            img.save(f, format="PNG", compress_level=3)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
        link = os.path.join(directory, ".current.png.tmp")
        if os.path.lexists(link):
            os.unlink(link)
        os.symlink(name, link)
        os.replace(link, os.path.join(directory, "current.png"))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return path


KDE_SCHEMES = {"dark": "BreezeDark", "light": "BreezeLight"}
KDE_SCHEME_GROUPS = ("[Colors:", "[ColorEffects:", "[WM]")


def ini_groups(text):
    """Split KDE config text into (header, lines); the first header is None."""
    groups = [(None, [])]
    for line in text.splitlines():
        if line.startswith("["):
            groups.append((line, []))
        else:
            groups[-1][1].append(line)
    return groups


def kdeglobals_text(current, scheme_text, scheme):
    """`current` with its colour groups replaced by those of `scheme_text`."""
    groups = [(h, ls) for h, ls in ini_groups(current)
              if not (h and h.startswith(KDE_SCHEME_GROUPS))]
    groups += [(h, ls) for h, ls in ini_groups(scheme_text)
               if h and h.startswith(KDE_SCHEME_GROUPS)]
    general = next((ls for h, ls in groups if h == "[General]"), None)
    if general is None:
        general = []
        groups.append(("[General]", general))
    general[:] = [f"ColorScheme={scheme}"] + [
        line for line in general if not line.startswith("ColorScheme=")]
    blocks = []
    for header, lines in groups:
        block = "\n".join(filter(None, (header, "\n".join(lines).strip("\n"))))
        if block:
            blocks.append(block)
    return "\n\n".join(blocks) + "\n"


def apply_kde_colors(mode):
    """Copy the Breeze scheme for `mode` into kdeglobals and signal Qt's
    built-in KDE platform theme (QT_QPA_PLATFORMTHEME=kde), which re-reads
    kdeglobals and repaints running Qt apps."""
    scheme = KDE_SCHEMES[mode]
    dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    for d in dirs.split(":"):
        path = os.path.join(d, "color-schemes", scheme + ".colors")
        if os.path.isfile(path):
            break
    else:
        print(f"kde: {scheme}.colors not found", file=sys.stderr)
        return
    with open(path) as f:
        scheme_text = f.read()
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    target = os.path.join(config, "kdeglobals")
    try:
        with open(target) as f:
            current = f.read()
    except FileNotFoundError:
        current = ""
    write_atomic(target, kdeglobals_text(current, scheme_text, scheme))
    # Qt listens for this from any sender; Plasma's portal normally sends it.
    run("busctl", "--user", "emit", "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.Settings", "SettingChanged", "ssv",
        "org.kde.kdeglobals.General", "ColorScheme", "s", scheme)


def apply_theme(theme):
    hc = hypr_colors(theme)
    run("hyprctl", "dispatch",
        "function() hl.config({"
        f"general={{col={{active_border=\"{hc['active_border']}\", "
        f"inactive_border=\"{hc['inactive_border']}\"}}}}, "
        f"decoration={{shadow={{color={hc['shadow']}}}}}"
        "}) end")
    run("makoctl", "reload")
    apply_kde_colors(theme["mode"])
    # xdg-desktop-portal-gtk serves color-scheme to apps (GTK4/libadwaita,
    # Chromium, Electron); GTK3 only follows gtk-theme.
    dark = theme["mode"] == "dark"
    for key, value in (("color-scheme", "prefer-dark" if dark else "prefer-light"),
                       ("gtk-theme", "Adwaita-dark" if dark else "Adwaita")):
        run("dconf", "write", f"/org/gnome/desktop/interface/{key}", f"'{value}'")


def apply_wallpaper(path, mons):
    """Point every monitor at `path`, waiting for hyprpaper's IPC."""
    names = [m.get("name", "") for m in mons] or [""]
    deadline = time.monotonic() + HYPRPAPER_WAIT
    for name in names:
        while True:
            r = run("hyprctl", "hyprpaper", "wallpaper", f"{name},{path}")
            if r is None:
                return False
            if r.returncode == 0:
                break
            if time.monotonic() >= deadline:
                msg = (r.stdout + r.stderr).strip()
                print(f"hyprpaper: {msg}", file=sys.stderr)
                return False
            time.sleep(0.5)
    return True


def prune(directory, keep):
    for path in glob.glob(os.path.join(directory, "wall-*.png")):
        if os.path.basename(path) != os.path.basename(keep):
            try:
                os.unlink(path)
            except OSError:
                pass


# --- Preview ---
def preview_sheet(img, palette, theme):
    w, h = img.size
    band = max(24, h // 20)
    sheet = Image.new("RGB", (w, h + 4 * band), theme["background"])
    sheet.paste(img, (0, 0))
    lut = (gradient(palette) * 255).round().astype(np.uint8)
    strip = Image.fromarray(lut[None, :, :]).resize((w, band))
    sheet.paste(strip, (0, h))
    draw = ImageDraw.Draw(sheet)
    stops = theme["palette"]
    for k, color in enumerate(stops):
        x0, x1 = k * w // len(stops), (k + 1) * w // len(stops)
        draw.rectangle((x0, h + band, x1, h + 2 * band), fill=color)
        draw.text((x0 + 6, h + band + 4), color,
                  fill="#000000" if luminance(color) > 0.2 else "#ffffff")
    keys = [k for k in THEME_KEYS if k not in ("mode", "palette", "seed")]
    for k, key in enumerate(keys):
        x0, x1 = k * w // len(keys), (k + 1) * w // len(keys)
        draw.rectangle((x0, h + 2 * band, x1, h + 4 * band),
                       fill=theme[key])
        ink = "#000000" if luminance(theme[key]) > 0.2 else "#ffffff"
        draw.text((x0 + 6, h + 2 * band + 4), f"{key}\n{theme[key]}",
                  fill=ink)
    draw.text((8, h + 3 * band + band // 2),
              f"seed {theme['seed']}: {palette['desc']}",
              fill=theme["foreground"])
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int,
                        help="seed for a reproducible palette and pattern")
    parser.add_argument("--preview", metavar="OUT.png",
                        help="write a preview sheet instead of applying")
    args = parser.parse_args()

    seed = args.seed
    if seed is None:
        seed = random.SystemRandom().randrange(2 ** 31)
    rng = random.Random(seed)
    palette = make_palette(rng)
    params = structure(rng)
    theme = derive_theme(palette, seed)

    if not os.path.exists(shader_path()):
        print(f"Shader file not found at {shader_path()}", file=sys.stderr)
        sys.exit(1)

    mons = [] if args.preview else monitors()
    try:
        img = render(palette, params, render_size(mons))
    except Exception as e:
        print(f"Failed to render wallpaper: {e}", file=sys.stderr)
        sys.exit(1)

    if args.preview:
        preview_sheet(img, palette, theme).save(args.preview)
        print(f"seed {seed}: {palette['desc']}")
        print(theme_files(theme)["theme.json"], end="")
        return

    directory = cache_dir()
    path = save_wallpaper(img, directory, seed)
    for name, text in theme_files(theme).items():
        write_atomic(os.path.join(directory, name), text)
    apply_theme(theme)
    apply_wallpaper(path, mons)
    prune(directory, path)
    print(f"seed {seed}: {palette['desc']} -> {path}")


if __name__ == "__main__":
    main()
