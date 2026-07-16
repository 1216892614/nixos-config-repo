//! Dynamic Island – SCTK layer-shell overlay for NixOS/niri.
//!
//! CPU-rendered (tiny-skia + fontdue) status overlay using:
//! - smithay-client-toolkit for Wayland layer-shell + shm buffers
//! - calloop for the event loop
//! - dbus-monitor subprocess for notification eavesdropping
//! - inotify for agent JSON file watch

mod config;
mod renderer;
mod spring;
mod state;

use std::time::{Duration, Instant};

use calloop::timer::{TimeoutAction, Timer};
use calloop::EventLoop;
use log::{debug, info};

use smithay_client_toolkit::reexports::calloop_wayland_source::WaylandSource;
use smithay_client_toolkit::reexports::client::{
    globals::registry_queue_init,
    protocol::wl_output::WlOutput,
    Connection, QueueHandle,
};
use smithay_client_toolkit::shell::wlr_layer::{
    Anchor, KeyboardInteractivity, Layer, LayerShell, LayerSurface, LayerSurfaceConfigure,
};
use smithay_client_toolkit::shell::WaylandSurface;
use smithay_client_toolkit::shm::slot::SlotPool;
use smithay_client_toolkit::shm::{Shm, ShmHandler};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{SeatHandler, SeatState},
    delegate_seat,
};


use crate::config::Config;
use crate::renderer::Renderer;
use crate::spring::Spring2D;
use crate::state::{IslandState, IslandStateMachine, AgentSource};

// ── Constants ──────────────────────────────────────────────────────────

/// Target frame interval: 60 FPS when animating, idle otherwise
const FRAME_DT: Duration = Duration::from_millis(16);
/// Spring physics dt (seconds)
const SPRING_DT: f32 = 0.016;
/// Max dimensions for shm pool pre-allocation (must cover card_w × card_h)
const MAX_WIDTH: u32 = 400;
const MAX_HEIGHT: u32 = 220;

// ── Font loading ───────────────────────────────────────────────────────

/// Find a suitable font at runtime (NixOS-compatible)
fn find_font() -> Vec<u8> {
    // Check env var first (set by Nix derivation wrapper)
    if let Ok(path) = std::env::var("DYNAMIC_ISLAND_FONT") {
        if let Ok(data) = std::fs::read(&path) {
            info!("font loaded from DYNAMIC_ISLAND_FONT: {path}");
            return data;
        }
    }

    // Try fontconfig via fc-match
    if let Ok(output) = std::process::Command::new("fc-match")
        .args(["--format=%{file}", "monospace"])
        .output()
    {
        if output.status.success() {
            let path = String::from_utf8_lossy(&output.stdout).to_string();
            if let Ok(data) = std::fs::read(&path) {
                info!("font loaded via fc-match: {path}");
                return data;
            }
        }
    }

    // Fallback: scan common NixOS font paths
    let candidates = [
        "/run/current-system/sw/share/X11/fonts/DejaVuSansMono.ttf",
        "/run/current-system/sw/share/X11/fonts/DejaVuSans.ttf",
    ];
    for path in &candidates {
        if let Ok(data) = std::fs::read(path) {
            info!("font loaded from: {path}");
            return data;
        }
    }

    panic!("no suitable font found. Set DYNAMIC_ISLAND_FONT env var.");
}

// ── Per-output layer surface ──────────────────────────────────────────

struct PerOutput {
    output: WlOutput,
    surface: LayerSurface,
    pool: SlotPool,
    configured: bool,
}

// ── Island main state ──────────────────────────────────────────────────

struct Island {
    // Wayland state
    registry_state: RegistryState,
    compositor_state: CompositorState,
    layer_shell: LayerShell,
    shm: Shm,
    seat_state: SeatState,
    output_state: OutputState,


    // Per-output surfaces (one island per monitor)
    layers: Vec<PerOutput>,

    // Rendering
    renderer: Renderer,
    config: Config,
    state_machine: IslandStateMachine,

    // Animation
    size_spring: Spring2D,
    current_width: f32,
    current_height: f32,

    // Frame tracking
    last_frame: Instant,
    animating: bool,

    // Screen width for centering
    screen_width: u32,
}

impl Island {
    fn new(
        registry_state: RegistryState,
        compositor_state: CompositorState,
        layer_shell: LayerShell,
        shm: Shm,
        seat_state: SeatState,
        output_state: OutputState,
    ) -> Self {
        let config = Config::load();
        let (iw, ih) = config.idle_size();
        let font_data = find_font();
        let renderer = Renderer::new(&font_data);

        Self {
            registry_state,
            compositor_state,
            layer_shell,
            shm,
            seat_state,
            output_state,

            layers: Vec::new(),

            renderer,
            config,
            state_machine: IslandStateMachine::new(),

            size_spring: Spring2D::new(iw, ih),
            current_width: iw,
            current_height: ih,

            last_frame: Instant::now(),
            animating: false,

            screen_width: 2560, // default; updated from output info
        }
    }

    /// Create a layer surface on a specific output
    fn create_surface_for_output(&mut self, qh: &QueueHandle<Self>, output: WlOutput) {
        let surface = self.compositor_state.create_surface(qh);
        let layer_surface = self.layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("dynamic-island"),
            Some(&output),
        );

        // Configure: anchor top-center, dynamic size
        layer_surface.set_anchor(Anchor::TOP);
        let iw = self.current_width.round() as u32;
        let ih = self.current_height.round() as u32;
        layer_surface.set_size(iw.max(1), ih.max(1));
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer_surface.set_exclusive_zone(-1);
        layer_surface.set_margin(6, 0, 0, 0);
        layer_surface.commit();

        let pool_size = (MAX_WIDTH * MAX_HEIGHT * 4 * 2) as usize;
        let pool = SlotPool::new(pool_size, &self.shm)
            .expect("failed to create slot pool for output");

        self.layers.push(PerOutput {
            output,
            surface: layer_surface,
            pool,
            configured: false,
        });
    }

    /// Per-frame tick: advance spring, check timeouts, render if needed.
    fn tick(&mut self) {
        let now = Instant::now();
        let _elapsed = now.duration_since(self.last_frame);
        self.last_frame = now;

        // Check state timeouts
        let state_changed = self.state_machine.check_timeout();
        if state_changed {
            let (tw, th) = self.state_machine.target_size(&self.config);
            self.size_spring.set_target(tw, th);
            self.animating = true;
        }

        // Advance spring
        self.size_spring.tick(SPRING_DT);
        let (new_w, new_h) = self.size_spring.value();
        self.animating = self.size_spring.is_active();

        self.current_width = new_w;
        self.current_height = new_h;

        // Render frame
        self.render_frame();
    }

    fn render_frame(&mut self) {
        // Compute current pill dimensions
        let iw = self.current_width.round() as u32;
        let ih = self.current_height.round() as u32;
        if iw == 0 || ih == 0 {
            return;
        }

        // niri's liquid-glass layer-rule provides the frosted glass background;
        // the island surface only needs to be a dark semi-transparent shape.
        // No grim capture needed — niri composites behind our alpha channel.

        // Render pixels once (shared across all outputs)
        let text = self.state_machine.display_text(&self.config);
        let corner_radius = ih as f32 / 2.0;
        let opacity = 0.35; // low opacity so niri liquid-glass shows through
        let glow = 0.4;

        let pixels = self.renderer.render(
            &self.config,
            &text,
            iw,
            ih,
            corner_radius,
            opacity,
            glow,
        );

        let copy_len = (iw * ih * 4) as usize;

        // Blit to each configured output surface
        for per_output in &mut self.layers {
            if !per_output.configured {
                continue;
            }

            per_output.surface.set_size(iw, ih);

            let buf_w = iw;
            let buf_h = ih;
            let stride = buf_w as i32 * 4;
            let buf_size = (stride * buf_h as i32) as usize;

            if per_output.pool.len() < buf_size {
                per_output.pool.resize(buf_size).expect("pool resize failed");
            }

            let (buffer, canvas) = per_output
                .pool
                .create_buffer(
                    buf_w as i32,
                    buf_h as i32,
                    stride,
                    smithay_client_toolkit::reexports::client::protocol::wl_shm::Format::Argb8888,
                )
                .expect("create_buffer failed");

            canvas.fill(0);
            if pixels.len() >= copy_len && canvas.len() >= copy_len {
                canvas[..copy_len].copy_from_slice(&pixels[..copy_len]);
            }

            let surface = per_output.surface.wl_surface();

            buffer.attach_to(surface).expect("buffer attach failed");
            surface.damage_buffer(0, 0, buf_w as i32, buf_h as i32);
            surface.commit();
        }
    }
}

// ── SCTK Handler Implementations ──────────────────────────────────────

impl CompositorHandler for Island {
    fn scale_factor_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface,
        _new_factor: i32,
    ) {
    }

    fn transform_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface,
        _new_transform: smithay_client_toolkit::reexports::client::protocol::wl_output::Transform,
    ) {
    }

    fn frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface,
        _time: u32,
    ) {
    }

    fn surface_enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface,
        _output: &smithay_client_toolkit::reexports::client::protocol::wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface,
        _output: &smithay_client_toolkit::reexports::client::protocol::wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for Island {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        output: smithay_client_toolkit::reexports::client::protocol::wl_output::WlOutput,
    ) {
        // Update screen width from output logical size
        if let Some(info) = self.output_state.info(&output) {
            if let Some(logical) = info.logical_size {
                self.screen_width = logical.0 as u32;
            }
        }
        info!("new output detected (width={}), creating island surface", self.screen_width);
        self.create_surface_for_output(qh, output);
    }

    fn update_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: smithay_client_toolkit::reexports::client::protocol::wl_output::WlOutput,
    ) {
    }

    fn output_destroyed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        output: smithay_client_toolkit::reexports::client::protocol::wl_output::WlOutput,
    ) {
        info!("output destroyed, removing island surface");
        self.layers.retain(|l| l.output != output);
    }
}

impl SeatHandler for Island {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }

    fn new_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: smithay_client_toolkit::reexports::client::protocol::wl_seat::WlSeat,
    ) {
    }

    fn new_capability(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: smithay_client_toolkit::reexports::client::protocol::wl_seat::WlSeat,
        _capability: smithay_client_toolkit::seat::Capability,
    ) {
    }

    fn remove_capability(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: smithay_client_toolkit::reexports::client::protocol::wl_seat::WlSeat,
        _capability: smithay_client_toolkit::seat::Capability,
    ) {
    }

    fn remove_seat(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _seat: smithay_client_toolkit::reexports::client::protocol::wl_seat::WlSeat,
    ) {
    }
}

impl ShmHandler for Island {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl smithay_client_toolkit::shell::wlr_layer::LayerShellHandler for Island {
    fn closed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        layer: &LayerSurface,
    ) {
        info!("layer surface closed");
        self.layers.retain(|l| &l.surface != layer);
        if self.layers.is_empty() {
            std::process::exit(0);
        }
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        debug!("configured: {}x{}", configure.new_size.0, configure.new_size.1);
        // Mark the matching per-output surface as configured
        for per_output in &mut self.layers {
            if &per_output.surface == layer {
                per_output.configured = true;
                break;
            }
        }
        // Render to all configured surfaces
        self.render_frame();
    }
}

impl ProvidesRegistryState for Island {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }

    registry_handlers![OutputState, SeatState];
}

// ── Delegate macros ────────────────────────────────────────────────────

delegate_compositor!(Island);
delegate_output!(Island);
delegate_layer!(Island);
delegate_registry!(Island);
delegate_seat!(Island);
delegate_shm!(Island);

// ── D-Bus notification listener (dbus-monitor subprocess) ──────────────

/// Spawn `dbus-monitor` as a subprocess to passively eavesdrop on Notify calls.
/// This avoids all zbus/BecomeMonitor routing issues — dbus-monitor uses
/// BecomeMonitor natively and outputs a simple text protocol we parse.
fn spawn_dbus_listener(
    sender: calloop::channel::Sender<NotificationEvent>,
) {
    std::thread::spawn(move || {
        use std::io::BufRead;
        use std::process::{Command, Stdio};

        let mut child = match Command::new("dbus-monitor")
            .args(["--session", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
        {
            Ok(c) => c,
            Err(e) => {
                log::error!("failed to spawn dbus-monitor: {e}");
                return;
            }
        };

        info!("D-Bus notification monitor active (dbus-monitor pid={})", child.id());

        let stdout = child.stdout.take().unwrap();
        let reader = std::io::BufReader::new(stdout);

        // dbus-monitor output for a Notify call looks like:
        // method call time=... sender=... -> destination=... member=Notify
        //    string "app_name"
        //    uint32 0
        //    string "icon"
        //    string "summary"
        //    string "body"
        //    array [ ... ]
        //    array [ ... ]
        //    int32 5000
        //
        // We collect string/int32 fields after seeing a Notify line.

        let mut in_notify = false;
        let mut strings: Vec<String> = Vec::new();
        let mut last_int: i32 = 5000;

        for line in reader.lines() {
            let line = match line {
                Ok(l) => l,
                Err(_) => break,
            };

            let trimmed = line.trim();

            // New method call starts a message block
            if trimmed.starts_with("method call") && trimmed.contains("member=Notify") {
                // If we had a previous Notify in progress, emit it
                if in_notify && strings.len() >= 4 {
                    emit_notification(&sender, &strings, last_int);
                }
                in_notify = true;
                strings.clear();
                last_int = 5000;
                continue;
            }

            // Another message block starts (signal, method_return, etc.) -> flush
            if !line.starts_with(' ') && !trimmed.is_empty() && in_notify {
                if strings.len() >= 4 {
                    emit_notification(&sender, &strings, last_int);
                }
                in_notify = false;
                strings.clear();
                continue;
            }

            if !in_notify {
                continue;
            }

            // Parse string fields
            if trimmed.starts_with("string \"") {
                // Extract content between first pair of quotes
                if let Some(start) = trimmed.find('"') {
                    let rest = &trimmed[start + 1..];
                    if let Some(end) = rest.rfind('"') {
                        strings.push(rest[..end].to_string());
                    }
                }
            } else if trimmed.starts_with("int32 ") {
                if let Ok(v) = trimmed[6..].trim().parse::<i32>() {
                    last_int = v;
                }
                // int32 is the last argument of Notify (susssasa{sv}i) — emit now
                if in_notify && strings.len() >= 4 {
                    emit_notification(&sender, &strings, last_int);
                    in_notify = false;
                    strings.clear();
                }
            }
        }

        // dbus-monitor exited
        let _ = child.wait();
        log::warn!("dbus-monitor exited");
    });
}

fn emit_notification(
    sender: &calloop::channel::Sender<NotificationEvent>,
    strings: &[String],
    expire: i32,
) {
    // Notify args order: app_name(0), icon(1?), summary, body
    // After replaces_id (uint32, not captured) and icon, we get summary and body.
    // dbus-monitor string order: app_name, icon, summary, body
    // index 0=app_name, 1=icon, 2=summary, 3=body
    if strings.len() < 4 {
        return;
    }
    let app_name = &strings[0];
    let summary = &strings[2];
    let body_text = &strings[3];
    let timeout_ms = if expire <= 0 { 5000 } else { expire as u32 };

    log::debug!("notification: {app_name}: {summary}");
    let _ = sender.send(NotificationEvent {
        app_name: app_name.clone(),
        summary: summary.clone(),
        body: body_text.clone(),
        timeout_ms,
    });
}

struct NotificationEvent {
    app_name: String,
    summary: String,
    body: String,
    timeout_ms: u32,
}

// ── Agent file watcher ─────────────────────────────────────────────────

struct AgentEvent {
    source: AgentSource,
    state: String,
    task: String,
}

fn spawn_agent_watcher(sender: calloop::channel::Sender<AgentEvent>) {
    use inotify::{Inotify, WatchMask};

    std::thread::spawn(move || {
        let path = "/tmp/island-agent.json";

        // Ensure file exists
        if !std::path::Path::new(path).exists() {
            let _ = std::fs::write(path, "{}");
        }

        let mut inotify = Inotify::init().expect("inotify init");
        inotify
            .watches()
            .add(path, WatchMask::MODIFY | WatchMask::CREATE)
            .expect("inotify watch");

        let mut buf = [0u8; 1024];
        loop {
            let events = inotify.read_events_blocking(&mut buf);
            if events.is_err() {
                std::thread::sleep(Duration::from_secs(1));
                continue;
            }

            // Read and parse the JSON
            if let Ok(data) = std::fs::read_to_string(path) {
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&data) {
                    let source = match json.get("source").and_then(|v| v.as_str()) {
                        Some("opencode") => AgentSource::OpenCode,
                        Some("omp") => AgentSource::Omp,
                        _ => continue,
                    };
                    let state = json
                        .get("state")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    let task = json
                        .get("task")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();

                    let _ = sender.send(AgentEvent { source, state, task });
                }
            }
        }
    });
}

// ── Howdy monitor ──────────────────────────────────────────────────────

enum HowdyEvent {
    Started,
    Ended(bool), // true = success
}

fn spawn_howdy_monitor(sender: calloop::channel::Sender<HowdyEvent>) {
    std::thread::spawn(move || {
        let mut was_running = false;
        loop {
            let running = std::process::Command::new("pgrep")
                .args(["-x", "howdy"])
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false);

            if running && !was_running {
                let _ = sender.send(HowdyEvent::Started);
            } else if !running && was_running {
                // Check exit status from PAM module status file
                let success = std::path::Path::new("/tmp/howdy-success").exists();
                let _ = sender.send(HowdyEvent::Ended(success));
                // Clean up
                let _ = std::fs::remove_file("/tmp/howdy-success");
            }

            was_running = running;
            std::thread::sleep(Duration::from_millis(500));
        }
    });
}

// ── Main ───────────────────────────────────────────────────────────────

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    info!("Dynamic Island starting");

    let conn = Connection::connect_to_env().expect("failed to connect to Wayland");
    let (globals, mut event_queue) =
        registry_queue_init(&conn).expect("failed to init registry");
    let qh = event_queue.handle();

    let compositor_state =
        CompositorState::bind(&globals, &qh).expect("wl_compositor not available");
    let layer_shell =
        LayerShell::bind(&globals, &qh).expect("wlr-layer-shell not available");
    let shm = Shm::bind(&globals, &qh).expect("wl_shm not available");
    let seat_state = SeatState::new(&globals, &qh);
    let output_state = OutputState::new(&globals, &qh);

    let registry_state = RegistryState::new(&globals);

    let mut island = Island::new(
        registry_state,
        compositor_state,
        layer_shell,
        shm,
        seat_state,
        output_state,
    );

    // Initial roundtrip to discover outputs.
    // NOTE: registry_queue_init already binds outputs internally, so
    // OutputHandler::new_output may NOT fire during this roundtrip.
    // We manually iterate already-known outputs afterward.
    event_queue.roundtrip(&mut island).expect("initial roundtrip");

    // Create surfaces for outputs already known to OutputState
    // (handles the SCTK 0.19 timing where new_output doesn't re-fire).
    let qh = event_queue.handle();
    let known_outputs: Vec<WlOutput> = island.output_state.outputs().collect();
    for output in known_outputs {
        if !island.layers.iter().any(|l| l.output == output) {
            info!("creating surface for pre-existing output");
            island.create_surface_for_output(&qh, output);
        }
    }
    // Second roundtrip to get layer_surface configure events
    event_queue.roundtrip(&mut island).expect("second roundtrip");

    // Set up calloop event loop
    let mut event_loop: EventLoop<Island> = EventLoop::try_new().expect("event loop");
    let loop_handle = event_loop.handle();

    // Insert Wayland source
    WaylandSource::new(conn.clone(), event_queue)
        .insert(loop_handle.clone())
        .expect("wayland source");

    // Frame timer
    loop_handle
        .insert_source(
            Timer::from_duration(FRAME_DT),
            |_event, _metadata, island| {
                if !island.layers.iter().any(|l| l.configured) {
                    return TimeoutAction::ToDuration(Duration::from_millis(100));
                }
                island.tick();
                if island.animating {
                    TimeoutAction::ToDuration(FRAME_DT)
                } else {
                    // Idle: tick once per second for clock updates
                    TimeoutAction::ToDuration(Duration::from_secs(1))
                }
            },
        )
        .expect("timer source");

    // D-Bus notification channel
    let (notif_send, notif_recv) = calloop::channel::channel::<NotificationEvent>();
    loop_handle
        .insert_source(notif_recv, |event, _metadata, island| {
            if let calloop::channel::Event::Msg(notif) = event {
                let changed = island.state_machine.push(IslandState::Notification {
                    summary: notif.summary,
                    body: notif.body,
                    app_name: notif.app_name,
                    icon: None,
                    entered_at: Instant::now(),
                    timeout_ms: notif.timeout_ms,
                });
                if changed {
                    let (tw, th) = island.state_machine.target_size(&island.config);
                    island.size_spring.set_target(tw, th);
                    island.animating = true;
                }
            }
        })
        .expect("notif channel");
    spawn_dbus_listener(notif_send);

    // Agent file watcher channel
    let (agent_send, agent_recv) = calloop::channel::channel::<AgentEvent>();
    loop_handle
        .insert_source(agent_recv, |event, _metadata, island| {
            if let calloop::channel::Event::Msg(evt) = event {
                let changed = match evt.state.as_str() {
                    "running" => island.state_machine.push(IslandState::AgentRunning {
                        source: evt.source,
                        task: evt.task,
                        started_at: Instant::now(),
                    }),
                    "done" => island.state_machine.push(IslandState::AgentResult {
                        source: evt.source,
                        task: evt.task,
                        success: true,
                        entered_at: Instant::now(),
                    }),
                    "error" => island.state_machine.push(IslandState::AgentResult {
                        source: evt.source,
                        task: evt.task,
                        success: false,
                        entered_at: Instant::now(),
                    }),
                    _ => false,
                };
                if changed {
                    let (tw, th) = island.state_machine.target_size(&island.config);
                    island.size_spring.set_target(tw, th);
                    island.animating = true;
                }
            }
        })
        .expect("agent channel");
    spawn_agent_watcher(agent_send);

    // Howdy monitor channel
    let (howdy_send, howdy_recv) = calloop::channel::channel::<HowdyEvent>();
    loop_handle
        .insert_source(howdy_recv, |event, _metadata, island| {
            if let calloop::channel::Event::Msg(evt) = event {
                let changed = match evt {
                    HowdyEvent::Started => {
                        island.state_machine.push(IslandState::Howdy {
                            sub_state: crate::state::HowdySubState::Scanning,
                            entered_at: Instant::now(),
                        })
                    }
                    HowdyEvent::Ended(success) => {
                        // Update howdy state to result
                        let sub = if success {
                            crate::state::HowdySubState::Success
                        } else {
                            crate::state::HowdySubState::Failed
                        };
                        island.state_machine.push(IslandState::Howdy {
                            sub_state: sub,
                            entered_at: Instant::now(),
                        })
                    }
                };
                if changed {
                    let (tw, th) = island.state_machine.target_size(&island.config);
                    island.size_spring.set_target(tw, th);
                    island.animating = true;
                }
            }
        })
        .expect("howdy channel");
    spawn_howdy_monitor(howdy_send);

    info!("entering event loop");
    loop {
        event_loop
            .dispatch(Some(Duration::from_millis(100)), &mut island)
            .expect("event loop error");
    }
}
