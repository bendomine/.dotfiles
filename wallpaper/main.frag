#version 330
precision highp float;

uniform vec2 u_resolution;   // framebuffer size in pixels
uniform vec2 u_offset;       // noise-space offset (seeded)
uniform float u_angle;       // rotation of the noise field (radians)
uniform float u_scale;       // feature size of the base octave (pixels @1080p)
uniform float u_inner;       // strength of the inner warp
uniform vec2 u_warp;         // strength/direction of the outer warp
uniform vec2 u_range;        // raw warp value range mapped onto the palette
uniform int u_raw;           // 1: output raw warp value (statistics pass)
uniform sampler2D u_palette; // 256x1 sRGB gradient LUT
out vec4 fragColor;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 grad(vec2 p) {
    float angle = random(p) * 2. * 3.1415926;
    return vec2(cos(angle), sin(angle));
}

float spline(float i) {
    return i*i*i*(i*(i*6. - 15.) + 10.);
}
vec2 spline(vec2 i) {
    return vec2(spline(i.x), spline(i.y));
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 blr = grad(i);
    vec2 tlr = grad(i + vec2(0., 1.));
    vec2 trr = grad(i + vec2(1., 1.));
    vec2 brr = grad(i + vec2(1., 0.));

    vec2 blo = f;
    vec2 tlo = f - vec2(0., 1.);
    vec2 tro = f - vec2(1., 1.);
    vec2 bro = f - vec2(1., 0.);

    float bld = dot(blr, blo);
    float tld = dot(tlr, tlo);
    float trd = dot(trr, tro);
    float brd = dot(brr, bro);

    vec2 sq = spline(f);
    float t = mix(tld, trd, sq.x);
    float b = mix(bld, brd, sq.x);
    // min: -0.5; max: 0.5
    return mix(b, t, sq.y) + 0.5;
}

float fBM(vec2 p) {
    vec2 q = p / u_scale + u_offset;
    return noise(q) / 2. +
           noise(q * 2. + 12.) / 4. +
           noise(q * 4. + 34.) / 8. +
           noise(q * 8. + 56.) / 16. +
           noise(q * 16. + 78.) / 32. +
           noise(q * 32. + 90.) / 64.;
}

float warp(vec2 p) {
    float q = fBM(p + u_inner * fBM(p));
    return fBM(p + u_warp * (-1. + 2. * q));
}

void main()
{
    // Resolution independent coordinates: 1 unit = 1 pixel at 1080p.
    vec2 p = (gl_FragCoord.xy - 0.5 * u_resolution) * (1080. / u_resolution.y);
    float c = cos(u_angle);
    float s = sin(u_angle);
    p = mat2(c, s, -s, c) * p;

    float v = warp(p);
    if (u_raw == 1) {
        fragColor = vec4(v, 0., 0., 1.);
        return;
    }

    float t = clamp((v - u_range.x) / (u_range.y - u_range.x), 0., 1.);
    vec3 col = texture(u_palette, vec2((t * 255. + 0.5) / 256., 0.5)).rgb;
    // Triangular dither against 8-bit banding.
    float d = random(gl_FragCoord.xy) + random(gl_FragCoord.yx + 17.) - 1.;
    fragColor = vec4(col + d / 255., 1.);
}
