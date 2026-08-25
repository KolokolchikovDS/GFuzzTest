#include <string>

#include "absl/strings/str_cat.h"

// Simulate the consumer's fork headers which declare StrCatW() and reference
// it from fuzztest container_of_impl.h (VectorOf). We only declare it here;
// the definition must come from the packaged fuzztest.lib.
namespace absl {
ABSL_NAMESPACE_BEGIN
std::string StrCatW(const AlphaNum& a, const AlphaNum& b);
std::string StrCatW(const AlphaNum& a, const AlphaNum& b, const AlphaNum& c,
                    const AlphaNum& d);
ABSL_NAMESPACE_END
}  // namespace absl

int main() {
  using absl::AlphaNum;
  // Mimic container_of_impl.h lines 345/349 (4-arg) and 357 (2-arg).
  std::string s4 = absl::StrCatW(AlphaNum("Invalid size: "),
                                 AlphaNum((unsigned long long)5),
                                 AlphaNum(". Min size: "),
                                 AlphaNum((unsigned long long)1));
  std::string s2 =
      absl::StrCatW(AlphaNum("Invalid value at index "), AlphaNum(3));
  return static_cast<int>(s4.size() + s2.size()) == 0;
}