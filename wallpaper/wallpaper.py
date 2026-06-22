import os
import sys
import subprocess
from random import random
# from datetime import datetime, timezone, timedelta
# from suntime import Sun
import moderngl
import numpy as np
from PIL import Image

# --- CONFIGURATION ---
LAT = 38.6270
LON = -90.1994
MONITOR = "eDP-1"
WIDTH, HEIGHT = 1920, 1080
SHADER_FILE = os.path.expanduser("./main.frag")


# def choose_color_mode():
#     """Returns 0 for sunrise,1 for daytime, 2 for sunset, 3 for nighttime."""
#     sun = Sun(LAT, LON)
#     utc_sunrise = sun.get_sunrise_time()
#     utc_sunset = sun.get_sunset_time()
#     utc_time = datetime.now(timezone.utc)

#     sunrise_diff = utc_sunrise - utc_time
#     if abs(sunrise_diff / timedelta(minutes=1)) <= 30:
#         return 0

#     sunset_diff = utc_sunset - utc_time
#     if abs(sunset_diff / timedelta(minutes=1)) <= 30:
#         return 2

#     if utc_time > utc_sunrise and utc_time < utc_sunset:
#         return 1

#     return 3


def render_shader(shader_path, data, out_path):
    ctx = moderngl.create_standalone_context()

    with open(shader_path, 'r') as f:
        frag_content = f.read()

    vert_source = """
    #version 330
    in vec2 in_vert;
    void main() {
        gl_Position = vec4(in_vert, 0.0, 1.0);
    }
    """

    prog = ctx.program(vertex_shader=vert_source,
                       fragment_shader=frag_content)

    # Set uniforms safely
    # if 'u_time' in prog:
    #     prog['u_time'].value = time.time() % 1000.0

    for key, value in data.items():
        if key in prog:
            prog[key].value = value

    # Full screen quad
    vertices = np.array([
        -1.0, -1.0,
        1.0, -1.0,
        -1.0, 1.0,
        1.0, 1.0,
    ], dtype='f4')

    vbo = ctx.buffer(vertices)
    vao = ctx.simple_vertex_array(prog, vbo, 'in_vert')

    fbo = ctx.framebuffer(
        color_attachments=[ctx.renderbuffer((WIDTH, HEIGHT))]
    )
    fbo.use()
    ctx.clear(0.0, 0.0, 0.0, 1.0)
    vao.render(moderngl.TRIANGLE_STRIP)

    # Read and save
    raw = fbo.read(components=4)
    img = Image.frombytes('RGBA', (WIDTH, HEIGHT), raw).transpose(
        Image.FLIP_TOP_BOTTOM)
    img.save(out_path)


def main():
    # print("Color mode:" + str(choose_color_mode()))
    if not os.path.exists(SHADER_FILE):
        print(f"Shader file not found at {SHADER_FILE}", file=sys.stderr)
        sys.exit(1)

    # Fetch dynamic values
    # data = fetch_solar_and_weather()
    # data = {
    #     "u_a": (0.5, 0.2, 0.4),
    #     "u_b": (0.6, 0.0, 0.4),
    #     "u_c": (0.5, 0.8, 0.5),
    #     "u_d": (0.6, 0.0, 0.0)
    # }
    data = {
        "u_a": (random(), random(), random()),
        "u_b": (random(), random(), random()),
        "u_c": (random(), random(), random()),
        "u_d": (random(), random(), random())
    }

    # --- TEMPLATE: CALCULATE YOUR CUSTOM UNIFORMS HERE ---
    # You can process the raw API inputs into higher-level shader properties.

    # Example 1: Calculate transition factor between day and night
    # 0.0 means fully night, 1.0 means fully day
    # t = data["u_time_of_day"]
    # sr = data["u_sunrise"]
    # ss = data["u_sunset"]

    # Simple linear interpolation window for golden hour / dawn
    # (e.g., 45 mins = ~0.03 of a day)
    # buffer = 0.03
    # if t > (sr - buffer) and t < (ss + buffer):
    #     # It's daytime, fade smoothly near edges
    #     day_factor = min(1.0, (t - (sr - buffer)) / buffer) \
    #         if t < sr else 1.0
    #     day_factor = min(day_factor, ((ss + buffer) - t) / buffer) \
    #         if t > ss else day_factor
    # else:
    #     day_factor = 0.0

    # data["u_day_factor"] = day_factor

    # # Example 2: Weather severity metric mapping
    # # Map rain/storm codes to an intensity scalar
    # w = data["u_weather"]
    # storm_intensity = 0.0
    # if w in [51, 53, 55]: storm_intensity = 0.3   # Drizzle
    # elif w in [61, 63, 65]: storm_intensity = 0.6 # Rain
    # elif w in [71, 73, 75, 85, 86]: storm_intensity = 0.8 # Snow
    # elif w in [95, 96, 99]: storm_intensity = 1.0 # Thunderstorm

    # data["u_storm_intensity"] = storm_intensity
    # ----------------------------------------------------

    # Generate transient unique file to completely break hyprpaper's caching
    new_image = os.path.expanduser("/tmp/wallpaper_shader.png")

    # Render single frame using ModernGL
    try:
        render_shader(SHADER_FILE, data, new_image)
    except Exception as e:
        print(f"Failed to render background frame: {e}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(new_image):
        print("Failed to render background frame (no file).", file=sys.stderr)
        sys.exit(1)

    # Atomic swap inside hyprpaper IPC
    # subprocess.run(
    #     ["hyprctl", "hyprpaper", "preload", new_image],
    #     stdout=subprocess.DEVNULL
    # )
    subprocess.run(
        ["hyprctl", "hyprpaper", "wallpaper", f"{MONITOR},{new_image}"],
        stdout=subprocess.DEVNULL
    )

    # Unload older images to avoid leaks.
    # Hyprpaper clears completely unused images when explicit unload is sent
    subprocess.run(
        ["hyprctl", "hyprpaper", "unload", "unused"],
        stdout=subprocess.DEVNULL
    )


if __name__ == "__main__":
    main()
