#pragma once

namespace rex::system {
class KernelState;
}

// Installs every STFS package below --sw2_dlc_root. Does nothing when the
// option is omitted.
void sw2_install_requested_dlc(rex::system::KernelState* kernel_state);
