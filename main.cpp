#include "fuzztest/fuzztest.h"
#include "gtest/gtest.h"

#include <exception>


void PassOnlyPositiveNumbers(int val)
{
    if (val < 0) {
        throw std::runtime_error("TEST FAIL");
    }
}

void MyFuzzTest(int input)
{
    SCOPED_TRACE(testing::Message() << "input = " << input);
    ASSERT_NO_THROW(PassOnlyPositiveNumbers(input));
}

FUZZ_TEST(MyTestSuite, MyFuzzTest)
.WithDomains(fuzztest::InRange(-50, 50));