# LD_PRELOAD shim that intercepts pa_context_get_card_info_list/by_index.
#
# Steam's bundled libaudio.so (compiled ~2012) crashes in its PulseAudio card
# info callback when used with PipeWire because the pa_card_info struct layout
# has changed. Rather than replacing libpulse (which doesn't help — the bug is
# in libaudio.so's own callback code), we simply prevent the crashing functions
# from ever being called.
#
# We build BOTH 32-bit and 64-bit versions because Steam spawns a mix of
# i686 (main UI bootstrapper) and x86_64 (steamwebhelper, pressure-vessel)
# processes. LD_PRELOAD with both lets ld.so silently skip the wrong-ELF one.
{ pkgs }:

let
  src = pkgs.writeText "steam_pulse_fix.c" ''
    /* Fix Steam crash: "Assertion 'pa_atomic_load(&(o)->_ref) >= 1' failed
     * at pulse/operation.c:68, function pa_operation_unref(). Aborting."
     *
     * PipeWire's libpulse compatibility layer has a race condition where
     * pa_operation objects can be double-unreffed. We intercept pa_operation_unref
     * to silently ignore the call when ref is already <= 0 instead of aborting.
     *
     * We also still intercept pa_context_get_card_info_list/by_index as the
     * original Steam libaudio.so card enumeration crash workaround.
     */
    #define _GNU_SOURCE
    #include <stddef.h>
    #include <stdint.h>
    #include <dlfcn.h>

    /* Minimal pa_operation layout matching PulseAudio internals.
     * First field is the atomic ref count (int). */
    struct pa_operation_min {
        int _ref;
        /* rest doesn't matter for our purposes */
    };

    /* Intercept pa_operation_unref: skip if ref is already <= 0. */
    void pa_operation_unref(void *o) {
        if (!o) return;
        struct pa_operation_min *op = (struct pa_operation_min *)o;
        if (op->_ref <= 0) return;  /* prevent the assert + abort */

        /* Call the real implementation */
        static void (*real_unref)(void *) = NULL;
        if (!real_unref) {
            real_unref = dlsym(RTLD_NEXT, "pa_operation_unref");
            if (!real_unref) return;
        }
        real_unref(o);
    }

    /* Still intercept card info to avoid the libaudio.so callback crash. */
    static struct pa_operation_min fake_op = { ._ref = 9999 };

    void* pa_context_get_card_info_list(void *c, void *cb, void *userdata) {
        (void)c; (void)cb; (void)userdata;
        return &fake_op;
    }

    void* pa_context_get_card_info_by_index(void *c, unsigned idx, void *cb, void *userdata) {
        (void)c; (void)idx; (void)cb; (void)userdata;
        return &fake_op;
    }
  '';

  build32 = pkgs.pkgsCross.gnu32.stdenv.mkDerivation {
    pname = "steam-pulse-fix-32";
    version = "1.1.0";
    inherit src;
    dontUnpack = true;
    dontMoveSlib = true;
    buildPhase = ''
      $CC -shared -fPIC -ldl -o steam_pulse_fix32.so $src
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp steam_pulse_fix32.so $out/lib/
    '';
  };

  build64 = pkgs.stdenv.mkDerivation {
    pname = "steam-pulse-fix-64";
    version = "1.1.0";
    inherit src;
    dontUnpack = true;
    dontMoveSlib = true;
    buildPhase = ''
      $CC -shared -fPIC -ldl -o steam_pulse_fix64.so $src
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp steam_pulse_fix64.so $out/lib/
    '';
  };
in
pkgs.symlinkJoin {
  name = "steam-pulse-fix-1.1.0";
  paths = [ build32 build64 ];
  meta = {
    description = "LD_PRELOAD fix for Steam PulseAudio card info crash on PipeWire (32+64 bit)";
    platforms = [ "x86_64-linux" ];
  };
}
