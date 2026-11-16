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
