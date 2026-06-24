# Noctalia v5: PAM Authentication & Howdy Integration

**Research Date:** 2026-06-22
**Status:** ⚠️ V5 is alpha software — API and behavior may change

---

## Executive Summary

**Noctalia v5 does NOT support `NOCTALIA_PAM_SERVICE` (or any custom PAM service name).** The lock screen hardcodes `"login"` as the PAM service. For howdy facial recognition, you have two options: (1) add howdy to `/etc/pam.d/login`, or (2) patch v5 to read from an environment variable.

---

## 1. V5 Architecture: Complete Rewrite

Noctalia v5 is a **native C++23** application built on Wayland + OpenGL ES, launched via the `noctalia` binary. It is NOT the QML-based `noctalia-shell` from v4 — none of v4's environment variables or configuration patterns apply.

|                        | v4 (`noctalia-shell`)   | v5 (`noctalia`)           |
|------------------------|-------------------------|---------------------------|
| Language               | QML + Quickshell        | C++23 + OpenGL ES         |
| Config format          | QML/JS                  | TOML                      |
| Lock protocol          | ext-session-lock-v1     | ext-session-lock-v1       |
| PAM env var            | `NOCTALIA_PAM_SERVICE`  | **NOT SUPPORTED**         |
| Fingerprint            | Via PAM (pam_fprintd)   | Via D-Bus (direct fprintd)|
| Launch binary          | `qs` / `noctalia-qs`    | `noctalia`                |

---

## 2. Evidence: PAM Service is Hardcoded

### 2.1 Lock Screen Authentication (`src/shell/lockscreen/lock_screen.cpp`)

**Evidence** ([source](https://github.com/noctalia-dev/noctalia/blob/main/src/shell/lockscreen/lock_screen.cpp#L693-L702)):

```cpp
void LockScreen::tryAuthenticate() {
  // ...
  const PamAuthenticator authenticator = m_authenticator;
  // Authenticate against the "login" stack. If fingerprint is enabled, strip
  // pam_fprintd from it: noctalia drives the reader itself over D-Bus and the
  // two can't share the sensor. See docs/fingerprint.md.
  const std::string pamService = "login";   // ← HARDCODED
  std::thread([this, generation, password = std::move(password), authenticator, pamService]() mutable {
    const auto result = authenticator.authenticateCurrentUser(password, pamService);
    // ...
  }).detach();
}
```

**Explanation:** The PAM service name is a literal string `"login"`. There is no environment variable lookup, no config option, and no branch that could produce a different value at runtime.

### 2.2 PAM Authenticator API Supports Custom Service (But Not Used)

**Evidence** ([source](https://github.com/noctalia-dev/noctalia/blob/main/src/auth/pam_authenticator.h#L12)):

```cpp
[[nodiscard]] Result authenticateCurrentUser(
    std::string_view password,
    std::string_view service = "login"   // ← default, but configurable
) const;
```

**Explanation:** The API *can* accept any service name — the infrastructure is there. But the lock screen always passes `"login"`. A one-line patch in `lock_screen.cpp` would enable reading from an environment variable.

### 2.3 Implicit Fallback in Authentication

**Evidence** ([source](https://github.com/noctalia-dev/noctalia/blob/main/src/auth/pam_authenticator.cpp#L184-L186)):

```cpp
if (service.empty()) {
    service = "login";
}
```

**Explanation:** If `service` were ever passed as empty, it defaults to `"login"`.

### 2.4 FAQ Confirms Behavior

**Evidence** ([source](https://docs.noctalia.dev/v5/getting-started/faq/#why-cant-i-unlock-my-lock-screen)):

> Noctalia v5 authenticates through PAM using the `login` service. Make sure `/etc/pam.d/login` exists and is valid for your distribution.
>
> If you changed your PAM stack for fingerprint, security key, or other authentication methods, make sure those changes are present in the `login` PAM service used by Noctalia.

### 2.5 Zero References to NOCTALIA_PAM_SERVICE

Searched the entire `noctalia-dev/noctalia` C++ source for `NOCTALIA_PAM`, `pamConfig`, `pamService`, and `pam_service` — **zero results** in the v5 C++ codebase. These terms only exist in the legacy QML-based v4 codebase (`noctalia-dev/noctalia-shell`).

---

## 3. V5 Lock Screen Config Schema

From the official `[lockscreen]` TOML schema and `example.toml`:

**Evidence** ([source: docs](https://docs.noctalia.dev/v5/configuration/shell/#lock-screen), [source: example.toml](https://github.com/noctalia-dev/noctalia/blob/main/example.toml#L165-L172)):

```toml
[lockscreen]
enabled               = true      # master switch for session lock
fingerprint           = true      # D-Bus fprintd integration (NOT PAM)
allow_empty_password  = false     # submit Enter with empty password
blurred_desktop       = false     # desktop capture background
blur_intensity        = 0.5       # 0.0 = none, 1.0 = max
tint_intensity        = 0.3       # surface-color tint
wallpaper             = ""        # optional custom lock image
monitors              = []        # connector filter; empty = all
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Master switch for session lock |
| `fingerprint` | bool | `true` | Enables **direct D-Bus fprintd** integration (NOT via PAM) |
| `allow_empty_password` | bool | `false` | Allow empty password submission |
| `blurred_desktop` | bool | `false` | Use desktop snapshot as background |
| `blur_intensity` | float | `0.5` | Background blur 0.0–1.0 |
| `tint_intensity` | float | `0.3` | Surface tint 0.0–1.0 |
| `wallpaper` | string | `""` | Custom lock screen image path |
| `monitors` | array | `[]` | Connector names for lock screen |

**Critical finding:** There is NO `pam_service` key in the schema. The fingerprint option controls Noctalia's own D-Bus fprintd integration, not PAM module behavior.

---

## 4. How Noctalia v5 Handles Fingerprint

V5 **directly** communicates with `org.freedesktop.fprintd` over D-Bus (not through PAM). This is architecturally different from v4:

```
V4 flow:  User → LockScreen → PAM → pam_fprintd.so → fprintd
V5 flow:  User → LockScreen → fprintd (D-Bus) [integrated]
                    ↳ PAM "login" (password only)
```

**Evidence** from `src/auth/fingerprint_authenticator.cpp`: The `FingerprintAuthenticator` class connects to fprintd over D-Bus, calls `Claim()`, `VerifyStart()`, and `Release()` directly — bypassing PAM entirely.

This means `pam_fprintd.so` in `/etc/pam.d/login` would **conflict** with v5's own fprintd driver. V5 even strips pam_fprintd from the stack per the comment in `tryAuthenticate()`.

---

## 5. Howdy Integration Approaches

### Approach A: Add howdy to `/etc/pam.d/login` (Simplest)

Since v5 uses the `login` PAM service, add howdy's PAM module to `/etc/pam.d/login`:

```pam
# /etc/pam.d/login
auth     sufficient  pam_howdy.so
auth     required    pam_unix.so try_first_pass nullok
account  required    pam_unix.so
session  required    pam_unix.so
password required    pam_unix.so
```

**Pros:**
- Zero code changes to Noctalia
- Standard PAM stacking semantics
- Works on NixOS and non-NixOS

**Caveats:**
- Disable v5's `fingerprint = false` if you're using howdy for face (not fprintd fingerprint)
- The lock screen UI won't show "Scanning face..." — it'll just show the password field
- depends on howdy's camera access working under the Wayland session-lock context

### Approach B: Dedicated PAM service (Requires Patch)

Patch `src/shell/lockscreen/lock_screen.cpp` to read `NOCTALIA_PAM_SERVICE`:

```cpp
// In tryAuthenticate(), replace:
const std::string pamService = "login";
// With:
const std::string pamService = []() -> std::string {
    const char* env = std::getenv("NOCTALIA_PAM_SERVICE");
    return (env != nullptr && env[0] != '\0') ? env : "login";
}();
```

Then create `/etc/pam.d/noctalia` with howdy:

```pam
# /etc/pam.d/noctalia
auth     sufficient  pam_howdy.so
auth     required    pam_unix.so try_first_pass nullok
account  required    pam_unix.so
session  required    pam_unix.so
password required    pam_unix.so
```

Set `NOCTALIA_PAM_SERVICE=noctalia` in the systemd service environment.

**Pros:**
- Clean separation from system login
- Future-proof if upstream adds this feature
- The `authenticateCurrentUser` API already accepts a service parameter

### Approach C: Wait for Plugin System

V5 has a plugin system "under active development" per the README. A community or official plugin could expose PAM service configuration without patching.

---

## 6. NixOS-Specific Notes

### Current v4 Approach (for reference)

```nix
# /etc/pam.d/noctalia (defined in NixOS config)
security.pam.services.noctalia = {
  text = ''
    auth sufficient pam_howdy.so
    auth required pam_unix.so try_first_pass nullok
  '';
};

systemd.user.services.noctalia = {
  environment = {
    NOCTALIA_PAM_SERVICE = "noctalia";
  };
};
```

### V5 Path Forward

For v5, either:
1. Add `pam_howdy.so` to the `login` PAM service via `security.pam.services.login.text` (if not overriding system defaults)
2. Or use a Nix overlay to patch the v5 source to support `NOCTALIA_PAM_SERVICE`

---

## 7. Key Source File Map

| File | Purpose | Key Finding |
|------|---------|-------------|
| `src/shell/lockscreen/lock_screen.cpp` | Lock screen logic | PAM service hardcoded to `"login"` |
| `src/shell/lockscreen/lock_screen.h` | Lock screen header | Declares `tryAuthenticate()` |
| `src/auth/pam_authenticator.cpp` | PAM wrapper (forks child process) | Calls `pam_start(service, user, ...)` |
| `src/auth/pam_authenticator.h` | PAM API | `authenticateCurrentUser(password, service = "login")` |
| `src/auth/fingerprint_authenticator.cpp` | D-Bus fprintd integration | Direct fprintd, NOT via PAM |
| `example.toml` | Default config | `[lockscreen]` has no `pam_service` key |

---

## 8. Recommendations

1. **Short-term:** Use Approach A (add `pam_howdy.so` to `/etc/pam.d/login`, set `fingerprint = false`). This works today with zero code changes.

2. **Medium-term:** Upstream a PR that adds `NOCTALIA_PAM_SERVICE` support. The API already accepts a custom service name — the change would be ~5 lines in `lock_screen.cpp`.

3. **V5 Greeter:** Note that the separate `noctalia-greeter` project (for display manager login) may have different PAM behavior. Check its docs if you need greeter-level howdy support too.
