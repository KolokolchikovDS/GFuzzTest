#include "fuzztest/fuzztest.h"
#include "gtest/gtest.h"

#include <array>
#include <atomic>
#include <complex>
#include <cstdint>
#include <deque>
#include <iostream>
#include <list>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <tuple>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <variant>
#include <vector>

// no-op that keeps the compiler from optimizing away the parameters, so that
// all the generated values are truly "consumed" by the property function.
template <typename... Ts>
void KeepAlive(Ts&&...) {}

// ---------------------------------------------------------------------------
// Native scalar types via Arbitrary<T>()
// ---------------------------------------------------------------------------
void IntDoesNotCrash(int x) { KeepAlive(x); }
FUZZ_TEST(ArbitrarySuite, IntDoesNotCrash);

void Uint8DoesNotCrash(uint8_t x) { KeepAlive(x); }
FUZZ_TEST(ArbitrarySuite, Uint8DoesNotCrash);

void Int64DoesNotCrash(int64_t x) { KeepAlive(x); }
FUZZ_TEST(ArbitrarySuite, Int64DoesNotCrash);

void FloatDoesNotCrash(float f) { KeepAlive(f); }
FUZZ_TEST(ArbitrarySuite, FloatDoesNotCrash);

void DoubleDoesNotCrash(double d) { KeepAlive(d); }
FUZZ_TEST(ArbitrarySuite, DoubleDoesNotCrash);

void BoolDoesNotCrash(bool b) { KeepAlive(b); }
FUZZ_TEST(ArbitrarySuite, BoolDoesNotCrash);

void StringDoesNotCrash(std::string s) { KeepAlive(s); }
FUZZ_TEST(ArbitrarySuite, StringDoesNotCrash);

// ---------------------------------------------------------------------------
// InRange / numeric helper domains
// ---------------------------------------------------------------------------
void InRangeNeverLeavesBounds(int v) { ASSERT_GE(v, -100); ASSERT_LE(v, 100); }
FUZZ_TEST(NumericSuite, InRangeNeverLeavesBounds)
    .WithDomains(fuzztest::InRange(-100, 100))
    .WithSeeds({{-100}, {0}, {100}});

void PositiveIsPositive(int v) { ASSERT_GT(v, 0); }
FUZZ_TEST(NumericSuite, PositiveIsPositive)
    .WithDomains(fuzztest::Positive<int>());

void NonNegativeIsNonNegative(int v) { ASSERT_GE(v, 0); }
FUZZ_TEST(NumericSuite, NonNegativeIsNonNegative)
    .WithDomains(fuzztest::NonNegative<int>());

void NegativeIsNegative(int v) { ASSERT_LT(v, 0); }
FUZZ_TEST(NumericSuite, NegativeIsNegative)
    .WithDomains(fuzztest::Negative<int>());

void NonPositiveIsNonPositive(int v) { ASSERT_LE(v, 0); }
FUZZ_TEST(NumericSuite, NonPositiveIsNonPositive)
    .WithDomains(fuzztest::NonPositive<int>());

void NonZeroIsNonZero(int v) { ASSERT_NE(v, 0); }
FUZZ_TEST(NumericSuite, NonZeroIsNonZero).WithDomains(fuzztest::NonZero<int>());

void FiniteIsFinite(double d) { ASSERT_TRUE(std::isfinite(d)); }
FUZZ_TEST(NumericSuite, FiniteIsFinite).WithDomains(fuzztest::Finite<double>());

void FloatDomainFinite(float f) { ASSERT_TRUE(std::isfinite(f)); }
FUZZ_TEST(NumericSuite, FloatDomainFinite).WithDomains(fuzztest::Finite<float>());

void PositiveDoubleIsPositive(double d) { ASSERT_GT(d, 0.0); }
FUZZ_TEST(NumericSuite, PositiveDoubleIsPositive)
    .WithDomains(fuzztest::Positive<double>());

void InRangeFloatStaysInRange(float f) { ASSERT_GE(f, 0.0f); ASSERT_LE(f, 1.0f); }
FUZZ_TEST(NumericSuite, InRangeFloatStaysInRange)
    .WithDomains(fuzztest::InRange(0.0f, 1.0f));

// ---------------------------------------------------------------------------
// ElementOf / Just / OneOf
// ---------------------------------------------------------------------------
void ElementOfOnlyFromList(int v) {
  ASSERT_TRUE(v == 0xDEADBEEF || v == 0xBADDCAFE || v == 0xFEEDFACE);
}
FUZZ_TEST(SelectionSuite, ElementOfOnlyFromList)
    .WithDomains(fuzztest::ElementOf({0xDEADBEEF, 0xBADDCAFE, 0xFEEDFACE}));

void ElementOfVectorFromList(int v) {
  ASSERT_TRUE(v == 1 || v == 2 || v == 3);
}
FUZZ_TEST(SelectionSuite, ElementOfVectorFromList)
    .WithDomains(fuzztest::ElementOf(std::vector<int>{1, 2, 3}));

void ElementOfArrayFromList(int v) { ASSERT_EQ(v, 42); }
FUZZ_TEST(SelectionSuite, ElementOfArrayFromList)
    .WithDomains(fuzztest::ElementOf(std::array<int, 1>{42}));

void JustAlwaysSame(int v) { ASSERT_EQ(v, 7); }
FUZZ_TEST(SelectionSuite, JustAlwaysSame).WithDomains(fuzztest::Just(7));

void OneOfPicksValidValue(int v) { ASSERT_TRUE(v == 1 || v == 2 || v == 3); }
FUZZ_TEST(SelectionSuite, OneOfPicksValidValue)
    .WithDomains(fuzztest::OneOf(fuzztest::Just(1), fuzztest::Just(2),
                                 fuzztest::Just(3)));

// ---------------------------------------------------------------------------
// Filter / OverlapOf
// ---------------------------------------------------------------------------
void FilteredIsNeverSentinel(int v) { ASSERT_NE(v, 99); }
FUZZ_TEST(FilterSuite, FilteredIsNeverSentinel)
    .WithDomains(fuzztest::Filter([](int x) { return x != 99; },
                                  fuzztest::Arbitrary<int>()));

void OverlapIsBoth(int v) { ASSERT_NE(v, 0); ASSERT_GE(v, -10); ASSERT_LE(v, 10); }
FUZZ_TEST(FilterSuite, OverlapIsBoth)
    .WithDomains(fuzztest::OverlapOf(fuzztest::InRange(-10, 10),
                                     fuzztest::NonZero<int>()));

// ---------------------------------------------------------------------------
// BitFlagCombinationOf
// ---------------------------------------------------------------------------
enum class Options {
  kFirst = 1 << 0,
  kSecond = 1 << 1,
  kThird = 1 << 2,
};

void BitFlagsOnlyUseCombinations(Options o) { KeepAlive(o); }
FUZZ_TEST(BitFlagSuite, BitFlagsOnlyUseCombinations)
    .WithDomains(fuzztest::BitFlagCombinationOf({Options::kFirst, Options::kThird}));

// ---------------------------------------------------------------------------
// Char / string domains
// ---------------------------------------------------------------------------
void NonZeroCharTest(char c) { ASSERT_NE(c, 0); }
FUZZ_TEST(CharSuite, NonZeroCharTest).WithDomains(fuzztest::NonZeroChar());

void AsciiCharTest(char c) { ASSERT_GE(c, 0); ASSERT_LE(c, 127); }
FUZZ_TEST(CharSuite, AsciiCharTest).WithDomains(fuzztest::AsciiChar());

void PrintableAsciiCharTest(char c) { ASSERT_GE(c, 32); ASSERT_LE(c, 126); }
FUZZ_TEST(CharSuite, PrintableAsciiCharTest)
    .WithDomains(fuzztest::PrintableAsciiChar());

void NumericCharTest(char c) { ASSERT_GE(c, '0'); ASSERT_LE(c, '9'); }
FUZZ_TEST(CharSuite, NumericCharTest).WithDomains(fuzztest::NumericChar());

void LowerCharTest(char c) { ASSERT_GE(c, 'a'); ASSERT_LE(c, 'z'); }
FUZZ_TEST(CharSuite, LowerCharTest).WithDomains(fuzztest::LowerChar());

void UpperCharTest(char c) { ASSERT_GE(c, 'A'); ASSERT_LE(c, 'Z'); }
FUZZ_TEST(CharSuite, UpperCharTest).WithDomains(fuzztest::UpperChar());

void AlphaCharTest(char c) {
  bool is_letter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
  ASSERT_TRUE(is_letter);
}
FUZZ_TEST(CharSuite, AlphaCharTest).WithDomains(fuzztest::AlphaChar());

void AlphaNumericCharTest(char c) {
  bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9');
  ASSERT_TRUE(ok);
}
FUZZ_TEST(CharSuite, AlphaNumericCharTest)
    .WithDomains(fuzztest::AlphaNumericChar());

void StringOfOnlyLower(std::string s) {
  for (char c : s) {
    ASSERT_GE(c, 'a');
    ASSERT_LE(c, 'z');
  }
}
FUZZ_TEST(StringSuite, StringOfOnlyLower)
    .WithDomains(fuzztest::StringOf(fuzztest::LowerChar()).WithMaxSize(10));

void AsciiStringOnlyAscii(std::string s) {
  for (char c : s) {
    ASSERT_GE(c, 0);
    ASSERT_LE(c, 127);
  }
}
FUZZ_TEST(StringSuite, AsciiStringOnlyAscii)
    .WithDomains(fuzztest::AsciiString().WithMinSize(0).WithMaxSize(20));

void PrintableAsciiStringOnlyPrintable(std::string s) {
  for (char c : s) {
    ASSERT_GE(c, 32);
    ASSERT_LE(c, 126);
  }
}
FUZZ_TEST(StringSuite, PrintableAsciiStringOnlyPrintable)
    .WithDomains(fuzztest::PrintableAsciiString().WithSize(5));

void Utf8StringIsValid(std::string s) { KeepAlive(s); }
FUZZ_TEST(StringSuite, Utf8StringIsValid).WithDomains(fuzztest::Utf8String());

void InRegexpMatchesDate(std::string s) { KeepAlive(s); }
FUZZ_TEST(StringSuite, InRegexpMatchesDate)
    .WithDomains(fuzztest::InRegexp("[0-9]{4}-[0-9]{2}-[0-9]{2}"));

void StringWithSeedsWorks(std::string s) { KeepAlive(s); }
FUZZ_TEST(StringSuite, StringWithSeedsWorks)
    .WithDomains(fuzztest::String().WithSeeds(
        std::vector<std::string>{"hello", "world", "fuzz"}));

// ---------------------------------------------------------------------------
// Containers
// ---------------------------------------------------------------------------
void VectorOfIntWorks(std::vector<int> v) { KeepAlive(v); }
FUZZ_TEST(ContainerSuite, VectorOfIntWorks)
    .WithDomains(fuzztest::VectorOf(fuzztest::InRange(0, 100)).WithSize(4));

void ContainerOfDeque(std::deque<int> d) { KeepAlive(d); }
FUZZ_TEST(ContainerSuite, ContainerOfDeque)
    .WithDomains(fuzztest::DequeOf(fuzztest::Arbitrary<int>()).WithMaxSize(8));

void ContainerOfList(std::list<std::string> l) { KeepAlive(l); }
FUZZ_TEST(ContainerSuite, ContainerOfList)
    .WithDomains(fuzztest::ListOf(fuzztest::AsciiString()).WithMaxSize(4));

void SetOfHasUniqueElements(std::set<int> s) {
  ASSERT_EQ(s.size(), static_cast<size_t>(
                          std::distance(s.begin(), s.end())));
}
FUZZ_TEST(ContainerSuite, SetOfHasUniqueElements)
    .WithDomains(fuzztest::SetOf(fuzztest::InRange(0, 50)).WithMaxSize(10));

void MapOfWorks(std::map<int, std::string> m) { KeepAlive(m); }
FUZZ_TEST(ContainerSuite, MapOfWorks)
    .WithDomains(fuzztest::MapOf(fuzztest::InRange(0, 100),
                                 fuzztest::AsciiString())
                     .WithMaxSize(6));

void UnorderedSetOfWorks(std::unordered_set<int> s) { KeepAlive(s); }
FUZZ_TEST(ContainerSuite, UnorderedSetOfWorks)
    .WithDomains(fuzztest::UnorderedSetOf(fuzztest::Arbitrary<int>())
                     .WithMaxSize(6));

void UnorderedMapOfWorks(std::unordered_map<int, int> m) { KeepAlive(m); }
FUZZ_TEST(ContainerSuite, UnorderedMapOfWorks)
    .WithDomains(fuzztest::UnorderedMapOf(fuzztest::InRange(0, 10),
                                          fuzztest::InRange(0, 10))
                     .WithMaxSize(5));

void ArrayOfWorks(std::array<int, 2> a) { KeepAlive(a); }
FUZZ_TEST(ContainerSuite, ArrayOfWorks)
    .WithDomains(fuzztest::ArrayOf(fuzztest::InRange(0, 100),
                                   fuzztest::InRange(1, 12)));

void ArrayOfNWorks(std::array<double, 3> a) { KeepAlive(a); }
FUZZ_TEST(ContainerSuite, ArrayOfNWorks)
    .WithDomains(fuzztest::ArrayOf<3>(fuzztest::InRange(0.0, 1.0)));

void ContainerOfCustomType(std::vector<uint8_t> v) { KeepAlive(v); }
FUZZ_TEST(ContainerSuite, ContainerOfCustomType)
    .WithDomains(fuzztest::ContainerOf<std::vector<uint8_t>>(
        fuzztest::Arbitrary<uint8_t>()).WithMaxSize(16));

void UniqueElementsVectorOfWorks(std::vector<int> v) {
  std::set<int> unique(v.begin(), v.end());
  ASSERT_EQ(v.size(), unique.size());
}
FUZZ_TEST(ContainerSuite, UniqueElementsVectorOfWorks)
    .WithDomains(fuzztest::UniqueElementsVectorOf(fuzztest::InRange(0, 1000))
                     .WithSize(6));

void UniqueElementsContainerOfWorks(std::vector<int> v) {
  std::set<int> unique(v.begin(), v.end());
  ASSERT_EQ(v.size(), unique.size());
}
FUZZ_TEST(ContainerSuite, UniqueElementsContainerOfWorks)
    .WithDomains(
        fuzztest::UniqueElementsContainerOf<std::vector<int>>(
            fuzztest::InRange(0, 100))
            .WithMinSize(1)
            .WithMaxSize(5));

void NonEmptyNeverEmpty(std::string s) { ASSERT_FALSE(s.empty()); }
FUZZ_TEST(ContainerSuite, NonEmptyNeverEmpty)
    .WithDomains(fuzztest::NonEmpty(fuzztest::AsciiString()));

// ---------------------------------------------------------------------------
// Tuples, pairs, variants, optionals, structs
// ---------------------------------------------------------------------------
void PairOfWorks(std::pair<int, std::string> p) { KeepAlive(p); }
FUZZ_TEST(AggregateSuite, PairOfWorks)
    .WithDomains(fuzztest::PairOf(fuzztest::InRange(0, 10),
                                  fuzztest::AsciiString()))
    .WithSeeds({{std::make_tuple(std::pair{3, "abc"})},
                {std::make_tuple(std::pair{7, "xyz"})}});

void TupleOfWorks(int a, std::string b, bool c) { KeepAlive(a, b, c); }
FUZZ_TEST(AggregateSuite, TupleOfWorks)
    .WithDomains(fuzztest::TupleOf(fuzztest::InRange(0, 10),
                                   fuzztest::AsciiString(),
                                   fuzztest::Arbitrary<bool>()));

void VariantOfWorks(std::variant<int, std::string> v) { KeepAlive(v); }
FUZZ_TEST(AggregateSuite, VariantOfWorks)
    .WithDomains(
        fuzztest::VariantOf(fuzztest::InRange(0, 10), fuzztest::AsciiString()));

void OptionalOfWorks(std::optional<int> o) {
  if (o.has_value()) {
    ASSERT_GE(*o, 0);
    ASSERT_LE(*o, 100);
  }
}
FUZZ_TEST(AggregateSuite, OptionalOfWorks)
    .WithDomains(fuzztest::OptionalOf(fuzztest::InRange(0, 100)));

void NullOptAlwaysNull(std::optional<int> o) { ASSERT_FALSE(o.has_value()); }
FUZZ_TEST(AggregateSuite, NullOptAlwaysNull)
    .WithDomains(fuzztest::NullOpt<int>());

void NonNullNeverNull(std::optional<int> o) { ASSERT_TRUE(o.has_value()); }
FUZZ_TEST(AggregateSuite, NonNullNeverNull)
    .WithDomains(fuzztest::NonNull(fuzztest::OptionalOf(fuzztest::InRange(0, 10))));

struct Thing {
  int id;
  std::string name;
};

void StructOfWorks(Thing t) {
  ASSERT_GE(t.id, 0);
  ASSERT_LE(t.id, 100);
  KeepAlive(t.name);
}
FUZZ_TEST(AggregateSuite, StructOfWorks)
    .WithDomains(fuzztest::StructOf<Thing>(fuzztest::InRange(0, 100),
                                           fuzztest::AsciiString()));

// ---------------------------------------------------------------------------
// Smart pointers
// ---------------------------------------------------------------------------
void UniquePtrOfWorks(std::unique_ptr<int> p) {
  if (p) {
    ASSERT_GE(*p, 0);
    ASSERT_LE(*p, 10);
  }
}
FUZZ_TEST(PointerSuite, UniquePtrOfWorks)
    .WithDomains(fuzztest::UniquePtrOf(fuzztest::InRange(0, 10)));

void SharedPtrOfWorks(std::shared_ptr<std::string> p) {
  if (p) KeepAlive(*p);
}
FUZZ_TEST(PointerSuite, SharedPtrOfWorks)
    .WithDomains(fuzztest::SharedPtrOf(fuzztest::AsciiString()));

void SmartPointerOfWorks(std::unique_ptr<double> p) {
  if (p) ASSERT_TRUE(std::isfinite(*p));
}
FUZZ_TEST(PointerSuite, SmartPointerOfWorks)
    .WithDomains(fuzztest::SmartPointerOf<std::unique_ptr<double>>(
        fuzztest::Finite<double>()));

// ---------------------------------------------------------------------------
// Map / ReversibleMap / FlatMap / ConstructorOf
// ---------------------------------------------------------------------------
void MapDoubles(int v) {
  ASSERT_GE(v, 0);
  ASSERT_LE(v, 200);
}
FUZZ_TEST(MapSuite, MapDoubles)
    .WithDomains(fuzztest::Map([](int i) { return 2 * i; },
                               fuzztest::InRange(0, 100)));

void ReversibleMapComplex(std::complex<double> z) {
  ASSERT_TRUE(std::isfinite(z.real()));
  ASSERT_TRUE(std::isfinite(z.imag()));
}
FUZZ_TEST(MapSuite, ReversibleMapComplex)
    .WithDomains(fuzztest::ReversibleMap(
        [](double real, double imag) {
          return std::complex<double>{real, imag};
        },
        [](std::complex<double> z) {
          return std::optional{std::tuple{z.real(), z.imag()}};
        },
        fuzztest::Finite<double>(), fuzztest::Finite<double>()));

void FlatMapEqualSizeStrings(std::pair<std::string, std::string> p) {
  ASSERT_EQ(p.first.size(), p.second.size());
}
FUZZ_TEST(MapSuite, FlatMapEqualSizeStrings)
    .WithDomains(fuzztest::FlatMap(
        [](int size) {
          return fuzztest::PairOf(fuzztest::AsciiString().WithSize(size),
                                  fuzztest::AsciiString().WithSize(size));
        },
        fuzztest::InRange(0, 10)));

class Rectangle {
 public:
  Rectangle(int w, int h) : w_(w), h_(h) {}
  int Area() const { return w_ * h_; }

 private:
  int w_;
  int h_;
};

void ConstructorOfWorks(Rectangle r) { KeepAlive(r.Area()); }
FUZZ_TEST(MapSuite, ConstructorOfWorks)
    .WithDomains(fuzztest::ConstructorOf<Rectangle>(fuzztest::InRange(0, 100),
                                                    fuzztest::InRange(0, 100)));

// ---------------------------------------------------------------------------
// DomainBuilder (recursive data structures)
// ---------------------------------------------------------------------------
struct TreeNode {
  int value;
  std::vector<TreeNode> children;
};

fuzztest::Domain<TreeNode> TreeNodeDomain() {
  fuzztest::DomainBuilder builder;
  auto node = builder.Get<TreeNode>("node");
  builder.Set("node",
              fuzztest::Domain<TreeNode>(fuzztest::StructOf<TreeNode>(
                  fuzztest::InRange(0, 10),
                  fuzztest::ContainerOf<std::vector<TreeNode>>(node)
                      .WithMaxSize(3))));
  return std::move(builder).Finalize<TreeNode>("node");
}

void RecursiveTreeNeverCrashes(TreeNode root) { KeepAlive(root.value); }
FUZZ_TEST(DomainBuilderSuite, RecursiveTreeNeverCrashes)
    .WithDomains(TreeNodeDomain());

// ---------------------------------------------------------------------------
// Fixture-based fuzz tests
// ---------------------------------------------------------------------------
class CounterFixture {
 public:
  CounterFixture() : count_(0) {}
  void FixtureIncrements(int x) {
    IncrementBy(x);
    ASSERT_GE(Count(), 0);
  }

 private:
  void IncrementBy(int x) { count_ += x; }
  long long Count() const { return count_; }
  long long count_ = 0;
};
FUZZ_TEST_F(CounterFixture, FixtureIncrements)
    .WithDomains(fuzztest::NonNegative<int>())
    .WithSeeds({{0}, {1}, {5}});

// ---------------------------------------------------------------------------
// Many-parameter fuzz test + domain-level seeds + dictionary
// ---------------------------------------------------------------------------
void ManyParameters(int a, std::string b, double c, bool d,
                    std::vector<int> e) {
  ASSERT_GE(a, 0);
  ASSERT_LE(a, 100);
  ASSERT_TRUE(std::isfinite(c));
  ASSERT_LE(e.size(), static_cast<size_t>(10));
  KeepAlive(b, d);
}
FUZZ_TEST(MultiParamSuite, ManyParameters)
    .WithDomains(fuzztest::InRange(0, 100).WithSeeds(std::vector{1, 5, 50}),
                 fuzztest::String().WithDictionary(
                     std::vector<std::string>{"alpha", "beta", "gamma"}),
                 fuzztest::Finite<double>(),
                 fuzztest::Arbitrary<bool>(),
                 fuzztest::VectorOf(fuzztest::InRange(0, 10)).WithMaxSize(10))
    .WithSeeds({{0, "hello", 0.5, true, {1, 2, 3}},
                {10, "world", -1.25, false, {}}});

// ---------------------------------------------------------------------------
// Custom domain: small vectors of bounded reals + dot product
// ---------------------------------------------------------------------------
using Vec = std::vector<double>;

// A custom domain for a vector whose coordinates are all generated from a
// bounded real domain. Min/max size are pinned so both vectors are short and
// negative dot products are common.
fuzztest::Domain<Vec> VecDomain() {
  return fuzztest::VectorOf(fuzztest::InRange(-10.0, 10.0))
      .WithMinSize(1)
      .WithMaxSize(4);
}

std::string ToString(const Vec& v) {
  std::ostringstream oss;
  oss << "[";
  for (size_t i = 0; i < v.size(); ++i) {
    if (i != 0) oss << ", ";
    oss << v[i];
  }
  oss << "]";
  return oss.str();
}

// Logs the exact inputs fed to the property on every iteration, plus the
// computed result. The monotonic counter makes each line greppable and lets us
// confirm that a fresh (different) vector pair is generated on every iteration.
std::atomic<int> g_input_log_count{0};

double DotProduct(const Vec& a, const Vec& b) {
  const size_t n = a.size() < b.size() ? a.size() : b.size();
  double sum = 0.0;
  for (size_t i = 0; i < n; ++i) sum += a[i] * b[i];
  return sum;
}

// Property that deliberately FAILS whenever the dot product is negative.
void DotProductNeverNegative(const Vec& a, const Vec& b) {
  const double dot = DotProduct(a, b);
  std::cout << "[iter " << g_input_log_count.fetch_add(1)
            << "] a=" << ToString(a) << "  b=" << ToString(b)
            << "  -> dot=" << dot << std::endl;
  ASSERT_GE(dot, 0.0) << "Dot product must not be negative, but got " << dot;
}
FUZZ_TEST(DotProductSuite, DotProductNeverNegative)
    .WithDomains(VecDomain(), VecDomain());

// Same custom domain, but only checks the result is finite so the property
// PASSES for the whole run and we can inspect a longer stream of distinct
// generated inputs (and confirm it changes between runs).
void DotProductLogsVaryingInputs(const Vec& a, const Vec& b) {
  const double dot = DotProduct(a, b);
  std::cout << "[iter " << g_input_log_count.fetch_add(1)
            << "] a=" << ToString(a) << "  b=" << ToString(b)
            << "  -> dot=" << dot << std::endl;
  ASSERT_TRUE(std::isfinite(dot));
}
FUZZ_TEST(DotProductSuite, DotProductLogsVaryingInputs)
    .WithDomains(VecDomain(), VecDomain())
    .WithSeeds({{Vec{1.0, 2.0}, Vec{3.0, 4.0}}});

// ---------------------------------------------------------------------------
// unstable::ParseReproducerValue - just instantiates the template.
// ---------------------------------------------------------------------------
TEST(UnstableApi, ParseReproducerValueInstantiates) {
  auto res = fuzztest::unstable::ParseReproducerValue(
      "garbage", fuzztest::InRange(0, 100), fuzztest::AsciiString());
  (void)res;
}