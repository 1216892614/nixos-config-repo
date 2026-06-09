//! PAM module entry point for pam_howdy_animated.
//!
//! This module wraps howdy's PAM authentication with a terminal animation
//! that displays a camera-style recording indicator during face scanning.
//!
//! When a TTY is available (terminal sudo), it shows:
//!   SCANNING → CHECK (success) or FAIL (failure)
//!
//! When no TTY is available (GDM, polkit), it silently delegates to pam_howdy.

mod animation;
mod howdy;

use std::ffi::CStr;
use std::os::raw::c_int;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use howdy::{PAM_IGNORE, PAM_SUCCESS};

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

    if !has_tty() {
        // No terminal available (GDM, polkit, etc.) — silent pass-through
        return howdy::call_pam_howdy(&howdy_path, pamh, flags);
    }

    // Terminal available — show animation
    let anim = match animation::Animation::from_dev_tty() {
        Some(a) => a,
        None => {
            // Can't open tty for animation, fall back to silent
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
