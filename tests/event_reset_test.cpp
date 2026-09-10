#include <rex/system/xevent.h>
#include <cstdio>

// Exercise the installed SDK, with a manual-reset event like the game's.
// No game, graphics, or kernel state is required for InitializeNative/Query.
int main() {
  rex::system::X_KEVENT guest{};
  guest.header.type = 0;
  guest.header.signal_state = 1;
  rex::system::XEvent event(nullptr);
  event.InitializeNative(&guest, &guest.header);
  uint32_t state = 0;
  event.Query(nullptr, &state);
  if (state != 1) return 1;

  // Original PPC implementation: stw zero,4(event).
  guest.header.signal_state = 0;
  event.Query(nullptr, &state);
  if (state != 1) return 2;
  std::puts("Reproduced: guest SignalState=0 leaves host event signaled.");

  // The added hook performs this host reset after the original PPC store.
  event.Clear();
  event.Query(nullptr, &state);
  if (state != 0 || guest.header.signal_state != 0) return 3;
  std::puts("Passed: Clear resets the host event too.");

  // A subsequent signal must still be delivered, and reset remains repeatable.
  for (unsigned i = 0; i != 100; ++i) {
    event.Set(0, false);
    event.Query(nullptr, &state);
    if (state != 1) return 4;
    guest.header.signal_state = 0;
    event.Clear();
    event.Query(nullptr, &state);
    if (state != 0) return 5;
  }
  std::puts("Passed: 100 signal/reset cycles.");
  return 0;
}
