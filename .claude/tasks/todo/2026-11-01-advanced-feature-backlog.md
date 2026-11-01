# Task: Advanced feature backlog (ESP32 + app)
**Added By**: mostafiz9900 (with Claude)
**Date Added**: 2026-11-01
**Priority**: 🟡 Medium
**Module**: node_setup, hall_map, hall, firmware/esp32, report, session
**Estimated Effort**: Large (split into one task per item when picked up)
**Assigned To**: unassigned

## Description
Ideas agreed with the owner to build later. Not started. The owner's
suggested order is at the bottom. Already done, so not in this list: hall
map, BLE fingerprint/rotation grouping (2026-10-18), and Bluetooth node setup.

### ESP32 — firmware only (no new hardware)
1. **Wi-Fi probe-request sniffing** ⭐
   - Phones with Wi-Fi on send probe requests even when unconnected, so this catches phones with Bluetooth off.
   - Use ESP32 promiscuous mode.
   - Send the probe count and RSSI as a new sighting kind.
   - MAC randomisation means: report "new phone signal" and strength, not an exact count.
2. **Bluetooth OTA firmware update from the app.** Update every node with no computer.
3. **Node health.** Report firmware version, uptime, RSSI to the host and last-seen time. Warn before power runs out.

### ESP32 + cheap module
4. **Cellular call/data detector** using an AD8317/AD8318 RF log-detector into the ESP32 ADC. Catches 900/1800 MHz bursts from phones not in airplane mode.
5. **Neck-loop / induction earpiece detector** using a pickup coil and an op-amp into the ADC. Detects audio-frequency magnetic fields.
6. **Tamper alert** using an MPU6050. Alert when a node is moved, flipped or covered.
7. **Node battery %** using a voltage divider on the ADC.

### App — software only
8. **Exam replay.** A time slider over the hall map showing where devices were and when.
9. **Seat heatmap** of suspicious signal across the whole exam.
10. **Smartwatch vibration alerts** for invigilators.
11. **Tamper-evident report.** Signed PDF with a QR code to verify it.
12. **Student roster CSV + seats.** Link incidents to roll numbers.
13. **Controller dashboard** for several halls, with escalation.
14. **Per-room normal-pattern learning** with an anomaly score.
15. **Kiosk mode + PIN** during the exam.

## Suggested order
1. #1 Wi-Fi probe
2. #4 RF call detector
3. #8 replay + #9 heatmap
4. #2 OTA + #3 health
5. #11 + #12

## Acceptance Criteria
- [ ] Each item picked up becomes its own task with a plan in .claude/tasks/plans/
- [ ] Owner confirms which hardware modules were bought before #4–#7

## Notes
- Owner hasn't bought the ESP32 yet. Buy the #4–#6 modules in the same shop visit.
- The firmware builds with PlatformIO. Libraries are already downloaded in firmware/esp32/.pio.
- The hall protocol is v1. New sighting kinds must stay backward compatible: old apps ignore unknown `tx`.

## Related Files
- firmware/esp32/src/main.cpp, firmware/esp32/README.md
- lib/features/hall/repository/hall_protocol.dart
- lib/features/hall_map/, lib/features/node_setup/
- .claude/modules/node_setup.md, .claude/modules/hall_map.md
