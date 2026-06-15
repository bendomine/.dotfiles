vec4 colormap(float x) {
    return vec4(clamp(x, 0.0, 1.0), clamp(0.5 * x + 0.5, 0.0, 1.0), 0.4, 1.0);
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}
vec2 grad(vec2 p) {
    //return normalize(vec2(random(p), random(p + vec2(12, 34))) * 2. - 1.);
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
    //return mix(b, t, sq.y) / 0.707 / 0.5 + 0.5;
    // min: -0.5; max: 0.5
    return mix(b, t, sq.y) + 0.5;
}

float fBM(vec2 p){
    float size = 300.;
    return noise(p / size) / 2. +
           noise(p / size * 2. + 12.) / 4. +
           noise(p / size * 4. + 34.) / 8. +
           noise(p / size * 8. + 56.) / 16. +
           noise(p / size * 16. + 78.) / 32. +
           noise(p / size * 32. + 90.) / 64.;
}

float warp(vec2 p) {
    return fBM(p + vec2(500. * (-1. + 2. * fBM(p + 500. * fBM(p))),
                       -200. * (-1. + 2. * fBM(p + 500. * fBM(p)))));
}

void main()
{
    gl_FragColor = colormap(warp(gl_FragCoord.xy));
}