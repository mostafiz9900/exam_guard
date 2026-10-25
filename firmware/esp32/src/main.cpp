// ExamGuard sensor node.
//
// Scans BLE advertisements continuously and Wi-Fi access points every 30 s,
// and every 2 s sends the strongest devices (raw clues: manufacturer id,
// first data byte, service UUIDs, SSID) to the host phone's hall hub over a
// WebSocket. The app classifies them with the phones' own rules.
// Protocol: lib/features/hall/repository/hall_protocol.dart (v1).
//
// Setup from a phone: hold BOOT 3 s (or first start without settings) →
// Wi-Fi "ExamGuard-Setup-XXXXXX" opens for 5 minutes → fill in the page.

#include <Arduino.h>
#include <ArduinoJson.h>
#include <NimBLEDevice.h>
#include <Preferences.h>
#include <Ticker.h>
#include <WebSocketsClient.h>
#include <WiFi.h>
#include <WiFiManager.h>

#include <algorithm>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#if __has_include("node_config.h")
#include "node_config.h"
#else
#include "node_config.example.h"
#endif

namespace {

constexpr int kProtocolVersion = 1;
constexpr uint32_t kSendEveryMs = 2000;
constexpr uint32_t kWifiScanEveryMs = 30000;
// Only devices heard recently, about inside the hall, are sent.
constexpr uint32_t kFreshMs = 15000;
constexpr uint32_t kForgetMs = 30000;
constexpr int kMinRssi = -90;
constexpr size_t kMaxItems = 60;
constexpr size_t kMaxTracked = 400;
// Same smoothing as the app's scanner list (RSSI jumps ±3–6 dB per packet).
constexpr float kRssiAlpha = 0.3f;

constexpr uint32_t kSetupHoldMs = 3000;
constexpr uint32_t kSetupPortalSeconds = 300;
// Self-healing: re-join Wi-Fi, or restart when the hub stays unreachable.
constexpr uint32_t kWifiRejoinMs = 120000;
constexpr uint32_t kHubRestartMs = 600000;

// ── Settings (saved on the board, defaults from node_config.h) ──────────

struct Settings {
  String key;
  String name;
  String hub;
};

Settings gSettings;
Preferences gPrefs;
String gSuffix;  // last 3 MAC bytes, e.g. "A1B2C3"

String normalizeName(String name) {
  name.trim();
  if (name.isEmpty()) return "ExamGuard-Node-" + gSuffix;
  String lower = name;
  lower.toLowerCase();
  // Phones trust "ExamGuard…" names as ExamGuard hardware.
  return lower.startsWith("examguard") ? name : "ExamGuard-" + name;
}

void loadSettings() {
  gPrefs.begin("examguard", true);
  gSettings.key = gPrefs.getString("key", NODE_KEY);
  gSettings.name = normalizeName(gPrefs.getString("name", NODE_NAME));
  gSettings.hub = gPrefs.getString("hub", HUB_HOST);
  gPrefs.end();
  gSettings.key.trim();
  gSettings.hub.trim();
}

void saveSettings(const Settings& s) {
  gPrefs.begin("examguard", false);
  gPrefs.putString("key", s.key);
  gPrefs.putString("name", s.name);
  gPrefs.putString("hub", s.hub);
  gPrefs.end();
}

// ── LED ──────────────────────────────────────────────────────────────────
// Solid = live in a hall · fast blink = Wi-Fi OK, no hub · slow blink = no
// Wi-Fi · double blink = setup mode.

enum class LedMode { noWifi, noHub, live, setup };
volatile LedMode gLed = LedMode::noWifi;
Ticker gLedTicker;

void ledTick() {
  const uint32_t t = millis();
  bool on = false;
  switch (gLed) {
    case LedMode::live:
      on = true;
      break;
    case LedMode::noHub:
      on = (t / 200) % 2;
      break;
    case LedMode::noWifi:
      on = (t / 1000) % 2;
      break;
    case LedMode::setup: {
      const uint32_t p = t % 1200;  // on-off-on, long pause
      on = p < 150 || (p >= 300 && p < 450);
      break;
    }
  }
  digitalWrite(LED_PIN, on ? HIGH : LOW);
}

// ── Sightings ────────────────────────────────────────────────────────────

struct Sighting {
  std::string name;
  float rssi = 0;
  int companyId = -1;  // BLE manufacturer company id, -1 = none
  int firstByte = -1;  // first manufacturer data byte after the id
  std::vector<std::string> services;
  bool wifi = false;
  uint32_t lastSeenMs = 0;
};

std::map<std::string, Sighting> gSightings;  // key: "AA:BB:.." or "wifi:AA:.."
std::mutex gLock;

std::string upper(std::string s) {
  for (auto& c : s) c = toupper(static_cast<unsigned char>(c));
  return s;
}

void remember(const std::string& key, Sighting fresh) {
  std::lock_guard<std::mutex> guard(gLock);
  auto it = gSightings.find(key);
  if (it == gSightings.end()) {
    if (gSightings.size() >= kMaxTracked) return;  // full: drop newcomers
    gSightings.emplace(key, std::move(fresh));
    return;
  }
  Sighting& s = it->second;
  s.rssi += kRssiAlpha * (fresh.rssi - s.rssi);
  s.lastSeenMs = fresh.lastSeenMs;
  // Split packets: keep what earlier packets told us.
  if (!fresh.name.empty()) s.name = fresh.name;
  if (fresh.companyId >= 0) {
    s.companyId = fresh.companyId;
    s.firstByte = fresh.firstByte;
  }
  if (!fresh.services.empty()) s.services = fresh.services;
}

// ── BLE ──────────────────────────────────────────────────────────────────

class ScanCallbacks : public NimBLEScanCallbacks {
  void onResult(const NimBLEAdvertisedDevice* d) override {
    const int rssi = d->getRSSI();
    if (rssi >= 0) return;  // "unknown" level, not a reading
    Sighting s;
    s.rssi = rssi;
    s.lastSeenMs = millis();
    s.name = d->getName();
    if (d->haveManufacturerData()) {
      const std::string data = d->getManufacturerData();
      if (data.size() >= 2) {
        s.companyId = static_cast<uint8_t>(data[0]) |
                      (static_cast<uint8_t>(data[1]) << 8);
        s.firstByte = data.size() >= 3 ? static_cast<uint8_t>(data[2]) : -1;
      }
    }
    for (int i = 0; i < d->getServiceUUIDCount(); i++) {
      s.services.push_back(upper(d->getServiceUUID(i).toString()));
    }
    remember(upper(d->getAddress().toString()), std::move(s));
  }

  void onScanEnd(const NimBLEScanResults&, int) override {
    // Scanning is meant to run forever; restart if the stack stopped it.
    NimBLEDevice::getScan()->start(0, false, true);
  }
};

ScanCallbacks gScanCallbacks;

void startBle() {
  NimBLEDevice::init(gSettings.name.c_str());
  // Advertise our name so phones recognise this board as ExamGuard
  // hardware (the app trusts the "ExamGuard" prefix).
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->setName(gSettings.name.c_str());
  adv->start();

  NimBLEScan* scan = NimBLEDevice::getScan();
  scan->setScanCallbacks(&gScanCallbacks, true);  // want duplicates
  scan->setActiveScan(true);  // scan responses often carry the name
  // Leave radio time for Wi-Fi (shared antenna).
  scan->setInterval(100);
  scan->setWindow(60);
  scan->start(0, false, true);
}

// ── Wi-Fi access points ──────────────────────────────────────────────────

uint32_t gLastWifiScan = 0;

void pollWifiScan() {
  const int16_t n = WiFi.scanComplete();
  if (n == WIFI_SCAN_RUNNING) return;
  if (n >= 0) {
    for (int i = 0; i < n; i++) {
      if (WiFi.RSSI(i) >= 0) continue;
      Sighting s;
      s.wifi = true;
      s.rssi = WiFi.RSSI(i);
      s.lastSeenMs = millis();
      s.name = WiFi.SSID(i).c_str();
      remember("wifi:" + upper(WiFi.BSSIDstr(i).c_str()), std::move(s));
    }
    WiFi.scanDelete();
  }
  if (WiFi.isConnected() && millis() - gLastWifiScan >= kWifiScanEveryMs) {
    gLastWifiScan = millis();
    // Async, hidden networks too, active, 120 ms per channel: only short
    // gaps in the link.
    WiFi.scanNetworks(true, true, false, 120);
  }
}

// ── Setup page ───────────────────────────────────────────────────────────

// Opens the "ExamGuard-Setup-…" Wi-Fi for 5 minutes. Never called because
// Wi-Fi failed: only on the BOOT button or a first start, so a switched-off
// hotspot during an exam can't open a door into the node.
[[noreturn]] void runSetupPortal() {
  Serial.println("[setup] opening setup Wi-Fi for 5 minutes");
  gLed = LedMode::setup;
  if (NimBLEDevice::isInitialized()) NimBLEDevice::getScan()->stop();

  const bool hasKey = !gSettings.key.isEmpty();
  WiFiManager wm;
  WiFiManagerParameter keyField(
      "key",
      hasKey ? "Node key (empty = keep current)" : "Node key (from the app)",
      "", 40, "type='password' autocomplete='off'");
  WiFiManagerParameter nameField("name", "Node name", gSettings.name.c_str(),
                                 40);
  WiFiManagerParameter hubField(
      "hub", "Host phone address (empty when using its hotspot)",
      gSettings.hub.c_str(), 40);
  wm.addParameter(&keyField);
  wm.addParameter(&nameField);
  wm.addParameter(&hubField);

  bool saved = false;
  wm.setSaveParamsCallback([&saved] { saved = true; });
  wm.setSaveConfigCallback([&saved] { saved = true; });
  wm.setBreakAfterConfig(true);  // keep settings even if Wi-Fi test fails
  wm.setConfigPortalTimeout(kSetupPortalSeconds);
  wm.setTitle("ExamGuard sensor node");
  std::vector<const char*> menu = {"wifi", "exit"};
  wm.setMenu(menu);

  const String ap = "ExamGuard-Setup-" + gSuffix;
  Serial.printf("[setup] Wi-Fi \"%s\", password \"%s\"\n", ap.c_str(),
                SETUP_PASSWORD);
  wm.startConfigPortal(ap.c_str(), SETUP_PASSWORD);

  if (saved) {
    Settings next = gSettings;
    String key = keyField.getValue();
    key.trim();
    if (!key.isEmpty()) next.key = key;
    next.name = normalizeName(nameField.getValue());
    next.hub = hubField.getValue();
    next.hub.trim();
    saveSettings(next);
    Serial.printf("[setup] saved, node name %s\n", next.name.c_str());
  } else {
    Serial.println("[setup] closed without changes");
  }
  delay(500);
  ESP.restart();
  for (;;) {
  }
}

bool bootHeld(uint32_t forMs) {
  const uint32_t start = millis();
  while (digitalRead(BOOT_BUTTON_PIN) == LOW) {
    if (millis() - start >= forMs) return true;
    delay(20);
  }
  return false;
}

// ── Hall link ────────────────────────────────────────────────────────────

WebSocketsClient gSocket;
String gNodeId;
bool gWelcomed = false;
uint32_t gLastSend = 0;
uint32_t gRejectedUntil = 0;
uint32_t gLastWelcome = 0;

void sendHello() {
  JsonDocument doc;
  doc["t"] = "hello";
  doc["v"] = kProtocolVersion;
  doc["token"] = gSettings.key;
  JsonObject member = doc["member"].to<JsonObject>();
  member["id"] = gNodeId;
  member["name"] = gSettings.name;
  member["kind"] = "node";
  String text;
  serializeJson(doc, text);
  gSocket.sendTXT(text);
}

void sendSightings() {
  struct Item {
    std::string key;
    Sighting s;
  };
  std::vector<Item> items;
  const uint32_t now = millis();
  {
    std::lock_guard<std::mutex> guard(gLock);
    for (auto it = gSightings.begin(); it != gSightings.end();) {
      const uint32_t age = now - it->second.lastSeenMs;
      if (age > kForgetMs) {
        it = gSightings.erase(it);
        continue;
      }
      if (age <= kFreshMs && it->second.rssi >= kMinRssi) {
        items.push_back({it->first, it->second});
      }
      ++it;
    }
  }
  std::sort(items.begin(), items.end(), [](const Item& a, const Item& b) {
    return a.s.rssi > b.s.rssi;
  });
  if (items.size() > kMaxItems) items.resize(kMaxItems);

  JsonDocument doc;
  doc["t"] = "sightings";
  doc["v"] = kProtocolVersion;
  doc["from"] = gNodeId;  // the hub replaces this with the real sender
  JsonArray list = doc["items"].to<JsonArray>();
  for (const Item& item : items) {
    JsonObject o = list.add<JsonObject>();
    o["id"] = item.key;
    o["rssi"] = static_cast<int>(lroundf(item.s.rssi));
    o["tx"] = item.s.wifi ? "wifi" : "ble";
    if (!item.s.name.empty()) o["name"] = item.s.name;
    if (item.s.companyId >= 0) {
      o["mfid"] = item.s.companyId;
      if (item.s.firstByte >= 0) o["mfb"] = item.s.firstByte;
    }
    if (!item.s.services.empty()) {
      JsonArray svc = o["svc"].to<JsonArray>();
      for (const auto& u : item.s.services) svc.add(u);
    }
    // No "at": the node has no wall clock; the hub stamps arrival time.
  }
  String text;
  serializeJson(doc, text);
  gSocket.sendTXT(text);
}

void onSocketEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      Serial.println("[hall] connected, saying hello");
      gWelcomed = false;
      sendHello();
      break;
    case WStype_DISCONNECTED:
      if (gWelcomed) Serial.println("[hall] link lost, retrying");
      gWelcomed = false;
      break;
    case WStype_TEXT: {
      JsonDocument doc;
      if (deserializeJson(doc, payload, length)) return;
      const char* t = doc["t"] | "";
      if (strcmp(t, "welcome") == 0) {
        gWelcomed = true;
        gLastWelcome = millis();
        Serial.printf("[hall] joined room %s\n",
                      static_cast<const char*>(doc["room"] | ""));
      } else if (strcmp(t, "reject") == 0) {
        Serial.printf(
            "[hall] REJECTED (%s): wrong node key? Hold BOOT 3 s to fix.\n",
            static_cast<const char*>(doc["reason"] | "?"));
        // Don't hammer the hub with a wrong key.
        gRejectedUntil = millis() + 30000;
        gSocket.disconnect();
      }
      break;
    }
    default:
      break;
  }
}

void connectHub() {
  String host = gSettings.hub;
  if (host.isEmpty()) host = WiFi.gatewayIP().toString();
  Serial.printf("[hall] hub ws://%s:%d\n", host.c_str(), HUB_PORT);
  gSocket.disconnect();
  gSocket.begin(host, HUB_PORT, "/");
  gSocket.onEvent(onSocketEvent);
  gSocket.setReconnectInterval(3000);
  // The hub pings every 5 s too; this catches a hub that vanished.
  gSocket.enableHeartbeat(5000, 3000, 2);
}

}  // namespace

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);
  gLedTicker.attach_ms(50, ledTick);

  uint8_t mac[6];
  WiFi.macAddress(mac);
  char suffix[8];
  snprintf(suffix, sizeof suffix, "%02X%02X%02X", mac[3], mac[4], mac[5]);
  gSuffix = suffix;
  gNodeId = "N-" + gSuffix;

  loadSettings();
  Serial.printf("\nExamGuard node %s (%s)\n", gSettings.name.c_str(),
                gNodeId.c_str());

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFiManager probe;
  const bool savedWifi = probe.getWiFiIsSaved();
  if (gSettings.key.isEmpty() || (!savedWifi && strlen(WIFI_SSID) == 0)) {
    Serial.println("[setup] no settings yet");
    runSetupPortal();
  }
  if (bootHeld(kSetupHoldMs)) runSetupPortal();

  if (savedWifi) {
    WiFi.begin();  // credentials saved by the setup page
  } else {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }
  Serial.println("[wifi] joining...");

  startBle();
}

void loop() {
  static uint32_t bootPressedAt = 0;
  static bool wasConnected = false;
  static uint32_t wifiLostAt = 0;
  const uint32_t now = millis();

  // BOOT held 3 s at any time → setup page.
  if (digitalRead(BOOT_BUTTON_PIN) == LOW) {
    if (bootPressedAt == 0) bootPressedAt = now;
    if (now - bootPressedAt >= kSetupHoldMs) runSetupPortal();
  } else {
    bootPressedAt = 0;
  }

  const bool connected = WiFi.isConnected();
  if (connected != wasConnected) {
    wasConnected = connected;
    if (connected) {
      Serial.printf("[wifi] connected, ip %s\n",
                    WiFi.localIP().toString().c_str());
      wifiLostAt = 0;
      gLastWelcome = now;  // give the hub time before self-healing
      connectHub();        // the gateway is only known now
    } else {
      Serial.println("[wifi] lost, retrying");
      wifiLostAt = now;
      gWelcomed = false;
    }
  }
  if (!connected && wifiLostAt != 0 && now - wifiLostAt >= kWifiRejoinMs) {
    Serial.println("[wifi] still offline, re-joining");
    WiFi.disconnect();
    WiFi.begin();
    wifiLostAt = now;
  }

  if (gRejectedUntil != 0 && now >= gRejectedUntil) {
    gRejectedUntil = 0;
    connectHub();
  }
  if (connected && gRejectedUntil == 0) gSocket.loop();
  // Wi-Fi up but the hub unreachable for 10 minutes: start clean.
  if (connected && !gWelcomed && now - gLastWelcome >= kHubRestartMs) {
    Serial.println("[hall] hub unreachable for 10 min, restarting");
    ESP.restart();
  }

  pollWifiScan();
  if (gWelcomed && now - gLastSend >= kSendEveryMs) {
    gLastSend = now;
    sendSightings();
  }

  gLed = gWelcomed ? LedMode::live
                   : connected ? LedMode::noHub
                               : LedMode::noWifi;
  delay(5);
}
