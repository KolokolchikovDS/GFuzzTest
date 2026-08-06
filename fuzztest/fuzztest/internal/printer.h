// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// IWYU pragma: private, include "fuzztest/fuzztest.h"
// IWYU pragma: friend fuzztest/.*

#ifndef FUZZTEST_FUZZTEST_INTERNAL_PRINTER_H_
#define FUZZTEST_FUZZTEST_INTERNAL_PRINTER_H_

#include "absl/strings/str_format.h"
#include "./fuzztest/internal/meta.h"

namespace fuzztest::domain_implementor {

// The type used for sink objects passed to PrintCorpusValue and PrintUserValue
// formatting functions of domain printers.
using RawSink = absl::FormatRawSink;

// The mode that determines how a domain printer's formatting function should
// format the value.
enum class PrintMode {
  // The value should be formatted as human-readable.
  kHumanReadable,

  // The value should be formatted as valid source code, e.g., to appear in a
  // reproducer test.
  kSourceCode
};

// Detects whether the printer exposes a PrintCorpusValue member. Uses the
// void_t detection idiom (rather than std::is_invocable on a generic lambda),
// which MSVC handles correctly even when PrintCorpusValue is a member
// function template.
template <typename Printer, typename CorpusT, typename = void>
struct has_print_corpus_value : std::false_type {};

template <typename Printer, typename CorpusT>
struct has_print_corpus_value<
    Printer, CorpusT,
    std::void_t<decltype(std::declval<const Printer&>().PrintCorpusValue(
        std::declval<const CorpusT&>(), std::declval<RawSink>(),
        std::declval<PrintMode>()))>> : std::true_type {};

template <typename Printer, typename CorpusT>
inline constexpr bool has_print_corpus_value_v =
    has_print_corpus_value<Printer, CorpusT>::value;

// Invokes PrintCorpusValue or PrintUserValue from the domain's type printer,
// depending on what's available. It will automatically call GetValue if needed
// for the PrintUserValue call.
template <typename Domain>
void PrintValue(const Domain& domain,
                const internal::corpus_type_t<Domain>& corpus_value,
                RawSink out, PrintMode mode) {
  auto printer = domain.GetPrinter();
  if constexpr (has_print_corpus_value_v<decltype(printer),
                                         internal::corpus_type_t<Domain>>) {
    printer.PrintCorpusValue(corpus_value, out, mode);
  } else {
    printer.PrintUserValue(domain.GetValue(corpus_value), out, mode);
  }
}

}  // namespace fuzztest::domain_implementor

#endif  // FUZZTEST_FUZZTEST_INTERNAL_PRINTER_H_
