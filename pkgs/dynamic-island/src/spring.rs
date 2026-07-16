//! Single-parameter spring animation system.
//! All properties share the same spring constants (spring: 4.0, damping: 0.82).
//! Assignment IS animation – setting a new target preserves velocity and
//! continues toward the new target (interruptible).

/// Spring constants (shared globally)
const SPRING_K: f32 = 180.0;
const DAMPING: f32 = 0.78;
const EPSILON: f32 = 0.5; // settle threshold (pixels)

#[derive(Debug, Clone, Copy)]
pub struct Spring {
    pub value: f32,
    pub target: f32,
    velocity: f32,
}

impl Spring {
    pub fn new(initial: f32) -> Self {
        Self {
            value: initial,
            target: initial,
            velocity: 0.0,
        }
    }

    /// Set new target – velocity is preserved (interruptible)
    pub fn set_target(&mut self, target: f32) {
        self.target = target;
    }

    /// Snap to value immediately (no animation)
    pub fn snap(&mut self, value: f32) {
        self.value = value;
        self.target = value;
        self.velocity = 0.0;
    }

    /// Returns true if still animating
    pub fn is_active(&self) -> bool {
        (self.value - self.target).abs() > EPSILON || self.velocity.abs() > EPSILON
    }

    /// Advance by dt seconds. Returns true if value changed.
    pub fn tick(&mut self, dt: f32) -> bool {
        if !self.is_active() {
            if self.value != self.target {
                self.value = self.target;
                self.velocity = 0.0;
                return true;
            }
            return false;
        }

        // Critically-damped spring: F = -k*x - c*v
        // where x = value - target, c = 2*damping*sqrt(k)
        let displacement = self.value - self.target;
        let c = 2.0 * DAMPING * SPRING_K.sqrt();
        let acceleration = -SPRING_K * displacement - c * self.velocity;

        // Semi-implicit Euler integration
        self.velocity += acceleration * dt;
        self.value += self.velocity * dt;

        true
    }
}

/// A 2D spring for (width, height) morphing
#[derive(Debug, Clone, Copy)]
pub struct Spring2D {
    pub x: Spring,
    pub y: Spring,
}

impl Spring2D {
    pub fn new(x: f32, y: f32) -> Self {
        Self {
            x: Spring::new(x),
            y: Spring::new(y),
        }
    }

    pub fn set_target(&mut self, x: f32, y: f32) {
        self.x.set_target(x);
        self.y.set_target(y);
    }

    pub fn snap(&mut self, x: f32, y: f32) {
        self.x.snap(x);
        self.y.snap(y);
    }

    pub fn is_active(&self) -> bool {
        self.x.is_active() || self.y.is_active()
    }

    pub fn tick(&mut self, dt: f32) -> bool {
        let a = self.x.tick(dt);
        let b = self.y.tick(dt);
        a || b
    }

    pub fn value(&self) -> (f32, f32) {
        (self.x.value, self.y.value)
    }

    /// Construct with current value (no animation target set separately)
    pub fn from_value(x: f32, y: f32) -> Self {
        Self::new(x, y)
    }

    /// Alias for tick() — used in main loop
    pub fn step(&mut self, dt: f32) -> bool {
        self.tick(dt)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn spring_settles() {
        let mut s = Spring::new(0.0);
        s.set_target(100.0);
        for _ in 0..300 {
            s.tick(1.0 / 60.0);
        }
        assert!((s.value - 100.0).abs() < EPSILON);
        assert!(!s.is_active());
    }

    #[test]
    fn spring_interruptible() {
        let mut s = Spring::new(0.0);
        s.set_target(100.0);
        // Advance partway
        for _ in 0..30 {
            s.tick(1.0 / 60.0);
        }
        let vel_before = s.velocity;
        // Interrupt
        s.set_target(50.0);
        // Velocity should be preserved
        assert_eq!(s.velocity, vel_before);
    }
}
