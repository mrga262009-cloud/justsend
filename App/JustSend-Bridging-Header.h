//
//  JustSend-Bridging-Header.h
//  Generated header from `cargo run -p cbindgen` (RustCore).
//  Keep the committed copy as a fallback for Xcode Previews.
//
#ifndef JustSend_Bridging_Header_h
#define JustSend_Bridging_Header_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char *ptr;
    int32_t len;
} JSString;

extern void js_string_free(JSString s);
extern JSString js_validate_catalog(const char *ptr, int32_t len);
extern JSString js_normalize_catalog(const char *ptr, int32_t len);
extern JSString js_ci_chain(const char *ptr, int32_t len);
extern JSString js_version(void);

#ifdef __cplusplus
}
#endif

#endif /* JustSend_Bridging_Header_h */
