use std::io::Write;
use std::time::Duration;

// ─── Catppuccin Mocha palette ──────────────────────────────────────────────
// surface0:        #313244 → rgb(49, 50, 68) — pill background
// text:            #cdd6f4 → rgb(205, 214, 244)
// red (accent):    #f38ba8 → rgb(243, 139, 168)
// surface2:        #585b70 → rgb(88, 91, 112) — dim dot

/// Pill background: surface0
const BG: &str = "\x1b[48;2;49;50;68m";
/// Reset all attributes
const RESET: &str = "\x1b[0m";

/// Dot colors for pulse animation (dim → bright → burst → dim)
/// Accent red at varying intensity, peak is a "burst" star
const DOT_COLORS: &[&str] = &[
    "\x1b[38;2;88;91;112m",   // surface2 (very dim)
    "\x1b[38;2;140;80;100m",  // dim red
    "\x1b[38;2;200;110;140m", // medium red
    "\x1b[38;2;243;139;168m", // full accent red — burst frame (✱)
    "\x1b[38;2;200;110;140m", // medium red (descending)
    "\x1b[38;2;140;80;100m",  // dim red
];

/// Dot glyphs: small → expanding → star burst → contracting
/// No full circle (●) during animation — peak is ✱ for explosion feel
const DOT_GLYPHS: &[&str] = &["·", "○", "◉", "✱", "◉", "○"];

/// Normal text color (no special color — just default terminal fg)
const FG: &str = "\x1b[38;2;205;214;244m";
/// Accent red for the final success dot
const RED_DOT: &str = "\x1b[38;2;243;139;168m";
/// Dim dot for failure
const DIM_DOT: &str = "\x1b[38;2;88;91;112m";

/// Hide cursor
const HIDE_CURSOR: &str = "\x1b[?25l";
/// Show cursor
const SHOW_CURSOR: &str = "\x1b[?25h";
/// Move to start of line and clear
const CLEAR_LINE: &str = "\r\x1b[2K";

/// Duration of one full pulse cycle
const PULSE_CYCLE_MS: u64 = 600;
/// How long to show CHECK result
const SUCCESS_DISPLAY_MS: u64 = 800;
/// How long to show FAIL result
const FAIL_DISPLAY_MS: u64 = 500;

/// Render the pill — only the dot gets color, text stays normal FG
fn render_pill(dot_color: &str, dot_glyph: &str, label: &str) -> String {
    format!("{CLEAR_LINE}  {BG} {dot_color}{dot_glyph}  {FG}{label:<8}{RESET}",)
}

/// Represents the animation state on a TTY file descriptor
pub struct Animation {
    tty: std::fs::File,
}

impl Animation {
    /// Create animation from /dev/tty (current controlling terminal)
    pub fn from_dev_tty() -> Option<Self> {
        let tty = std::fs::OpenOptions::new()
            .write(true)
            .open("/dev/tty")
            .ok()?;
        Some(Self { tty })
    }

    /// Begin: hide cursor
    fn begin(&mut self) {
        let _ = write!(self.tty, "{HIDE_CURSOR}");
        let _ = self.tty.flush();
    }

    /// End: show cursor, clear line
    fn end(&mut self) {
        let _ = write!(self.tty, "{CLEAR_LINE}{SHOW_CURSOR}");
        let _ = self.tty.flush();
    }

    /// Run the scanning animation loop until `stop` returns true.
    pub fn run_scanning_loop(&mut self, stop: &std::sync::atomic::AtomicBool) {
        let frame_duration = Duration::from_millis(PULSE_CYCLE_MS / DOT_GLYPHS.len() as u64);
        let mut frame: usize = 0;

        self.begin();

        while !stop.load(std::sync::atomic::Ordering::Relaxed) {
            let idx = frame % DOT_GLYPHS.len();
            let pill = render_pill(DOT_COLORS[idx], DOT_GLYPHS[idx], "SCANNING");
            let _ = write!(self.tty, "{pill}");
            let _ = self.tty.flush();
            frame = frame.wrapping_add(1);
            std::thread::sleep(frame_duration);
        }
    }

    /// Show the success state: solid red ● + normal text CHECK
    pub fn show_check(&mut self) {
        let pill = render_pill(RED_DOT, "●", "CHECK");
        let _ = write!(self.tty, "{pill}");
        let _ = self.tty.flush();
        std::thread::sleep(Duration::from_millis(SUCCESS_DISPLAY_MS));
        self.end();
    }

    /// Show the failure state: dim ○ + normal text FAIL
    pub fn show_fail(&mut self) {
        let pill = render_pill(DIM_DOT, "○", "FAIL");
        let _ = write!(self.tty, "{pill}");
        let _ = self.tty.flush();
        std::thread::sleep(Duration::from_millis(FAIL_DISPLAY_MS));
        self.end();
    }

    /// Show retry state: dim ○ + normal text RETRY
    #[allow(dead_code)]
    pub fn show_retry(&mut self) {
        let pill = render_pill(DIM_DOT, "○", "RETRY");
        let _ = write!(self.tty, "{pill}");
        let _ = self.tty.flush();
        std::thread::sleep(Duration::from_millis(FAIL_DISPLAY_MS));
        self.end();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_render_pill_contains_label() {
        let pill = render_pill(RED_DOT, "●", "CHECK");
        assert!(pill.contains("CHECK"));
        assert!(pill.contains("●"));
    }
}
