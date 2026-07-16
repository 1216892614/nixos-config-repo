//! Island state machine.
//! States: Idle, Notification, Howdy, HowdyResult, Recording, AgentRunning, AgentResult
//! Priority: Howdy > Recording > Notification > AgentResult > AgentRunning > Idle
//! Higher-priority states preempt lower ones; on completion, falls back to
//! the highest-priority still-active state.

use std::time::Instant;

/// Visual shape of the island
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Shape {
    /// Small pill: clock / compact info (140×36)
    Pill,
    /// Notification capsule: wider pill (360×40)
    Capsule,
    /// Tall card: expanded info (320×180)
    Card,
    /// Dot: tiny circle (12×12) – pagination indicator
    Dot,
}

impl Shape {
    /// Default dimensions (width, height) in logical pixels
    pub fn dimensions(self) -> (f32, f32) {
        match self {
            Shape::Pill => (140.0, 36.0),
            Shape::Capsule => (360.0, 40.0),
            Shape::Card => (320.0, 180.0),
            Shape::Dot => (12.0, 12.0),
        }
    }
}

/// Priority values (higher number = higher priority)
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum Priority {
    Idle = 0,
    AgentRunning = 1,
    AgentResult = 2,
    Notification = 3,
    Recording = 4,
    Howdy = 5,
}

/// Island display state
#[derive(Debug, Clone)]
pub enum IslandState {
    Idle,
    Notification {
        summary: String,
        body: String,
        app_name: String,
        icon: Option<String>,
        entered_at: Instant,
        /// Auto-dismiss after this duration
        timeout_ms: u32,
    },
    Howdy {
        sub_state: HowdySubState,
        entered_at: Instant,
    },
    Recording {
        pid: u32,
        started_at: Instant,
    },
    AgentRunning {
        source: AgentSource,
        task: String,
        started_at: Instant,
    },
    AgentResult {
        source: AgentSource,
        task: String,
        success: bool,
        entered_at: Instant,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HowdySubState {
    Scanning,
    Success,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentSource {
    OpenCode,
    Omp,
}

impl IslandState {
    pub fn priority(&self) -> Priority {
        match self {
            IslandState::Idle => Priority::Idle,
            IslandState::Notification { .. } => Priority::Notification,
            IslandState::Howdy { .. } => Priority::Howdy,
            IslandState::Recording { .. } => Priority::Recording,
            IslandState::AgentRunning { .. } => Priority::AgentRunning,
            IslandState::AgentResult { .. } => Priority::AgentResult,
        }
    }

    pub fn shape(&self) -> Shape {
        match self {
            IslandState::Idle => Shape::Pill,
            IslandState::Notification { .. } => Shape::Capsule,
            IslandState::Howdy {
                sub_state: HowdySubState::Scanning,
                ..
            } => Shape::Pill,
            IslandState::Howdy { .. } => Shape::Card,
            IslandState::Recording { .. } => Shape::Pill,
            IslandState::AgentRunning { .. } => Shape::Pill,
            IslandState::AgentResult { .. } => Shape::Card,
        }
    }
}

/// State machine managing transitions
pub struct StateMachine {
    /// Current displayed state
    pub current: IslandState,
    /// Queue of pending states (sorted by priority descending)
    pending: Vec<IslandState>,
}

impl StateMachine {
    pub fn new() -> Self {
        Self {
            current: IslandState::Idle,
            pending: Vec::new(),
        }
    }

    /// Push a new state. If higher priority than current, preempt immediately.
    /// Returns true if the display state changed.
    pub fn push(&mut self, state: IslandState) -> bool {
        let new_priority = state.priority();
        let cur_priority = self.current.priority();

        if new_priority > cur_priority {
            // Preempt: shelve current if non-idle
            if cur_priority > Priority::Idle {
                self.pending.push(std::mem::replace(&mut self.current, state));
            } else {
                self.current = state;
            }
            self.sort_pending();
            true
        } else {
            // Queue for later
            self.pending.push(state);
            self.sort_pending();
            false
        }
    }

    /// Dismiss current state and fall back to highest-priority pending.
    /// Returns true if display state changed.
    pub fn dismiss_current(&mut self) -> bool {
        if let Some(next) = self.pending.pop() {
            self.current = next;
        } else {
            self.current = IslandState::Idle;
        }
        true
    }

    /// Check if current state should auto-dismiss (timeout).
    /// Call periodically. Returns true if state changed.
    pub fn check_timeout(&mut self) -> bool {
        let now = Instant::now();
        let should_dismiss = match &self.current {
            IslandState::Notification {
                entered_at,
                timeout_ms,
                ..
            } => now.duration_since(*entered_at).as_millis() >= *timeout_ms as u128,
            IslandState::Howdy {
                sub_state,
                entered_at,
            } => {
                matches!(sub_state, HowdySubState::Success | HowdySubState::Failed)
                    && now.duration_since(*entered_at).as_millis() >= 2000
            }
            IslandState::AgentResult { entered_at, .. } => {
                now.duration_since(*entered_at).as_millis() >= 5000
            }
            _ => false,
        };

        if should_dismiss {
            self.dismiss_current()
        } else {
            false
        }
    }

    fn sort_pending(&mut self) {
        // Sort ascending so pop() gives highest priority
        self.pending
            .sort_by(|a, b| a.priority().cmp(&b.priority()));
    }
}

// -- Public API expected by main.rs --

/// Type alias for ergonomic use in main.rs
pub type IslandStateMachine = StateMachine;

impl StateMachine {
    /// Target size for spring animation based on current state.
    pub fn target_size(&self, config: &crate::config::Config) -> (f32, f32) {
        match &self.current {
            IslandState::Idle => (config.idle_w, config.idle_h),
            IslandState::Notification { .. } => (config.notification_w, config.notification_h),
            IslandState::Howdy { sub_state, .. } => match sub_state {
                HowdySubState::Scanning => (config.idle_w, config.idle_h),
                _ => (config.card_w, config.card_h),
            },
            IslandState::Recording { .. } => (config.idle_w, config.idle_h),
            IslandState::AgentRunning { .. } => (config.notification_w, config.notification_h),
            IslandState::AgentResult { .. } => (config.card_w, config.card_h),
        }
    }

    /// Text to display on the island for the current state.
    pub fn display_text(&self, _config: &crate::config::Config) -> String {
        match &self.current {
            IslandState::Idle => {
                let now = chrono::Local::now();
                now.format("%H:%M · %a %d").to_string()
            }
            IslandState::Notification { summary, app_name, .. } => {
                format!("{app_name}: {summary}")
            }
            IslandState::Howdy { sub_state, .. } => match sub_state {
                HowdySubState::Scanning => "🔍 Scanning...".into(),
                HowdySubState::Success => "✓ Authenticated".into(),
                HowdySubState::Failed => "✗ Face not recognized".into(),
            },
            IslandState::Recording { .. } => "⏺ Recording".into(),
            IslandState::AgentRunning { source, task, .. } => {
                let src = match source {
                    AgentSource::OpenCode => "opencode",
                    AgentSource::Omp => "omp",
                };
                format!("⚙ {src}: {task}")
            }
            IslandState::AgentResult { source, task, success, .. } => {
                let src = match source {
                    AgentSource::OpenCode => "opencode",
                    AgentSource::Omp => "omp",
                };
                let icon = if *success { "✓" } else { "✗" };
                format!("{icon} {src}: {task}")
            }
        }
    }

    /// Get a reference to the current state
    pub fn current_state(&self) -> &IslandState {
        &self.current
    }
}
