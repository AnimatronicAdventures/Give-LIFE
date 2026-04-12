shader_type canvas_item;

// ── TUNEABLE CONSTANTS ────────────────────────────────────────────────────

// How many scanlines tall the image is
uniform float SCANLINE_COUNT     : hint_range(10.0, 300.0) = 70.0;

// Minimum black bar height (fraction of one scanline band, 0..1)
uniform float BAR_MIN            : hint_range(0.0,  1.0)   = 0.1;

// Maximum black bar height (fraction of one scanline band, 0..1)
// Set > 1.0 to let tall ridges eat into the band above
uniform float BAR_MAX            : hint_range(0.0,  4.0)   = 1.8;

// Horizontal scale of the noise (higher = wider ridge clusters)
uniform float NOISE_SCALE_X      : hint_range(0.1, 16.0)   = 3.5;

// Vertical scale of the noise (higher = taller/chunkier clusters)
uniform float NOISE_SCALE_Y      : hint_range(0.1, 16.0)   = 2.5;

// How fast the noise field scrolls downward
uniform float SCROLL_SPEED       : hint_range(0.0,  8.0)   = 0.6;

// How fast the noise field drifts horizontally
uniform float DRIFT_SPEED        : hint_range(0.0,  4.0)   = 0.15;

// Sharpness of the noise → bar height mapping
// 1.0 = linear, >1 = more contrast (snappier ridges)
uniform float NOISE_CONTRAST     : hint_range(0.5,  6.0)   = 2.2;

// Random speckle on the bright gaps (0=clean, 1=dense static)
uniform float NOISE_DENSITY      : hint_range(0.0,  1.0)   = 0.4;

// Foreground colour
uniform vec4  COLOR_FG           : source_color             = vec4(0.93, 0.95, 0.0, 1.0);

// Background colour
uniform vec4  COLOR_BG           : source_color             = vec4(0.0,  0.0,  0.0,  1.0);

// ── NOISE ─────────────────────────────────────────────────────────────────

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

// Bilinear value noise — smooth, low-frequency blobs
float vnoise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);   // smoothstep

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Two-octave FBM for a bit of fine detail on top of the broad shapes
float fbm(vec2 p) {
    float v  = vnoise2(p)        * 0.65;
          v += vnoise2(p * 2.1 + vec2(3.7, 1.4)) * 0.25;
          v += vnoise2(p * 4.3 + vec2(1.1, 5.2)) * 0.10;
    return v;
}

// ── MAIN ──────────────────────────────────────────────────────────────────

void fragment() {
    vec2 uv = UV;

    // ── 1. SCANLINE BAND ──────────────────────────────────────────────────
    float y_f      = uv.y * SCANLINE_COUNT + TIME * SCROLL_SPEED;
    float row      = floor(y_f);          // which scanline band
    float band_frc = fract(y_f);          // 0=top of band, 1=bottom

    // ── 2. SAMPLE NOISE AT THIS (X, ROW) ─────────────────────────────────
    // X coord scaled so ridges are wide; row coord scaled so ridges are chunky.
    // Both scroll/drift over time.
    vec2 noise_uv = vec2(
        uv.x   * NOISE_SCALE_X + TIME * DRIFT_SPEED,
        row     / NOISE_SCALE_Y + TIME * SCROLL_SPEED * 0.05
    );

    float n = fbm(noise_uv);              // 0..1, smooth blobs

    // Apply contrast curve: pow pushes mid-values toward extremes
    n = pow(clamp(n, 0.0, 1.0), NOISE_CONTRAST);

    // ── 3. BAR HEIGHT FROM NOISE ──────────────────────────────────────────
    // n=0 → bar_height=BAR_MIN (thin black bar, lots of bright gap)
    // n=1 → bar_height=BAR_MAX (tall black bar, little/no bright gap)
    float bar_h = mix(BAR_MIN, BAR_MAX, n);

    // The black bar sits at the TOP of the band (band_frc=0).
    // The bright gap is whatever is left at the BOTTOM.
    // pixel is BRIGHT if band_frc > bar_h
    float bright = step(bar_h, band_frc);

    // ── 4. SPECKLE ────────────────────────────────────────────────────────
    vec2 px  = floor(FRAGCOORD.xy);
    float nt = floor(TIME * 15.0);
    float sp = hash(px + vec2(nt * 7.3, nt * 3.1));

    // Carve holes in bright areas AND add dots in dark areas
    float kill     = step(NOISE_DENSITY, sp);           // 0 = kill bright pixel
    float add_dot  = step(1.0 - NOISE_DENSITY * 0.5, sp); // 1 = add bright dot in dark

    float lit = max(bright * kill, (1.0 - bright) * add_dot);

    COLOR = mix(COLOR_BG, COLOR_FG, lit);
}
