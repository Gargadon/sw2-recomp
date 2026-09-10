# Stage crash investigation

The game reaches a stage, then crashes while moving (reported with Yukimura and
other characters). Earlier missing function entries have already been registered.

## Evidence

- `samurai_warriors_2_008.log`: null guest write in the audio cleanup thread.
- Windows dump `samurai_warriors_2.exe.5516.dmp`: fault maps to
  `sub_8231D008`, through `8231E208`, `8231BB50`, `8234C7C0`, `8234C9C0`,
  `82349020`, and worker `82310E20`.
- `allocation-diagnostics.txt`: freeing `440D369C` with flags `61820004`.
  It is an interior pointer, offset `2C` in a tracked allocation at `440D3670`
  (size `30C`, flags `61820006`) which was already freed.
- The worker waits for two events, stops/releases its audio object, then calls
  `sub_82349710` to clear both events before waiting again.
- `sub_82349710` is an inline event clear: `li r11,0; stw r11,4(r3); blr`.
  It only writes the guest dispatch header's SignalState.
- ReXGlue XEvent waits use a separate host event. Its Clear() method resets that
  event. Clearing guest memory alone does not reset the host event.

## Change

The manifest's hook at `82349714`, after the store, calls
`sw2_clear_host_event` in `src/event_fix.cpp`. It resolves the corresponding
XEvent through the runtime kernel and calls Clear(). Original PPC instructions
and register values remain intact. The first eight resets are logged.

## Validation

`tests/event_reset_test.cpp` runs against the installed SDK's XEvent. It
reproduces the stale host signal after a guest-only reset, verifies Clear()
resets the signal, and passes 100 signal/reset cycles. This establishes the
event synchronization defect, but a stage playthrough is still needed to verify
that this change resolves the reported gameplay crash.

Diagnostics are retained pending that playthrough. They observe heap operations
without skipping frees or changing guest pointers.
