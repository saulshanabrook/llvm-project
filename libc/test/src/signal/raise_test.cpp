//===----------------------- Unittests for raise --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "include/signal.h"
#include "src/signal/raise.h"
#include "utils/UnitTest/Test.h"

TEST(SignalTest, Raise) {
  // SIGCONT is ingored unless stopped, so we can use it to check the return
  // value of raise without needing to block.
  EXPECT_EQ(__llvm_libc::raise(SIGCONT), 0);
}
