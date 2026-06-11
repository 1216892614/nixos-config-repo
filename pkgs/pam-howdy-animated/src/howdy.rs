use libloading::{Library, Symbol};
use std::ffi::CString;
use std::os::raw::c_int;
use std::path::Path;

/// PAM return codes
pub const PAM_SUCCESS: c_int = 0;
pub const PAM_AUTH_ERR: c_int = 7;
pub const PAM_IGNORE: c_int = 25;

/// Type alias for pam_sm_authenticate function signature
/// int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv)
type PamSmAuthenticate =
    unsafe extern "C" fn(*mut libc::c_void, c_int, c_int, *const *const libc::c_char) -> c_int;

/// Build-time injected path (set via PAM_HOWDY_PATH env during compilation)
const HOWDY_PAM_BUILD_PATH: Option<&str> = option_env!("PAM_HOWDY_PATH");

/// Fallback paths to search at runtime
const HOWDY_PAM_PATHS: &[&str] = &["/run/current-system/sw/lib/security/pam_howdy.so"];

/// Find the howdy PAM module path.
/// Priority: module args → build-time path → env var → known paths.
pub fn find_howdy_pam_path(args: &[String]) -> Option<String> {
    // Check args for explicit path
    for arg in args {
        if let Some(path) = arg.strip_prefix("howdy_path=") {
            if Path::new(path).exists() {
                return Some(path.to_string());
            }
        }
    }

    // Check build-time injected path
    if let Some(path) = HOWDY_PAM_BUILD_PATH {
        if Path::new(path).exists() {
            return Some(path.to_string());
        }
    }

    // Check environment variable (set by Nix wrapper)
    if let Ok(path) = std::env::var("PAM_HOWDY_PATH") {
        if Path::new(&path).exists() {
            return Some(path);
        }
    }

    // Fallback to known paths
    for path in HOWDY_PAM_PATHS {
        if Path::new(path).exists() {
            return Some(path.to_string());
        }
    }

    None
}

/// Call pam_howdy.so's pam_sm_authenticate via dlopen.
///
/// # Safety
/// This function loads a shared library and calls a C function.
/// The pamh handle must be valid.
pub unsafe fn call_pam_howdy(howdy_path: &str, pamh: *mut libc::c_void, flags: c_int) -> c_int {
    // Load the howdy PAM library
    let lib = match Library::new(howdy_path) {
        Ok(lib) => lib,
        Err(_) => return PAM_AUTH_ERR,
    };

    // Look up pam_sm_authenticate
    let func: Symbol<PamSmAuthenticate> = match lib.get(b"pam_sm_authenticate\0") {
        Ok(f) => f,
        Err(_) => return PAM_AUTH_ERR,
    };

    // Call howdy's pam_sm_authenticate with no extra args
    func(pamh, flags, 0, std::ptr::null())
}
