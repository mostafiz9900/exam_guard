# ESP32 sensor node — easy connect + dashboard card

## Goal
User has not bought the board yet. After buying: flash once, then connect it
from the app in a minute, no second phone, no typing the node key.

## Approach
- **Bluetooth setup (new)**: in setup mode the node is a GATT server
  (service `e9a40001-…`). The app finds it, reads info + Wi-Fi networks the
  node sees, writes `{ssid, pass, key, name, hub}`; the node tests the Wi-Fi
  and the host phone live and reports each step (`status` notify), then saves
  and restarts. The old "ExamGuard-Setup" web page stays as a fallback.
- Node key is filled in by the app (hall `nodeKey`) — never typed.
- Hotspot name remembered (not the password).

## Files
- firmware/esp32/src/main.cpp, README.md
- firmware/esp32/tools/fake_node.dart (try the dashboard without hardware)
- lib/core/services/bluetooth/i_ble_gatt.dart + ble_gatt_impl.dart (GATT wrapper)
- lib/features/node_setup/{model,repository,view_model,view}
- lib/features/dashboard/view/widgets/sensor_nodes_tile.dart + dashboard_screen.dart
- lib/features/hall/view/widgets/hall_node_key_card.dart ("Add a node" button)
- lib/core/navigation (routes /nodes, /nodes/add)
- assets/translations en/bn/ar
- tests: protocol, view model, screens

## Blast radius
Dashboard layout (new card), hall node card, router. Hall protocol unchanged.
