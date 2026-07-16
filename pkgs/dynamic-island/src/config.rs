//! Configuration: colors, sizes, and layout constants.
//! Reads `~/.config/dynamic-island/colors.json` for theming (moss-fern palette default).

use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

/// Color palette (matches status-bar ColorSync format)
#[derive(Debug, Clone, Deserialize)]
pub struct Colors {
    #[serde(default = "default_accent")]
    pub accent: String,
    #[serde(default = "default_bg")]
    pub bg: String,
    #[serde(default = "default_text")]
    pub text: String,
    #[serde(default = "default_error")]
    pub error: String,
}

fn default_accent() -> String { "#a3b56a".into() }
fn default_bg() -> String { "#0a0e0a".into() }
fn default_text() -> String { "#e0e8d8".into() }
fn default_error() -> String { "#e06c75".into() }

impl Default for Colors {
    fn default() -> Self {
        Self {
            accent: default_accent(),
            bg: default_bg(),
            text: default_text(),
            error: default_error(),
        }
    }
}

/// Island dimensions for each visual state
#[derive(Debug, Clone)]
pub struct Config {
    pub colors: Colors,
    // Pill sizes (width, height)
    pub idle_w: f32,
    pub idle_h: f32,
    pub notification_w: f32,
    pub notification_h: f32,
    pub dot_diameter: f32,
    // Card sizes
    pub card_w: f32,
    pub card_h: f32,
    // Margins
    pub top_margin: u32,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            colors: Colors::default(),
            idle_w: 140.0,
            idle_h: 36.0,
            notification_w: 320.0,
            notification_h: 36.0,
            dot_diameter: 8.0,
            card_w: 320.0,
            card_h: 200.0,
            top_margin: 6,
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let mut cfg = Self::default();

        // Try to load colors from the shared colors.json
        let colors_path = colors_json_path();
        if let Ok(data) = fs::read_to_string(&colors_path) {
            if let Ok(colors) = serde_json::from_str::<Colors>(&data) {
                cfg.colors = colors;
            }
        }

        cfg
    }

    /// Initial idle pill size
    pub fn idle_size(&self) -> (f32, f32) {
        (self.idle_w, self.idle_h)
    }

    /// Parse hex color to [f32; 4] RGBA (sRGB)
    pub fn parse_color(hex: &str) -> [f32; 4] {
        let hex = hex.trim_start_matches('#');
        if hex.len() < 6 {
            return [1.0, 1.0, 1.0, 1.0];
        }
        let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(255) as f32 / 255.0;
        let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(255) as f32 / 255.0;
        let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(255) as f32 / 255.0;
        [r, g, b, 1.0]
    }
}

fn colors_json_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(home).join(".config/dynamic-island/colors.json")
}
