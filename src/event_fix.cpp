#include <rex/ppc/context.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xevent.h>
#include <rex/memory.h>
#include <rex/logging.h>
#include <atomic>

// Called after sub_82349710 clears the guest dispatch header's SignalState.
// The host event is separate from that header, so it needs the same reset.
void sw2_clear_host_event(PPCRegister& address) {
  auto* kernel = REX_KERNEL_STATE();
  auto* guest_event = kernel->memory()->TranslateVirtual<rex::system::X_KEVENT*>(address.u32);
  auto event = rex::system::XObject::GetNativeObject<rex::system::XEvent>(kernel, guest_event);
  if (!event) {
    REXLOG_ERROR("Inline event reset: no host event for {:08X}", address.u32);
    return;
  }
  event->Clear();
  static std::atomic<unsigned> reset_count{0};
  if (reset_count.fetch_add(1, std::memory_order_relaxed) < 8) {
    REXLOG_INFO("Inline event reset synchronized: guest={:08X}", address.u32);
  }
}
