// CRT + VHS Effects (Compatibility Mode Safe) V1
// ==== This shader has been built from various existing shader projects in addition to my own concepts.
// ==== Certain aspects have been altered to allow this to work in Godot's Compatibility Mode.
//
// ATTRIBUTION:
// Harrison Allen - CRT with Luminance Preservation - https://godotshaders.com/shader/crt-with-luminance-preservation/
// LazarusOverlook - VHS Post Processing - https://godotshaders.com/shader/vhs-post-processing/
// c64cosmin - Realistic CRT Shader - https://godotshaders.com/shader/realistic-crt-shader/

shader_type canvas_item;

// ===== Source (SubViewport texture) =====
uniform sampler2D tex: hint_screen_texture;
uniform sampler2D noise_tex: filter_nearest;

// ===== Edge pinning =====
uniform bool  edge_pinning = false; // OFF by default
uniform float edge_pin_power = 2.0; // higher = stronger pin to edges

// ===== Roll =====
uniform bool  roll = true;
uniform float roll_speed = 1.6;
uniform float roll_size = 2.0;
uniform float roll_variation = 0.919;
uniform float distort_intensity = 0.005;

// ===== Screen "breathing" (bright scenes enlarge image) =====
uniform float breathing_strength  = 0.02; // typical 0.0..0.05
uniform float breathing_softness  = 1.0;  // 0=linear, 1=smoothstep, 2=extra-smooth
uniform float breathing_bias      = 0.0;  // -0.5..0.5, shifts trigger point

// ===== VHS-style crease =====
uniform float vhs_crease_smear        = 0.2;
uniform float vhs_crease_intensity    = 0.2;
uniform float vhs_crease_jitter       = 0.10;
uniform float vhs_crease_speed        = 0.5;
uniform float vhs_crease_discolor_amt = 1.0;
uniform float vhs_bottom_thickness    = 0.025; // fraction of screen height
uniform float vhs_bottom_jitter_px    = 6.0;   // in source pixels

// ===== VHS YIQ multi-tap prefilter =====
uniform float vhs_mtap_strength = 0.0;  // 0..1 blend
uniform float vhs_chroma_twist  = 0.0;  // base I/Q rotation (radians, small)
uniform float vhs_tap_spread_px = 1.0;  // tap spacing in source pixels
uniform int   _vhs_samples       = 3;    // 2..5 taps
uniform float sparkle_intensity = 0.0;  // sparse additive luma specks (0..1)

// ===== Optics & chromatic aberration =====
uniform float optics_compensation_r = -0.01;
uniform float optics_compensation_g = 0.0;
uniform float optics_compensation_b = 0.0;
uniform float aberration = 0.0;   // small +/- x shift per channel

// ===== Discolor (sat/contrast) =====
uniform bool  discolor = false;
uniform float saturation = 0.5;    // 0..1 toward gray
uniform float contrast   = 1.2;    // >1 increases contrast

// ===== Static noise =====
uniform float static_noise_intensity: hint_range(0.0, 1.0, 0.01) = 0.02; // static noise (0..1)

// ===== Core CRT parameters =====
uniform float curve = 0.0;                 // overall optics compensation curve
uniform float aspect = 0.563;              // height/width
uniform float sharpness: hint_range(0.0, 1.0, 0.001) = 0.667;
uniform float color_offset = 0.0;
uniform float min_scanline_thickness = 0.5;
uniform float wobble_strength: hint_range(0.0, 2.0, 0.2) = 0.2;
uniform float virtual_scanlines: hint_range(240.0, 320.0, 1.0) = 320.0;   // 0 = use texture height

// Mask controls
uniform int   mask_type:           hint_range(0, 5)           = 3;     // 0=Dots,1=Aperture,2=Wide,3=WideSoft,4=Slot,5=Null
uniform float mask_brightness:     hint_range(0.0, 1.0, 0.01) = 1.0;   // preserve mask detail in brights (0..1)
uniform float scanline_brightness: hint_range(0.5, 1.0, 0.01) = 1.0;   // preserve scanline detail in brights (0.5..1)

// Vignette
uniform float vignette_intensity: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float vignette_opacity: hint_range(0.0, 1.0, 0.01)   = 0.5;

// ===== Phosphor defects =====
uniform bool  dead_cells_on = false;
uniform float dead_seed      = 1.0;
uniform float dead_cell_px   = 30.0;
uniform float dead_radius_px = 1.0;
uniform float dead_strength  = 1.0;  // 1 = fully dead

uniform bool  hot_cells_on   = false;
uniform float hot_seed       = 1.0;
uniform float hot_cell_px    = 50.0;
uniform float hot_radius_px  = 1.0;
uniform float hot_intensity  = 0.615;
uniform float hot_flicker    = 0.8;  // 0..1

varying float wobble;

// ========================= helpers =========================
void vertex() {
    // explicit 2π to avoid TAU issues in compatibility mode
    wobble = cos(TIME * 6.283185307179586 * 15.0) * wobble_strength / 4000.0;
}

// Given a normalized horizontal coordinate x01 in [0..1], return a "pin" weight
// that is 1.0 at the center (x=0.5) and falls to ~0.0 near the left/right edges.
// This is used to attenuate horizontal offsets (wobble, roll, chromatic aberration)
// so pixels don’t appear to slide beyond the bezel (physical frame).
float pin_factor(float x01) {
    float e = abs(x01 - 0.5) * 2.0; if (e < 0.0) e = 0.0; if (e > 1.0) e = 1.0;
    float f = 1.0 - e;
    return pow(f, edge_pin_power);
}

// Barrel/pincushion warp in normalized space, with aspect-correct x
// _aspect = height/width of the final display (so x is scaled to match y)
// _curve  = warp strength (>0 = barrel/curved outward, <0 = pincushion/inward)
vec2 warp_curve(vec2 uv, float _aspect, float _curve) {
    uv -= 0.5;
    uv.x /= _aspect;
    float warping = dot(uv, uv) * _curve;
    warping -= _curve * 0.25;
    uv /= (1.0 - warping);
    uv.x *= _aspect;
    uv += 0.5;
    return uv;
}

// Curve-aware radial optics compensation.
// Adds a small barrel/pincushion adjustment *on top of* the CRT curve warp,
// while taking the current curve into account so strength feels consistent
// across the screen.
vec2 optics_comp_curved(vec2 uv, float amount, float _aspect, float _curve) {
    vec2 d = uv - 0.5;
    vec2 e = d; e.x /= _aspect;
    float dist2 = dot(e, e);
    float denom = 1.0 - (dist2 * _curve - _curve * 0.25);
    if (denom < 0.2) denom = 0.2;
    float gain = 1.0 / denom;
    return uv + d * dist2 * amount * gain;
}

// Tiny, deterministic 2D hash → pseudo-random vec2 in [-1, +1].
// - Input: any 2D coordinate (UVs, pixel coords, grid id, etc.).
// - Process: project uv onto two different directions (dot with fixed
//   vectors) to decorrelate x/y, run a sine “hash” and keep the fractional
//   part, then remap from [0,1] to [-1,1].
vec2 rnd_hash(vec2 uv) {
    uv = vec2(dot(uv, vec2(127.1, 311.7)),
              dot(uv, vec2(269.5, 183.3)));
    uv = -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
	return texture(noise_tex, uv).rg * 2.0 - 1.0;
}
float rnd1(vec2 uv) { return rnd_hash(uv).x * 0.5 + 0.5; }

// Rounded-edge border matte in [0,1]:
// - Returns ~1.0 for pixels well inside the screen area and fades to 0.0
//   near/over the edges, creating a soft bezel/overscan falloff.
// - Uses a rounded-rectangle signed distance approximation so the corners
//   are gently curved instead of perfectly sharp.
// - 'curve' (global) controls the corner radius / softness coupling.
float border_mask(vec2 uv) {
    float r = curve; if (r > 0.08) r = 0.08; if (r < 1e-5) r = 1e-5;
    vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0) + r;
    float dist = length(max(vec2(0.0), abs_uv)) / r;
    float sq = smoothstep(0.96, 1.0, dist);
    float outv = 1.0 - sq; if (outv < 0.0) outv = 0.0; if (outv > 1.0) outv = 1.0;
    return outv;
}

// Vignette factor in [0,1] with a center peak and edge falloff.
// - uv:     normalized coords *after* warp/optics (so the vignette follows any bend).
// - intensity: controls how tight/steep the falloff is (larger → darker corners).
// - opac:   additional overall strength multiplier (acts with intensity as a product).
float vignette_fac(vec2 uv, float intensity, float opac) {
    vec2 u = uv; u *= 1.0 - u;
    float v = u.x * u.y * 15.0;
    v = pow(v, intensity * opac);
    return v;
}

// Piecewise-accurate sRGB <-> linear conversion.
vec3 linear_to_srgb(vec3 col) {
    bvec3 cut = lessThan(col, vec3(0.0031318));
    vec3 a = (pow(col, vec3(1.0 / 2.4)) * 1.055) - 0.055;
    vec3 b = col * 12.92;
    return mix(a, b, cut);
}
vec3 srgb_to_linear(vec3 col) {
    bvec3 cut = lessThan(col, vec3(0.04045));
    vec3 a = pow((col + 0.055) / 1.055, vec3(2.4));
    vec3 b = col / 12.92;
    return mix(a, b, cut);
}

// --- YIQ helpers (mat3 columns) ---
vec3 rgb2yiq(vec3 rgb) {
    mat3 M = mat3(
        vec3(0.299,  0.596,  0.211),
        vec3(0.587, -0.274, -0.523),
        vec3(0.114, -0.322,  0.312)
    );
    return M * rgb;
}
vec3 yiq2rgb(vec3 yiq) {
    mat3 M = mat3(
        vec3(1.0,   1.0,    1.0),
        vec3(0.956, -0.272, -1.106),
        vec3(0.621, -0.647,  1.703)
    );
    return M * yiq;
}
vec3 rotate_iq(vec3 yiq, float rot) {
    float c = cos(rot);
    float s = sin(rot);
    float I2 = yiq.g * c - yiq.b * s;
    float Q2 = yiq.g * s + yiq.b * c;
    return vec3(yiq.r, I2, Q2);
}

// ====== Global-average luma (8 point sample; center excluded) for breathing ======
float global_avg_luma() {
    vec3 c1 = srgb_to_linear(texture(tex, vec2(0.2, 0.2)).rgb);
    vec3 c2 = srgb_to_linear(texture(tex, vec2(0.5, 0.2)).rgb);
    vec3 c3 = srgb_to_linear(texture(tex, vec2(0.8, 0.2)).rgb);
    vec3 c4 = srgb_to_linear(texture(tex, vec2(0.2, 0.5)).rgb);
    vec3 c5 = srgb_to_linear(texture(tex, vec2(0.8, 0.5)).rgb);
    vec3 c6 = srgb_to_linear(texture(tex, vec2(0.2, 0.8)).rgb);
    vec3 c7 = srgb_to_linear(texture(tex, vec2(0.5, 0.8)).rgb);
    vec3 c8 = srgb_to_linear(texture(tex, vec2(0.8, 0.8)).rgb);
    float y1 = dot(c1, vec3(0.2126, 0.7152, 0.0722));
    float y2 = dot(c2, vec3(0.2126, 0.7152, 0.0722));
    float y3 = dot(c3, vec3(0.2126, 0.7152, 0.0722));
    float y4 = dot(c4, vec3(0.2126, 0.7152, 0.0722));
    float y5 = dot(c5, vec3(0.2126, 0.7152, 0.0722));
    float y6 = dot(c6, vec3(0.2126, 0.7152, 0.0722));
    float y7 = dot(c7, vec3(0.2126, 0.7152, 0.0722));
    float y8 = dot(c8, vec3(0.2126, 0.7152, 0.0722));
    return (y1+y2+y3+y4+y5+y6+y7+y8) / 8.0;
}

// ====== Phosphor defect helpers ======
float _rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}
vec2 _rand2(vec2 p) {
    return vec2(_rand(p + vec2(1.7, 9.2)), _rand(p + vec2(8.3, 2.8)));
}
// Channel selection per cell (7 possible combos: R,G,B,RG,RB,GB,RGB)
vec3 _cell_channel_mask(vec2 cell, float seed) {
    float r = _rand(cell + vec2(seed * 5.1, seed * 7.3));
    int idx = int(floor(r * 7.0));
    vec3 m = vec3(0.0);
    if (idx == 0) m = vec3(1.0, 0.0, 0.0);
    else if (idx == 1) m = vec3(0.0, 1.0, 0.0);
    else if (idx == 2) m = vec3(0.0, 0.0, 1.0);
    else if (idx == 3) m = vec3(1.0, 1.0, 0.0);
    else if (idx == 4) m = vec3(1.0, 0.0, 1.0);
    else if (idx == 5) m = vec3(0.0, 1.0, 1.0);
    else               m = vec3(1.0, 1.0, 1.0);
    return m;
}
// Fixed-sparsity spawn (~1%) with soft circular coverage
float _defect_weight(vec2 frag_px, float cell_px, float seed, float radius_px) {
    vec2 cell = floor(frag_px / cell_px);
    float r = _rand(cell + vec2(seed, seed * 1.31));
    float spawn = step(0.99, r); // ~1% of cells
    vec2 ofs = _rand2(cell + vec2(seed * 2.11, -seed * 4.27));
    vec2 center = (cell + ofs) * cell_px;
    float d = length(frag_px - center);
    float aa = 1.0;
    float gate = 1.0 - smoothstep(radius_px, radius_px + aa, d);
    return gate * spawn;
}

// --------- scanline kernel (linear) with pre-defect (mul/add) ---------
vec3 scanlines(vec2 uv, vec3 pre_mul, vec3 pre_add) {
    vec2 uv0 = uv;
    vec2 tex_size = vec2(textureSize(tex, 0));
    vec2 uv_px = uv * tex_size;

    int   y = int(floor(uv_px.y - 0.5));
    float x = floor(uv_px.x);

    float ax = x - 2.0;
    float bx = x - 1.0;
    float cx = x;
    float dx = x + 1.0;
    float ex = x + 2.0;

    vec3 upper_a = texelFetch(tex, ivec2(int(ax), y), 0).rgb;
    vec3 upper_b = texelFetch(tex, ivec2(int(bx), y), 0).rgb;
    vec3 upper_c = texelFetch(tex, ivec2(int(cx), y), 0).rgb;
    vec3 upper_d = texelFetch(tex, ivec2(int(dx), y), 0).rgb;
    vec3 upper_e = texelFetch(tex, ivec2(int(ex), y), 0).rgb;

    y += 1;

    vec3 lower_a = texelFetch(tex, ivec2(int(ax), y), 0).rgb;
    vec3 lower_b = texelFetch(tex, ivec2(int(bx), y), 0).rgb;
    vec3 lower_c = texelFetch(tex, ivec2(int(cx), y), 0).rgb;
    vec3 lower_d = texelFetch(tex, ivec2(int(dx), y), 0).rgb;
    vec3 lower_e = texelFetch(tex, ivec2(int(ex), y), 0).rgb;

    upper_a = srgb_to_linear(upper_a);
    upper_b = srgb_to_linear(upper_b);
    upper_c = srgb_to_linear(upper_c);
    upper_d = srgb_to_linear(upper_d);
    upper_e = srgb_to_linear(upper_e);

    lower_a = srgb_to_linear(lower_a);
    lower_b = srgb_to_linear(lower_b);
    lower_c = srgb_to_linear(lower_c);
    lower_d = srgb_to_linear(lower_d);
    lower_e = srgb_to_linear(lower_e);

    // Apply phosphor defects BEFORE shaping
    upper_a = clamp(upper_a * pre_mul + pre_add, 0.0, 1.0);
    upper_b = clamp(upper_b * pre_mul + pre_add, 0.0, 1.0);
    upper_c = clamp(upper_c * pre_mul + pre_add, 0.0, 1.0);
    upper_d = clamp(upper_d * pre_mul + pre_add, 0.0, 1.0);
    upper_e = clamp(upper_e * pre_mul + pre_add, 0.0, 1.0);

    lower_a = clamp(lower_a * pre_mul + pre_add, 0.0, 1.0);
    lower_b = clamp(lower_b * pre_mul + pre_add, 0.0, 1.0);
    lower_c = clamp(lower_c * pre_mul + pre_add, 0.0, 1.0);
    lower_d = clamp(lower_d * pre_mul + pre_add, 0.0, 1.0);
    lower_e = clamp(lower_e * pre_mul + pre_add, 0.0, 1.0);

    vec3 beam = vec3(uv_px.x - 0.5);
    beam.r -= color_offset;
    beam.b += color_offset;

    vec3 weight_a = smoothstep(1.0, 0.0, (beam - ax) * sharpness);
    vec3 weight_b = smoothstep(1.0, 0.0, (beam - bx) * sharpness);
    vec3 weight_c = smoothstep(1.0, 0.0, abs(beam - cx) * sharpness);
    vec3 weight_d = smoothstep(1.0, 0.0, (dx - beam) * sharpness);
    vec3 weight_e = smoothstep(1.0, 0.0, (ex - beam) * sharpness);

    vec3 upper_col = upper_a * weight_a +
                     upper_b * weight_b +
                     upper_c * weight_c +
                     upper_d * weight_d +
                     upper_e * weight_e;

    vec3 lower_col = lower_a * weight_a +
                     lower_b * weight_b +
                     lower_c * weight_c +
                     lower_d * weight_d +
                     lower_e * weight_e;

    vec3 weight_scaler = vec3(1.0) / (weight_a + weight_b + weight_c + weight_d + weight_e);
    upper_col *= weight_scaler;
    lower_col *= weight_scaler;

    upper_col *= scanline_brightness;
    lower_col *= scanline_brightness;

    vec3 upper_thickness = mix(vec3(min_scanline_thickness), vec3(1.0), upper_col);
    vec3 lower_thickness = mix(vec3(min_scanline_thickness), vec3(1.0), lower_col);

    float lines = vec2(textureSize(tex, 0)).y;
    if (virtual_scanlines > 0.0) {
        lines = virtual_scanlines;
    }
    float saw = fract(uv0.y * lines + 0.5);

    vec3 upper_line = vec3(saw) / upper_thickness;
    upper_line = smoothstep(1.0, 0.0, upper_line);

    vec3 lower_line = vec3(1.0 - saw) / lower_thickness;
    lower_line = smoothstep(1.0, 0.0, lower_line);

    upper_line *= upper_col / upper_thickness;
    lower_line *= lower_col / lower_thickness;

    vec3 combined = upper_line + lower_line;

    vec3 dark_upper = smoothstep(min_scanline_thickness, 0.0, vec3(saw)) * upper_col;
    vec3 dark_lower = smoothstep(min_scanline_thickness, 0.0, vec3(1.0 - saw)) * lower_col;
    vec3 dark_combined = dark_upper + dark_lower;

    float w = 0.9 + 0.1 * clamp(scanline_brightness, 0.0, 1.0);
    return mix(dark_combined, combined, w);
}

// ===== VHS multi-tap prefilter (2..5 taps) =====
vec3 vhs_prefilter_ntap(vec2 uv, float twist, float tap_px, int samples_) {
    vec2 ts = vec2(textureSize(tex, 0)); if (ts.x < 1.0) return vec3(0.0);
    float dx = tap_px / ts.x; vec2 duv = vec2(dx, 0.0);

    vec3 s0 = srgb_to_linear(texture(tex, uv                 ).rgb);
    vec3 s1 = srgb_to_linear(texture(tex, uv - duv           ).rgb);
    vec3 s2 = srgb_to_linear(texture(tex, uv - duv * 2.0     ).rgb);
    vec3 s3 = srgb_to_linear(texture(tex, uv - duv * 3.0     ).rgb);
    vec3 s4 = srgb_to_linear(texture(tex, uv - duv * 4.0     ).rgb);

    vec3 y0 = rgb2yiq(s0), y1 = rgb2yiq(s1), y2 = rgb2yiq(s2), y3 = rgb2yiq(s3), y4 = rgb2yiq(s4);

    float Y=0.0, I=0.0, Q=0.0;
    int n = samples_; if (n < 2) n = 2; if (n > 5) n = 5;

    if (n == 2) {
        float wy0=0.60, wy1=0.40, wc0=0.50, wc1=0.50;
        Y = y0.r*wy0 + y1.r*wy1; I = y0.g*wc0 + y1.g*wc1; Q = y0.b*wc0 + y1.b*wc1;
    } else if (n == 3) {
        float wy0=0.50, wy1=0.30, wy2=0.20; float wc0=0.45, wc1=0.33, wc2=0.22;
        Y = y0.r*wy0 + y1.r*wy1 + y2.r*wy2;
        I = y0.g*wc0 + y1.g*wc1 + y2.g*wc2;
        Q = y0.b*wc0 + y1.b*wc1 + y2.b*wc2;
    } else if (n == 4) {
        float wy0=0.42, wy1=0.28, wy2=0.18, wy3=0.12; float wc0=0.40, wc1=0.26, wc2=0.20, wc3=0.14;
        Y = y0.r*wy0 + y1.r*wy1 + y2.r*wy2 + y3.r*wy3;
        I = y0.g*wc0 + y1.g*wc1 + y2.g*wc2 + y3.g*wc3;
        Q = y0.b*wc0 + y1.b*wc1 + y2.b*wc2 + y3.b*wc3;
    } else {
        float wy0=0.40, wy1=0.25, wy2=0.15, wy3=0.12, wy4=0.08;
        float wc0=0.25, wc1=0.23, wc2=0.20, wc3=0.18, wc4=0.14;
        Y = y0.r*wy0 + y1.r*wy1 + y2.r*wy2 + y3.r*wy3 + y4.r*wy4;
        I = y0.g*wc0 + y1.g*wc1 + y2.g*wc2 + y3.g*wc3 + y4.g*wc4;
        Q = y0.b*wc0 + y1.b*wc1 + y2.b*wc2 + y3.b*wc3 + y4.b*wc4;
    }

    vec3 yiq = vec3(Y, I, Q);
    if (twist != 0.0) yiq = rotate_iq(yiq, twist);

    // Sparkle
    if (sparkle_intensity > 0.0) {
        vec2 g = floor(uv * ts);
        float nsp = rnd1(g + vec2(TIME * 7.173, 3.31));
        if (nsp > 0.995) {
            float s = (nsp - 0.995) * 200.0; if (s > 1.0) s = 1.0;
            yiq.r += s * sparkle_intensity;
        }
    }

    vec3 rgb = yiq2rgb(yiq);
    if (rgb.r < 0.0) rgb.r = 0.0; if (rgb.r > 1.0) rgb.r = 1.0;
    if (rgb.g < 0.0) rgb.g = 0.0; if (rgb.g > 1.0) rgb.g = 1.0;
    if (rgb.b < 0.0) rgb.b = 0.0; if (rgb.b > 1.0) rgb.b = 1.0;
    return rgb;
}


// ----- Mask patterns -----
vec3 _pick4(int idx, vec3 a, vec3 b, vec3 c, vec3 d) {
    if (idx == 0) return a;
    if (idx == 1) return b;
    if (idx == 2) return c;
    return d;
}
vec3 _slot_color(int idx) {
    if (idx == 0)  return vec3(1,0,1);
    if (idx == 1)  return vec3(0,1,0);
    if (idx == 2)  return vec3(1,0,1);
    if (idx == 3)  return vec3(0,1,0);
    if (idx == 4)  return vec3(0,0,1);
    if (idx == 5)  return vec3(0,1,0);
    if (idx == 6)  return vec3(1,0,0);
    if (idx == 7)  return vec3(0,0,0);
    if (idx == 8)  return vec3(1,0,1);
    if (idx == 9)  return vec3(0,1,0);
    if (idx == 10) return vec3(1,0,1);
    if (idx == 11) return vec3(0,1,0);
    if (idx == 12) return vec3(1,0,0);
    if (idx == 13) return vec3(0,0,0);
    if (idx == 14) return vec3(0,0,1);
    return vec3(0,1,0);
}
vec4 generate_mask(vec2 fragcoord) {
    int mx = mask_type;
    if (mx == 0) {
        ivec2 ico = ivec2(floor(fragcoord));
        int idx = (ico.y * 2 + ico.x) % 4;
        vec3 c = _pick4(idx, vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0,0,0));
        return vec4(c, 0.25);
    } else if (mx == 1) {
        int idx = int(floor(fragcoord.x)) % 2;
        vec3 c = vec3(0.0);
        if (idx == 0) c = vec3(0,1,0);
        else          c = vec3(1,0,1);
        return vec4(c, 0.5);
    } else if (mx == 2) {
        int idx = int(floor(fragcoord.x)) % 4;
        vec3 c = _pick4(idx, vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0,0,0));
        return vec4(c, 0.25);
    } else if (mx == 3) {
        int idx = int(floor(fragcoord.x)) % 4;
        vec3 c = _pick4(idx,
            vec3(1.0, 0.125, 0.0),
            vec3(0.125, 1.0, 0.125),
            vec3(0.0, 0.125, 1.0),
            vec3(0.125, 0.0, 0.125)
        );
        return vec4(c, 0.3125);
    } else if (mx == 4) {
        ivec2 ico = ivec2(floor(fragcoord));
        int ix = ico.x % 4;
        int iy = ico.y % 4;
        int idx = iy * 4 + ix;
        vec3 c = _slot_color(idx);
        return vec4(c, 0.375);
    } else {
        return vec4(0.5);
    }
}
vec3 apply_mask(vec3 linear_color, vec2 fragcoord) {
    vec4 m = generate_mask(fragcoord);
    float dim = m.w + (1.0 - m.w) * mask_brightness;
    linear_color *= dim;

    vec3 target = linear_color / m.w;
    vec3 primary = clamp(target, 0.0, 1.0);

    vec3 highlights = target - primary;
    highlights /= (1.0 / m.w - 1.0);

    primary *= m.rgb;
    primary += highlights * (1.0 - m.rgb);
    return primary;
}

// ========================= main =========================
void fragment() {
    // Overall optics compensation curve
    vec2 uv = warp_curve(UV, aspect, curve * 0.5);

    // Wobble; optionally pin edges
    float pin = 1.0;
    if (edge_pinning) { pin = pin_factor(UV.x); }
    uv.x += wobble * pin;

    // Roll / scan
    float dx = 0.0;
    if (roll) {
        float t = TIME;
        float l1 = sin(UV.y * roll_size - (t * roll_speed)); l1 = smoothstep(0.3, 0.9, l1); l1 *= l1;
        float l2 = sin(UV.y * roll_size * roll_variation - (t * roll_speed * roll_variation)); l2 = smoothstep(0.3, 0.9, l2);
        dx = l1 * l2 * distort_intensity;
        if (edge_pinning) { dx *= pin; }
    }
    vec2 base_uv = uv + vec2(dx, 0.0);

    // ===== Breathing (bright scenes enlarge image) with softness & bias =====
    if (breathing_strength != 0.0) {
        float L = global_avg_luma();
        L = clamp(L + breathing_bias, 0.0, 1.0); // shift trigger
        float s1 = L*L*(3.0 - 2.0*L);            // smoothstep
        float s2 = s1*s1*(3.0 - 2.0*s1);         // extra smooth
        float t  = breathing_softness; if (t < 0.0) t = 0.0; if (t > 2.0) t = 2.0;
        float e  = mix(L, s1, min(t, 1.0));
        e        = mix(e, s2, max(t - 1.0, 0.0));
        float b_scale = 1.0 + breathing_strength * e;
        vec2 d = base_uv - 0.5;
        base_uv = 0.5 + d / b_scale;
    }

    // ===== VHS crease =====
    float jitter_phase = rnd1(vec2(TIME * 0.67, TIME * 0.59)) * 2.0 - 1.0;
    float tc_phase = sin(base_uv.y * 8.0 - (TIME * vhs_crease_speed + vhs_crease_jitter * jitter_phase) * 3.769911184);
    tc_phase = smoothstep(0.9, 0.96, tc_phase);
    float tc_noise = smoothstep(0.3, 1.0, rnd1(vec2(base_uv.y * 4.77, TIME)));
    float tc = tc_phase * tc_noise * vhs_crease_intensity;

    vec2 tsz = vec2(textureSize(tex, 0));
    float smear_dx = (8.0 * vhs_crease_smear) / max(tsz.x, 1.0);
    base_uv.x -= tc * smear_dx;

    float sn_phase = smoothstep(1.0 - vhs_bottom_thickness, 1.0, base_uv.y);
    float sn_jit = (rnd1(vec2(UV.y * 100.0, TIME * 10.0)) - 0.5) * (vhs_bottom_jitter_px / max(tsz.x, 1.0));
    base_uv.x += sn_phase * sn_jit;

    // ===== Phosphor defects =====
    vec3 pre_mul = vec3(1.0);
    vec3 pre_add = vec3(0.0);
    vec2 frag_px = FRAGCOORD.xy;

    if (dead_cells_on) {
        float w_dead = _defect_weight(frag_px, dead_cell_px, dead_seed, dead_radius_px);
        if (w_dead > 0.0) {
            vec2 cell_d = floor(frag_px / dead_cell_px);
            vec3 m_dead = _cell_channel_mask(cell_d, dead_seed);
            vec3 delta = m_dead * (w_dead * dead_strength);
            pre_mul = pre_mul - delta;
            if (pre_mul.r < 0.0) pre_mul.r = 0.0;
            if (pre_mul.g < 0.0) pre_mul.g = 0.0;
            if (pre_mul.b < 0.0) pre_mul.b = 0.0;
        }
    }
    if (hot_cells_on) {
        float w_hot = _defect_weight(frag_px, hot_cell_px, hot_seed, hot_radius_px);
        if (w_hot > 0.0) {
            vec2 cell_h = floor(frag_px / hot_cell_px);
            float rf = _rand(cell_h + vec2(hot_seed * 9.7, TIME * 0.37));
            float flick = (1.0 - hot_flicker) + hot_flicker * rf;
            vec3 m_hot = _cell_channel_mask(cell_h, hot_seed);
            vec3 addv  = m_hot * (w_hot * hot_intensity * flick);
            pre_add = pre_add + addv;
            if (pre_add.r > 1.0) pre_add.r = 1.0;
            if (pre_add.g > 1.0) pre_add.g = 1.0;
            if (pre_add.b > 1.0) pre_add.b = 1.0;
        }
    }

    // ===== Optics per channel + chromatic aberration (curve-aware) =====
    vec2 uv_r = optics_comp_curved(base_uv, optics_compensation_r, aspect, curve);
    vec2 uv_g = optics_comp_curved(base_uv, optics_compensation_g, aspect, curve);
    vec2 uv_b = optics_comp_curved(base_uv, optics_compensation_b, aspect, curve);

    float ca = aberration * 0.1; if (edge_pinning) { ca *= pin; }
    uv_r += vec2( ca, 0.0);
    uv_g += vec2(-ca, 0.0);

    // ===== CRT scanline kernel per channel (linear) with pre-defects =====
    vec3 col_r = scanlines(uv_r, pre_mul, pre_add);
    vec3 col_g = scanlines(uv_g, pre_mul, pre_add);
    vec3 col_b = scanlines(uv_b, pre_mul, pre_add);
    vec3 col   = vec3(col_r.r, col_g.g, col_b.b);

    // ===== VHS multi-tap prefilter blend (uses crease chroma twist) =====
    if (vhs_mtap_strength > 0.0) {
        float crease_rot = (tc_phase * 0.2 + sn_phase * 2.0) * vhs_crease_discolor_amt;
        float total_twist = vhs_chroma_twist + crease_rot;
        vec3 vhs_col = vhs_prefilter_ntap(base_uv, total_twist, vhs_tap_spread_px, _vhs_samples);
        col = mix(col, vhs_col, vec3(vhs_mtap_strength));
    }

    // ===== Optional discolor (linear) =====
    if (discolor) {
        float gray = (col.r + col.g + col.b) / 3.0;
        col = mix(col, vec3(gray), vec3(saturation));
        float midpoint = pow(0.5, 2.2);
        col = (col - vec3(midpoint)) * contrast + vec3(midpoint);
    }

    // ===== Phosphor mask (linear) =====
    col = apply_mask(col, FRAGCOORD.xy);

    // ===== Static noise (linear) =====
    if (static_noise_intensity > 0.0) {
        vec2 uv_avg = (uv_r + uv_g + uv_b) / 3.0;
        vec2 tsz2 = vec2(textureSize(tex, 0));
        vec2 cell = ceil(uv_avg * tsz2) / tsz2;
        float r = rnd_hash(cell + fract(TIME)).x; if (r < 0.0) r = 0.0; if (r > 1.0) r = 1.0;
        col += vec3(r) * static_noise_intensity;
        col = clamp(col, vec3(0.0), vec3(1.0));
    }

    // ===== Vignette (linear) =====
    vec2 uv_avg2 = (uv_r + uv_g + uv_b) / 3.0;
    float border = border_mask(uv_avg2); col *= border;
    float vig = vignette_fac(uv_avg2, vignette_intensity, vignette_opacity); col *= vig;

    // Convert to sRGB
    col = linear_to_srgb(col);
    COLOR.rgb = col; COLOR.a = 1.0;
}
