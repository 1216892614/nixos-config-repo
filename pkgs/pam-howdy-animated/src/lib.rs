//! PAM module entry point for pam_howdy_animated.
//!
//! This module wraps howdy's PAM authentication with a terminal animation
//! that displays a camera-style recording indicator during face scanning.
//!
//! When a TTY is available (terminal sudo), it shows:
//!   SCANNING → CHECK (success) or FAIL (failure)
//!
//! When no TTY is available (lock screen, polkit), it delegates to pam_howdy
//! with PAM_SILENT flag to suppress error messages that would confuse
//! GUI PAM clients (e.g., Noctalia Shell lock screen).
mod animation;
mod howdy;

use std::ffi::CStr;
use std::fs;
use std::os::raw::c_int;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use howdy::{PAM_IGNORE, PAM_SUCCESS};

/// PAM flag: suppress messages from modules
const PAM_SILENT: c_int = 0x8000;

/// Check if we have access to a controlling terminal
fn has_tty() -> bool {
    std::fs::OpenOptions::new()
        .write(true)
        .open("/dev/tty")
        .is_ok()
}

/// Parse PAM module arguments from argc/argv into a Vec<String>
unsafe fn parse_args(argc: c_int, argv: *const *const libc::c_char) -> Vec<String> {
    let mut args = Vec::new();
    if argv.is_null() {
        return args;
    }
    for i in 0..argc as isize {
        let ptr = *argv.offset(i);
        if ptr.is_null() {
            break;
        }
        if let Ok(s) = CStr::from_ptr(ptr).to_str() {
            args.push(s.to_string());
        }
    }
    args
}

/// Write howdy status to `/run/user/<UID>/howdy-status.json` for UI overlay
fn write_status(state: &str, success: Option<bool>) {
    // Get UID from real user (not effective after sudo)
    let uid = unsafe { libc::getuid() };
    let status_path = format!("/run/user/{}/howdy-status.json", uid);
    
    let json = if let Some(s) = success {
        format!(r#"{{"state":"{}","success":{}}}"#, state, s)
    } else {
        format!(r#"{{"state":"{}"}}"#, state)
    };
    
    // Best-effort write (if fails, island just won't update)
    let _ = fs::write(&status_path, json);
}

/// PAM entry point: pam_sm_authenticate
///
/// # Safety
/// Called by the PAM framework with a valid pam_handle_t.
#[no_mangle]
pub unsafe extern "C" fn pam_sm_authenticate(
    pamh: *mut libc::c_void,
    flags: c_int,
    argc: c_int,
    argv: *const *const libc::c_char,
) -> c_int {
    let args = parse_args(argc, argv);

    // Find howdy PAM module
    let howdy_path = match howdy::find_howdy_pam_path(&args) {
        Some(p) => p,
        None => return PAM_IGNORE, // howdy not found, skip
    };
    
    // Notify island: howdy starting
    write_status("scanning", None);

    if !has_tty() {
        // No terminal available (lock screen, polkit, etc.)
        // Pass PAM_SILENT to suppress howdy's error messages (e.g., "Failure, timeout reached")
        // which would otherwise be relayed to GUI PAM clients and cause confusion.
        let result = howdy::call_pam_howdy(&howdy_path, pamh, flags | PAM_SILENT);
        
        // Notify island: result
        write_status("ended", Some(result == PAM_SUCCESS));
        
        // In non-TTY mode: if howdy fails, return PAM_IGNORE instead of PAM_AUTH_ERR.
        // This prevents GUI lock screens from counting it as a failed attempt,
        // allowing clean fallback to password without triggering retry loops.
        if result != PAM_SUCCESS {
            return PAM_IGNORE;
        }
        return result;
    }

    // Terminal available — show animation
    let anim = match animation::Animation::from_dev_tty() {
        Some(a) => a,
        None => {
            // Can't open tty for animation, fall back to direct call
            return howdy::call_pam_howdy(&howdy_path, pamh, flags);
        }
    };

    // Start scanning animation in a background thread (single writer)
    let stop_flag = Arc::new(AtomicBool::new(false));
    let stop_clone = Arc::clone(&stop_flag);

    let anim_thread = std::thread::spawn(move || {
        let mut anim = anim;
        anim.run_scanning_loop(&stop_clone);
        anim // return ownership back
    });

    // Call howdy authentication (blocking)
    let result = howdy::call_pam_howdy(&howdy_path, pamh, flags);

    // Stop animation and get the handle back
    stop_flag.store(true, Ordering::Relaxed);
    let mut anim = anim_thread.join().unwrap_or_else(|_| {
        // If thread panicked, create a fresh handle for cleanup
        animation::Animation::from_dev_tty().unwrap()
    });

    // Show result
    match result {
        PAM_SUCCESS => anim.show_check(),
        _ => anim.show_fail(),
    }
    
    // Notify island: result
    write_status("ended", Some(result == PAM_SUCCESS));

    result
}

/// PAM entry point: pam_sm_setcred (required, but we don't use it)
#[no_mangle]
pub unsafe extern "C" fn pam_sm_setcred(
    _pamh: *mut libc::c_void,
    _flags: c_int,
    _argc: c_int,
    _argv: *const *const libc::c_char,
) -> c_int {
    PAM_SUCCESS
}

/// PAM entry point: pam_sm_acct_mgmt (required for some configurations)
#[no_mangle]
pub unsafe extern "C" fn pam_sm_acct_mgmt(
    _pamh: *mut libc::c_void,
    _flags: c_int,
    _argc: c_int,
    _argv: *const *const libc::c_char,
) -> c_int {
    PAM_IGNORE
}
