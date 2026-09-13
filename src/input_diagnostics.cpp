#include <rex/ppc/context.h>
#include <rex/system/kernel_state.h>
#include <rex/memory.h>
#include <rex/logging.h>
#include <chrono>
#include <algorithm>
#include <cstdlib>

namespace {
bool InputDiagnosticsEnabled() {
  static const bool enabled = [] {
    const char* value = std::getenv("SW2_INPUT_DIAGNOSTICS");
    return value && value[0] == '1' && value[1] == '\0';
  }();
  return enabled;
}
}

// Observe the state already read by the game. Never inject or buffer buttons.
void sw2_observe_input(PPCRegister& object, PPCRegister& success, PPCRegister& buttons) {
  if (!InputDiagnosticsEnabled()) return;
  auto* memory = REX_KERNEL_STATE()->memory();
  const auto user = *memory->TranslateVirtual<rex::be<uint32_t>*>(object.u32 + 8);
  if (user != 0) return;
  using Clock = std::chrono::steady_clock;
  struct State {
    Clock::time_point previous{}, interval{};
    uint32_t object = 0, buttons = 0;
    unsigned samples = 0, failures = 0, long_gaps = 0;
    double max_gap_ms = 0;
  };
  static thread_local State state;
  const auto now = Clock::now();
  if (state.object != object.u32) {
    state = {};
    state.object = object.u32;
    state.previous = state.interval = now;
  }
  const double gap = std::chrono::duration<double, std::milli>(now-state.previous).count();
  state.previous = now;
  state.max_gap_ms = std::max(state.max_gap_ms, gap);
  ++state.samples;
  if (gap > 100) ++state.long_gaps;
  if (!success.u32) ++state.failures;
  constexpr uint32_t tracked = 0x0100 | 0x2000; // LB and B in XINPUT_GAMEPAD.
  const uint32_t held = success.u32 ? buttons.u32 : 0;
  if (((held ^ state.buttons) & tracked) != 0) {
    REXLOG_INFO("Input sample: LB={} B={} new_LB={} new_B={} gap_ms={:.1f} valid={}",
        bool(held & 0x0100), bool(held & 0x2000),
        bool((held & ~state.buttons) & 0x0100), bool((held & ~state.buttons) & 0x2000),
        gap, bool(success.u32));
  }
  state.buttons = held;
  const double elapsed = std::chrono::duration<double>(now-state.interval).count();
  if (elapsed >= 5) {
    REXLOG_INFO("Input polling: reads_per_sec={:.1f} max_gap_ms={:.1f} gaps_over_100ms={} failures={}",
        state.samples / elapsed, state.max_gap_ms, state.long_gaps, state.failures);
    state.interval = now;
    state.samples = state.failures = state.long_gaps = 0;
    state.max_gap_ms = 0;
  }
}
