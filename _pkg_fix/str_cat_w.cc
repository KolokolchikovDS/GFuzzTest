#include <string>

#include "absl/strings/str_cat.h"

// The consumer's fuzztest/abseil headers are a fork that renames the abseil
// StrCat() overloads to StrCatW() (wide/Unicode convention). The consolidated
// fuzztest.lib was built from the stock abseil, which exports StrCat() only.
// Provide StrCatW() overloads forwarding to the corresponding StrCat() so the
// packaged lib satisfies both names.

namespace absl {
ABSL_NAMESPACE_BEGIN

std::string StrCatW(const AlphaNum& a, const AlphaNum& b) {
  return StrCat(a, b);
}

std::string StrCatW(const AlphaNum& a, const AlphaNum& b, const AlphaNum& c) {
  return StrCat(a, b, c);
}

std::string StrCatW(const AlphaNum& a, const AlphaNum& b, const AlphaNum& c,
                    const AlphaNum& d) {
  return StrCat(a, b, c, d);
}

ABSL_NAMESPACE_END
}  // namespace absl