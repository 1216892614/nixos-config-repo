# 32-bit LD_PRELOAD shim that intercepts pa_context_get_card_info_list/by_index.
#
# Steam's bundled libaudio.so (compiled ~2012) crashes in its PulseAudio card
# info callback when used with PipeWire because the pa_card_info struct layout
# has changed. Rather than replacing libpulse (which doesn't help — the bug is
# in libaudio.so's own callback code), we simply prevent the crashing functions
# from ever being called.
{ pkgs }:

pkgs.pkgsCross.gnu32.stdenv.mkDerivation {
  pname = "steam-pulse-fix";
  version = "1.0.0";

  src = pkgs.writeText "steam_pulse_fix.c" ''
    /* Intercept pa_context_get_card_info_list / by_index to prevent
     * Steam libaudio.so from crashing in its card info callback.
     *
     * pa_operation layout (from PulseAudio source):
     *   int ref; void *context; void *stream; int state; ...
     * state=2 means PA_OPERATION_DONE — callers check this and skip.
     */
    #include <stddef.h>

    struct pa_operation_fake {
        int ref;
        void *context;
        void *stream;
        int state;
        void *userdata;
        void (*cb)(void);
    };

    static struct pa_operation_fake fake_op = {
        .ref = 1,
        .context = NULL,
        .stream = NULL,
        .state = 2,  /* PA_OPERATION_DONE */
        .userdata = NULL,
        .cb = NULL,
    };

    void* pa_context_get_card_info_list(void *c, void *cb, void *userdata) {
        (void)c; (void)cb; (void)userdata;
        return &fake_op;
    }

    void* pa_context_get_card_info_by_index(void *c, unsigned idx, void *cb, void *userdata) {
        (void)c; (void)idx; (void)cb; (void)userdata;
        return &fake_op;
    }
  '';

  dontUnpack = true;

  buildPhase = ''
    $CC -shared -fPIC -o steam_pulse_fix.so $src
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp steam_pulse_fix.so $out/lib/
  '';

  meta = {
    description = "LD_PRELOAD fix for Steam libaudio.so PulseAudio card info crash on PipeWire";
    platforms = [ "i686-linux" ];
  };
}
