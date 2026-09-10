#include <rex/ppc/context.h>
#include <rex/logging.h>
#include <Windows.h>
#include <array>
#include <cstdio>
#include <mutex>
#include <map>

namespace {
struct Entry {
  unsigned site, thread, previous, block, next, segment, tail, heap, source;
};
std::mutex history_mutex;
std::array<Entry, 128> history{};
size_t count = 0;
struct Allocation { uint32_t size, flags; bool freed; };
std::map<uint32_t, Allocation> allocations;
bool DiagnosticsEnabled() {
  static const bool enabled = [] {
    char value[2]{};
    return GetEnvironmentVariableA("SW2_HEAP_DIAGNOSTICS", value, sizeof(value)) == 1
        && value[0] == '1';
  }();
  return enabled;
}

void Snapshot(FILE* file, const char* label, uint32_t guest) {
  // This build's arena base is confirmed by the runtime logs and crash dump.
  // ReadProcessMemory safely reports unavailable pages rather than faulting.
  std::array<unsigned char, 128> bytes{};
  SIZE_T read = 0;
  const auto host = reinterpret_cast<const void*>(0x100000000ULL + guest);
  std::fprintf(file, "%s guest=%08X\n", label, guest);
  if (!ReadProcessMemory(GetCurrentProcess(), host, bytes.data(), bytes.size(), &read)) {
    std::fprintf(file, "unreadable error=%lu\n", GetLastError());
    return;
  }
  for (size_t i = 0; i < read; ++i) {
    std::fprintf(file, "%02X%s", bytes[i], (i % 16 == 15) ? "\n" : " ");
  }
}

void Record(unsigned site, PPCRegister& r9, PPCRegister& r10, PPCRegister& r11,
            PPCRegister& r26, PPCRegister& r28, PPCRegister& r29, PPCRegister& r31) {
  if (!DiagnosticsEnabled()) return;
  std::lock_guard lock(history_mutex);
  history[count++ % history.size()] = {site, GetCurrentThreadId(), r9.u32, r10.u32,
      r11.u32, r26.u32, r28.u32, r29.u32, r31.u32};
  if (r9.u32 != 0) return;
  FILE* file = nullptr;
  if (fopen_s(&file, "heap-diagnostics.txt", "a") == 0) {
    std::fprintf(file, "\nNull free-list link; recent insertions (oldest first):\n");
    const auto start = count > history.size() ? count - history.size() : 0;
    for (size_t i = start; i < count; ++i) {
      const auto& e = history[i % history.size()];
      std::fprintf(file, "site=%08X thread=%u prev=%08X block=%08X next=%08X segment=%08X tail=%08X heap=%08X source=%08X\n",
          e.site, e.thread, e.previous, e.block, e.next, e.segment, e.tail, e.heap, e.source);
    }
    Snapshot(file, "heap", r29.u32);
    Snapshot(file, "segment", r26.u32);
    Snapshot(file, "source", r31.u32);
    Snapshot(file, "tail", r28.u32);
    Snapshot(file, "list node", r11.u32);
    std::fclose(file);
  }
  REXLOG_ERROR("Heap diagnostics: null free-list link at {:08X}; heap={:08X}, node={:08X}. See heap-diagnostics.txt",
               site, r29.u32, r11.u32);
}
}

void sw2_heap_insert_first(PPCRegister& r9, PPCRegister& r10, PPCRegister& r11,
    PPCRegister& r26, PPCRegister& r28, PPCRegister& r29, PPCRegister& r31) {
  Record(0x8231D22C, r9, r10, r11, r26, r28, r29, r31);
}
void sw2_heap_insert_second(PPCRegister& r9, PPCRegister& r10, PPCRegister& r11,
    PPCRegister& r26, PPCRegister& r28, PPCRegister& r29, PPCRegister& r31) {
  Record(0x8231D328, r9, r10, r11, r26, r28, r29, r31);
}

void sw2_track_allocation(PPCRegister& pointer, PPCRegister& size, PPCRegister& flags) {
  if (!DiagnosticsEnabled()) return;
  if (!pointer.u32) return;
  std::lock_guard lock(history_mutex);
  allocations[pointer.u32] = {size.u32, flags.u32, false};
}

void sw2_track_free(PPCRegister& pointer, PPCRegister& flags) {
  if (!DiagnosticsEnabled()) return;
  if (!pointer.u32) return;
  std::lock_guard lock(history_mutex);
  auto exact = allocations.find(pointer.u32);
  if (exact != allocations.end() && !exact->second.freed) {
    exact->second.freed = true;
    return;
  }
  FILE* file = nullptr;
  if (fopen_s(&file, "allocation-diagnostics.txt", "a") != 0) return;
  std::fprintf(file, "\n%s free pointer=%08X flags=%08X thread=%lu\n",
      exact != allocations.end() ? "REPEATED" : "UNTRACKED", pointer.u32,
      flags.u32, GetCurrentThreadId());
  auto upper = allocations.upper_bound(pointer.u32);
  if (upper != allocations.begin()) {
    const auto& [address, entry] = *std::prev(upper);
    std::fprintf(file, "preceding allocation=%08X size=%08X flags=%08X freed=%d offset=%08X\n",
        address, entry.size, entry.flags, entry.freed, pointer.u32-address);
  }
  if (upper != allocations.end()) {
    std::fprintf(file, "next allocation=%08X size=%08X freed=%d\n",
        upper->first, upper->second.size, upper->second.freed);
  }
  void* frames[20]{};
  const auto frame_count = CaptureStackBackTrace(0, 20, frames, nullptr);
  const auto module = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
  std::fprintf(file, "EXE base=%llX; native frame offsets:\n", static_cast<unsigned long long>(module));
  for (USHORT i = 0; i < frame_count; ++i) {
    std::fprintf(file, "%llX\n", static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(frames[i])-module));
  }
  Snapshot(file, "before free", pointer.u32-16);
  std::fclose(file);
}
