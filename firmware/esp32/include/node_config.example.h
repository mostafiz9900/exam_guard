// ExamGuard sensor node — optional build-time defaults.
//
// You normally DON'T need this file: set the node up from a phone instead
// (hold BOOT 3 s → join Wi-Fi "ExamGuard-Setup-…" → fill in the page).
// Settings saved there are kept on the board and win over these defaults.
//
// To bake defaults into the firmware, copy this file to node_config.h
// (git-ignored: it would hold your hotspot password and node key).
#pragma once

// Hotspot of the host invigilator phone (or the hall Wi-Fi). Empty = set
// it on the setup page.
#define WIFI_SSID ""
#define WIFI_PASSWORD ""

// App: Hall link → Host this hall → Sensor nodes. Empty = setup page.
#define NODE_KEY ""

// Empty = automatic, e.g. "ExamGuard-Node-A1B2C3". A custom name always
// starts with "ExamGuard" (added if missing) so phones trust the node.
#define NODE_NAME ""

// Empty = the Wi-Fi gateway, i.e. the host phone running the hotspot.
// Set the host phone's address when everyone uses a shared hall router.
#define HUB_HOST ""
#define HUB_PORT 47800

// Password of the "ExamGuard-Setup-…" Wi-Fi (at least 8 characters).
#define SETUP_PASSWORD "examguard"

// Pins of a standard ESP32 DevKit.
#define LED_PIN 2
#define BOOT_BUTTON_PIN 0
