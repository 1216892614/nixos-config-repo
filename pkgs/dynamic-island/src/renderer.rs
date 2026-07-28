//! CPU renderer: capsule SDF + frosted glass with real background capture.
//! Produces raw ARGB8888 pixel buffer for Wayland shm submission.
//!
//! When a captured background is available, it's used as the base for the
//! glass effect (blur + tint + rim light + specular). Otherwise falls back
//! to the synthetic radial gradient simulation.

use fontdue::{Font, FontSettings};

use crate::config::Config;
/// Parsed RGBA color for pixel math
#[derive(Clone, Copy)]
pub struct Rgba {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
}

impl Rgba {
    pub fn from_hex(hex: &str) -> Self {
        let c = Config::parse_color(hex);
        Self { r: c[0], g: c[1], b: c[2], a: c[3] }
    }

    fn to_premul_u8(self, alpha: f32) -> [u8; 4] {
        let a = (self.a * alpha).clamp(0.0, 1.0);
        let r = (self.r * a * 255.0) as u8;
        let g = (self.g * a * 255.0) as u8;
        let b = (self.b * a * 255.0) as u8;
        let a8 = (a * 255.0) as u8;
        [r, g, b, a8]
    }
}

pub struct Renderer {
    font: Font,
    /// Current pixel buffer dimensions
    pub width: u32,
    pub height: u32,
}

impl Renderer {
    pub fn new(font_data: &[u8]) -> Self {
        let font = Font::from_bytes(font_data, FontSettings::default())
            .expect("failed to parse font");
        Self {
            font,
            width: 140,
            height: 36,
        }
    }

    pub fn resize(&mut self, w: u32, h: u32) {
        self.width = w;
        self.height = h;
    }

    /// Render the island pill/card shape.
    /// Produces ARGB8888 premultiplied buffer (Wayland byte order: B, G, R, A).
    /// The surface is semi-transparent; niri's liquid-glass layer-rule
    /// provides the frosted glass background compositing.
    pub fn render(
        &self,
        config: &Config,
        text: &str,
        width: u32,
        height: u32,
        corner_radius: f32,
        opacity_center: f32,
        glow_intensity: f32,
    ) -> Vec<u8> {
        let w = width as usize;
        let h = height as usize;
        let mut buf = vec![0u8; w * h * 4];

        let bg = Rgba::from_hex(&config.colors.bg);
        let accent = Rgba::from_hex(&config.colors.accent);
        let text_color = Rgba::from_hex(&config.colors.text);

        let wf = w as f32;
        let hf = h as f32;
        let r = corner_radius;

        // Gradient center: offset left-up to push transparency toward bottom-right
        let cx = wf * 0.38;
        let cy = hf * 0.32;

        // Specular highlight: a diagonal band simulating glass reflection
        // Direction vector (normalized): ~30° from horizontal
        let spec_angle: f32 = 0.52; // radians (~30°)
        let spec_cos = spec_angle.cos();
        let spec_sin = spec_angle.sin();
        // Band center offset (relative to pill center)
        let spec_offset = wf * 0.15;

        // Pass 1: SDF-based glass compositing
        for py in 0..h {
            for px in 0..w {
                let x = px as f32;
                let y = py as f32;

                // Capsule/rounded-rect SDF: 0 at center, 1 at boundary, >1 outside
                let sdf = rounded_rect_sdf(x, y, wf, hf, r);

                if sdf > 1.05 {
                    // Outside shape — fully transparent
                    continue;
                }

                // ── Anti-aliased edge mask ──
                // sdf=1 is boundary; feather over ~1.5px
                let edge_mask = (1.0 - (sdf - 1.0) * r.max(8.0)).clamp(0.0, 1.0);

                // ── Radial gradient: dark center → transparent edge ──
                let dx = (x - cx) / (wf * 0.55);
                let dy = (y - cy) / (hf * 0.55);
                let dist = (dx * dx + dy * dy).sqrt().min(1.0);
                // Quadratic falloff: center=opacity_center, edge≈0.08
                let base_alpha = lerp(opacity_center, 0.06, dist * dist);

                // ── Edge rim-light (refraction glow) ──
                // Strongest at sdf ∈ [0.75, 1.0]
                let rim = if sdf > 0.70 && sdf <= 1.0 {
                    let t = (sdf - 0.70) / 0.30;
                    // Bell curve: peak at boundary
                    let bell = (t * std::f32::consts::PI).sin();
                    bell * glow_intensity * 0.45
                } else {
                    0.0
                };

                // ── Specular highlight band ──
                // Project pixel onto the specular direction
                let rel_x = x - wf * 0.5;
                let rel_y = y - hf * 0.5;
                let proj = rel_x * spec_sin - rel_y * spec_cos + spec_offset;
                let spec_width = wf * 0.08;
                let spec = if proj.abs() < spec_width && sdf < 0.9 {
                    let t = 1.0 - (proj.abs() / spec_width);
                    // Fade with distance from center (stronger near top-left)
                    let fade = (1.0 - dist * 0.8).max(0.0);
                    t * t * fade * 0.12
                } else {
                    0.0
                };

                // ── Noise grain (deterministic hash) ──
                let grain = pixel_hash(px as u32, py as u32);
                let grain_amount = 0.015 * (1.0 - dist * 0.5); // less grain at edges

                // ── Chromatic aberration near edges ──
                // Slight RGB channel shift: red shifts outward, blue inward
                let chroma = if sdf > 0.5 && sdf <= 1.0 {
                    (sdf - 0.5) * 0.06
                } else {
                    0.0
                };

                // ── Composite final color ──
                // Surface is a semi-transparent dark shape; niri liquid-glass
                // composites the frosted background behind our alpha channel.
                let (base_r, base_g, base_b) = (bg.r, bg.g, bg.b);

                let r_out = base_r * (1.0 - rim - spec) + accent.r * rim + 1.0 * spec + grain * grain_amount + chroma * 0.5;
                let g_out = base_g * (1.0 - rim - spec) + accent.g * rim + 1.0 * spec + grain * grain_amount;
                let b_out = base_b * (1.0 - rim - spec) + accent.b * rim + 1.0 * spec + grain * grain_amount - chroma * 0.3;

                let final_alpha = (edge_mask * base_alpha).clamp(0.0, 1.0);

                // Premultiplied ARGB8888: B, G, R, A (little-endian)
                let idx = (py * w + px) * 4;
                buf[idx]     = (b_out.clamp(0.0, 1.0) * final_alpha * 255.0) as u8;
                buf[idx + 1] = (g_out.clamp(0.0, 1.0) * final_alpha * 255.0) as u8;
                buf[idx + 2] = (r_out.clamp(0.0, 1.0) * final_alpha * 255.0) as u8;
                buf[idx + 3] = (final_alpha * 255.0) as u8;
            }
        }

        // Pass 2: Text rendering via fontdue
        if !text.is_empty() {
            self.render_text(&mut buf, w, h, text, &text_color, corner_radius);
        }

        buf
    }

    fn render_text(
        &self,
        buf: &mut [u8],
        w: usize,
        h: usize,
        text: &str,
        color: &Rgba,
        _corner_radius: f32,
    ) {
        let font_size = if h > 60 { 14.0 } else { 13.0 };

        // ── Measure total text width ──
        let mut total_width = 0.0f32;
        for ch in text.chars() {
            total_width += self.font.metrics(ch, font_size).advance_width;
        }

        // ── Compute single baseline for vertical centering ──
        // fontdue horizontal_line_metrics gives ascent/descent
        let line_metrics = self.font.horizontal_line_metrics(font_size);
        let (ascent, descent) = match line_metrics {
            Some(m) => (m.ascent, m.descent), // descent is negative
            None => (font_size * 0.8, -(font_size * 0.2)),
        };
        // Text block height = ascent + |descent|
        let text_height = ascent - descent; // descent is negative so this adds
        // Center vertically: baseline_y = (h - text_height) / 2 + ascent
        let baseline_y = ((h as f32 - text_height) / 2.0 + ascent).round() as i32;

        // ── Left-align with padding (leave room for gradient fade on right) ──
        let h_pad = 20.0_f32;
        let start_x = if total_width + h_pad * 2.0 <= w as f32 {
            // Text fits: center it with padding respected
            ((w as f32 - total_width) / 2.0).max(h_pad)
        } else {
            // Text overflows: left-align at padding
            h_pad
        };

        // ── Render each glyph on the shared baseline ──
        let mut cursor_x = start_x;
        for ch in text.chars() {
            let (metrics, bitmap) = self.font.rasterize(ch, font_size);
            if metrics.width == 0 || metrics.height == 0 {
                cursor_x += metrics.advance_width;
                continue;
            }

            // Glyph bitmap top-left in screen coords (y-down):
            // bottom of bitmap = baseline_y - ymin (ymin measured upward from baseline)
            // top of bitmap = bottom - height
            let glyph_x = cursor_x as i32 + metrics.xmin;
            let glyph_top_y = baseline_y - metrics.ymin - metrics.height as i32;

            for gy in 0..metrics.height {
                for gx in 0..metrics.width {
                    let px = glyph_x + gx as i32;
                    let py = glyph_top_y + gy as i32;

                    if px < 0 || py < 0 || px >= w as i32 || py >= h as i32 {
                        continue;
                    }

                    let coverage = bitmap[gy * metrics.width + gx] as f32 / 255.0;
                    if coverage < 0.01 {
                        continue;
                    }

                    // ── Right-edge gradient fade (30px ramp → transparent) ──
                    let fade_zone = 30.0_f32;
                    let fade_start = w as f32 - h_pad - fade_zone;
                    let fade_factor = if (px as f32) > fade_start {
                        let t = ((px as f32) - fade_start) / fade_zone;
                        (1.0 - t * t).max(0.0) // quadratic ease-out to zero
                    } else {
                        1.0
                    };
                    let coverage = coverage * fade_factor;
                    if coverage < 0.01 {
                        continue;
                    }

                    let idx = (py as usize * w + px as usize) * 4;
                    // Alpha-composite text over existing background
                    let dst_b = buf[idx] as f32 / 255.0;
                    let dst_g = buf[idx + 1] as f32 / 255.0;
                    let dst_r = buf[idx + 2] as f32 / 255.0;
                    let dst_a = buf[idx + 3] as f32 / 255.0;

                    let src_a = coverage * color.a;
                    let out_a = src_a + dst_a * (1.0 - src_a);

                    if out_a > 0.001 {
                        let out_r = (color.r * src_a + dst_r * dst_a * (1.0 - src_a)) / out_a;
                        let out_g = (color.g * src_a + dst_g * dst_a * (1.0 - src_a)) / out_a;
                        let out_b = (color.b * src_a + dst_b * dst_a * (1.0 - src_a)) / out_a;

                        // Premultiplied for Wayland
                        buf[idx]     = (out_b * out_a * 255.0) as u8;
                        buf[idx + 1] = (out_g * out_a * 255.0) as u8;
                        buf[idx + 2] = (out_r * out_a * 255.0) as u8;
                        buf[idx + 3] = (out_a * 255.0) as u8;
                    }
                }
            }

            cursor_x += metrics.advance_width;
        }
    }

    /// Render text with a given opacity (0.0 = invisible, 1.0 = full).
    /// Used for crossfade transitions between content states.
    pub fn render_text_with_opacity(
        &self,
        buf: &mut [u8],
        w: usize,
        h: usize,
        text: &str,
        color: &Rgba,
        corner_radius: f32,
        opacity: f32,
    ) {
        if text.is_empty() || opacity < 0.01 {
            return;
        }
        let scaled_color = Rgba {
            r: color.r,
            g: color.g,
            b: color.b,
            a: color.a * opacity,
        };
        self.render_text(buf, w, h, text, &scaled_color, corner_radius);
    }

    /// Render a spinning circular pattern for the scanning animation.
    /// Draws a ring of arc segments that rotate based on `phase`.
    /// Centered in the upper 60% of the card area.
    pub fn render_scanning_spinner(
        &self,
        buf: &mut [u8],
        w: usize,
        h: usize,
        phase: f32,
        accent: &Rgba,
        dim: &Rgba,
    ) {
        // Circle center: horizontally centered, vertically at ~40% height
        let cx = w as f32 / 2.0;
        let cy = h as f32 * 0.40;
        // Radius: fit within the card nicely (about 25% of min dimension)
        let radius = (w.min(h) as f32 * 0.22).max(16.0);
        let ring_thickness = 3.0;

        // Draw arc segments: 8 segments, each gets varying brightness
        let num_segments = 8u32;
        for py in 0..h {
            for px in 0..w {
                let x = px as f32;
                let y = py as f32;

                let dx = x - cx;
                let dy = y - cy;
                let dist = (dx * dx + dy * dy).sqrt();

                // Only draw within the ring band
                let ring_dist = (dist - radius).abs();
                if ring_dist > ring_thickness {
                    continue;
                }

                // Anti-alias the ring edges
                let ring_aa = (1.0 - (ring_dist - ring_thickness + 1.0).max(0.0)).clamp(0.0, 1.0);
                if ring_aa < 0.01 {
                    continue;
                }

                // Compute angle and determine which segment
                let angle = dy.atan2(dx) + std::f32::consts::PI; // [0, 2π]
                let rotated = (angle + phase) % (2.0 * std::f32::consts::PI);
                let segment = (rotated / (2.0 * std::f32::consts::PI) * num_segments as f32) as u32;

                // Trailing fade: segment 0 is brightest (head), higher segments fade
                let brightness = 1.0 - (segment as f32 / num_segments as f32) * 0.85;

                // Interpolate between accent (bright) and dim
                let r = accent.r * brightness + dim.r * (1.0 - brightness) * 0.3;
                let g = accent.g * brightness + dim.g * (1.0 - brightness) * 0.3;
                let b = accent.b * brightness + dim.b * (1.0 - brightness) * 0.3;
                let a = ring_aa * 0.9;

                // Alpha composite onto buffer
                let idx = (py * w + px) * 4;
                let dst_b = buf[idx] as f32 / 255.0;
                let dst_g = buf[idx + 1] as f32 / 255.0;
                let dst_r = buf[idx + 2] as f32 / 255.0;
                let dst_a = buf[idx + 3] as f32 / 255.0;

                let src_a = a;
                let out_a = src_a + dst_a * (1.0 - src_a);
                if out_a > 0.001 {
                    let out_r = (r * src_a + dst_r * dst_a * (1.0 - src_a)) / out_a;
                    let out_g = (g * src_a + dst_g * dst_a * (1.0 - src_a)) / out_a;
                    let out_b = (b * src_a + dst_b * dst_a * (1.0 - src_a)) / out_a;

                    buf[idx]     = (out_b.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                    buf[idx + 1] = (out_g.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                    buf[idx + 2] = (out_r.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                    buf[idx + 3] = (out_a * 255.0) as u8;
                }
            }
        }
    }

    /// Render text at a specific vertical position (y_fraction: 0.0=top, 1.0=bottom).
    /// Horizontally centered. Used for scanning "scanning..." text below the spinner.
    pub fn render_text_at_y(
        &self,
        buf: &mut [u8],
        w: usize,
        h: usize,
        text: &str,
        color: &Rgba,
        y_fraction: f32,
    ) {
        if text.is_empty() {
            return;
        }
        let font_size = 13.0;

        // Measure text width
        let mut total_width = 0.0f32;
        for ch in text.chars() {
            total_width += self.font.metrics(ch, font_size).advance_width;
        }

        // Vertical position
        let line_metrics = self.font.horizontal_line_metrics(font_size);
        let ascent = match line_metrics {
            Some(m) => m.ascent,
            None => font_size * 0.8,
        };
        let baseline_y = (h as f32 * y_fraction + ascent * 0.5).round() as i32;

        // Horizontal center
        let start_x = ((w as f32 - total_width) / 2.0).max(4.0);

        // Render glyphs
        let mut cursor_x = start_x;
        for ch in text.chars() {
            let (metrics, bitmap) = self.font.rasterize(ch, font_size);
            if metrics.width == 0 || metrics.height == 0 {
                cursor_x += metrics.advance_width;
                continue;
            }

            let glyph_x = cursor_x as i32 + metrics.xmin;
            let glyph_top_y = baseline_y - metrics.ymin - metrics.height as i32;

            for gy in 0..metrics.height {
                for gx in 0..metrics.width {
                    let px = glyph_x + gx as i32;
                    let py = glyph_top_y + gy as i32;

                    if px < 0 || py < 0 || px >= w as i32 || py >= h as i32 {
                        continue;
                    }

                    let coverage = bitmap[gy * metrics.width + gx] as f32 / 255.0;
                    if coverage < 0.01 {
                        continue;
                    }

                    let idx = (py as usize * w + px as usize) * 4;
                    let dst_b = buf[idx] as f32 / 255.0;
                    let dst_g = buf[idx + 1] as f32 / 255.0;
                    let dst_r = buf[idx + 2] as f32 / 255.0;
                    let dst_a = buf[idx + 3] as f32 / 255.0;

                    let src_a = coverage * color.a;
                    let out_a = src_a + dst_a * (1.0 - src_a);

                    if out_a > 0.001 {
                        let out_r = (color.r * src_a + dst_r * dst_a * (1.0 - src_a)) / out_a;
                        let out_g = (color.g * src_a + dst_g * dst_a * (1.0 - src_a)) / out_a;
                        let out_b = (color.b * src_a + dst_b * dst_a * (1.0 - src_a)) / out_a;

                        buf[idx]     = (out_b.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                        buf[idx + 1] = (out_g.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                        buf[idx + 2] = (out_r.clamp(0.0, 1.0) * out_a * 255.0) as u8;
                        buf[idx + 3] = (out_a * 255.0) as u8;
                    }
                }
            }

            cursor_x += metrics.advance_width;
        }
    }
}

/// Rounded-rectangle SDF normalized: 0 at center, 1 at boundary, >1 outside.
/// With radius = height/2 this is a perfect capsule/stadium.
fn rounded_rect_sdf(px: f32, py: f32, w: f32, h: f32, radius: f32) -> f32 {
    let hw = w / 2.0;
    let hh = h / 2.0;
    let r = radius.min(hw).min(hh);

    // Fold to positive quadrant from center
    let x = (px - hw).abs();
    let y = (py - hh).abs();

    // IQ rounded box: signed distance from boundary
    // Interior rect half-extents minus radius
    let bx = hw - r;
    let by = hh - r;

    // Distance from the inner rounded-rect skeleton
    let dx = (x - bx).max(0.0);
    let dy = (y - by).max(0.0);
    // sd < 0 inside, 0 on boundary, > 0 outside
    let sd = (dx * dx + dy * dy).sqrt() - r
        + (x - bx).min(0.0).max((y - by).min(0.0));

    // Normalize: 0 at center, 1 at boundary
    let max_depth = hh.min(hw);
    if sd <= 0.0 {
        // Inside: map [-max_depth, 0] → [0, 1]
        1.0 + sd / max_depth
    } else {
        // Outside: 1 + positive distance
        1.0 + sd
    }
}

/// Deterministic per-pixel hash for grain dithering. Returns [0, 1].
#[inline]
fn pixel_hash(x: u32, y: u32) -> f32 {
    // Simple integer hash (no floating point indeterminism)
    let mut h = x.wrapping_mul(374761393).wrapping_add(y.wrapping_mul(668265263));
    h = (h ^ (h >> 13)).wrapping_mul(1274126177);
    h = h ^ (h >> 16);
    (h & 0xFFFF) as f32 / 65535.0
}

#[inline]
fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

#[inline]
fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}
