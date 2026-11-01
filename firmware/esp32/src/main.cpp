// Pahara sensor node.
//
// Scans BLE advertisements continuously and Wi-Fi access points every 30 s,
// and every 2 s sends the strongest devices (raw clues: manufacturer id,
// first data byte, service UUIDs, SSID) to the host phone's hall hub over a
// WebSocket. The app classifies them with the phones' own rules.
// Protocol: lib/features/hall/repository/hall_protocol.dart (v1).
//
// Setup (first start without settings, or hold BOOT 3 s) for 5 minutes:
// - from the Pahara app over Bluetooth: Sensor nodes → Add a node. The
//   app sends the hotspot, password and node key; the node tests them live.
//   Protocol: lib/features/node_setup/model/node_setup_protocol.dart (v1).
// - fallback from any phone: Wi-Fi "Pahara-Setup-XXXXXX" → setup page.

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
constexpr const char* kFirmwareVersion = "1.1.0";
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
  // Hotspot set up from the app. Empty: the page's saved Wi-Fi, or
  // node_config.h.
  String ssid;
  String pass;
};

Settings gSettings;
Preferences gPrefs;
String gSuffix;  // last 3 MAC bytes, e.g. "A1B2C3"
String gNodeId;  // "N-A1B2C3"

String normalizeName(String name) {
  name.trim();
  if (name.isEmpty()) return "Pahara-Node-" + gSuffix;
  String lower = name;
  lower.toLowerCase();
  // Phones trust "Pahara…" names as Pahara hardware ("Pahara…" is the
  // name before the rename and is still trusted).
  return lower.startsWith("pahara") || lower.startsWith("examguard")
             ? name
             : "Pahara-" + name;
}

void loadSettings() {
  gPrefs.begin("pahara", true);
  gSettings.key = gPrefs.getString("key", NODE_KEY);
  gSettings.name = normalizeName(gPrefs.getString("name", NODE_NAME));
  gSettings.hub = gPrefs.getString("hub", HUB_HOST);
  gSettings.ssid = gPrefs.getString("ssid", "");
  gSettings.pass = gPrefs.getString("pass", "");
  gPrefs.end();
  gSettings.key.trim();
  gSettings.hub.trim();
}

void saveSettings(const Settings& s) {
  gPrefs.begin("pahara", false);
  gPrefs.putString("key", s.key);
  gPrefs.putString("name", s.name);
  gPrefs.putString("hub", s.hub);
  gPrefs.putString("ssid", s.ssid);
  gPrefs.putString("pass", s.pass);
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
  // Advertise our name so phones recognise this board as Pahara
  // hardware (the app trusts the "Pahara" prefix).
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

// ── Setup ────────────────────────────────────────────────────────────────
// Open for 5 minutes, only on a first start or when BOOT is held — never
// because Wi-Fi failed, so a switched-off hotspot during an exam can't
// open a door into the node. Two ways in, at the same time:
//
// 1. The Pahara app over Bluetooth (GATT service below). The app reads
//    what this node is and which Wi-Fi networks it sees, writes the
//    hotspot, password, node key and name, and follows each step live:
//    joining → wifi_ok → host_ok / no_host → saved (then restart), or
//    no_network / bad_password / wifi_failed (setup stays open to retry).
// 2. Fallback for any phone: Wi-Fi "Pahara-Setup-XXXXXX" → setup page.

constexpr const char* kSetupService = "e9a40001-5c1d-4b6a-9e2f-3d8c7b1a0e01";
constexpr const char* kInfoChar = "e9a40002-5c1d-4b6a-9e2f-3d8c7b1a0e01";
constexpr const char* kNetworksChar = "e9a40003-5c1d-4b6a-9e2f-3d8c7b1a0e01";
constexpr const char* kConfigChar = "e9a40004-5c1d-4b6a-9e2f-3d8c7b1a0e01";
constexpr const char* kStatusChar = "e9a40005-5c1d-4b6a-9e2f-3d8c7b1a0e01";
constexpr size_t kMaxNetworks = 12;
constexpr uint32_t kJoinTimeoutMs = 20000;
constexpr uint32_t kHostCheckMs = 3000;

struct SetupRequest {
  bool scan = false;
  bool apply = false;
  Settings next;
};

std::mutex gSetupLock;
SetupRequest gRequest;
volatile bool gPhoneConnected = false;
NimBLECharacteristic* gInfoChar = nullptr;
NimBLECharacteristic* gNetworksChar = nullptr;
NimBLECharacteristic* gStatusChar = nullptr;
std::vector<String> gVisibleSsids;

void setStatus(const char* state, const String& detail = "") {
  Serial.printf("[setup] %s %s\n", state, detail.c_str());
  if (gStatusChar == nullptr) return;
  JsonDocument doc;
  doc["s"] = state;
  if (!detail.isEmpty()) doc["d"] = detail;
  String text;
  serializeJson(doc, text);
  gStatusChar->setValue(text.c_str());
  gStatusChar->notify();
}

void publishInfo() {
  JsonDocument doc;
  doc["v"] = kProtocolVersion;
  doc["id"] = gNodeId;
  doc["name"] = gSettings.name;
  doc["fw"] = kFirmwareVersion;
  doc["key"] = !gSettings.key.isEmpty();
  if (!gSettings.ssid.isEmpty()) doc["ssid"] = gSettings.ssid;
  String text;
  serializeJson(doc, text);
  gInfoChar->setValue(text.c_str());
}

// Blocking scan (~2–4 s); only in setup, when nothing else runs.
void scanNetworksForSetup() {
  const int16_t n = WiFi.scanNetworks(false, false);
  struct Net {
    String ssid;
    int rssi;
    bool open;
  };
  std::vector<Net> nets;
  for (int i = 0; i < n; i++) {
    const String ssid = WiFi.SSID(i);
    if (ssid.isEmpty()) continue;
    const auto same = std::find_if(nets.begin(), nets.end(),
                                   [&](const Net& x) { return x.ssid == ssid; });
    if (same != nets.end()) {
      same->rssi = std::max(same->rssi, static_cast<int>(WiFi.RSSI(i)));
      continue;
    }
    nets.push_back({ssid, WiFi.RSSI(i),
                    WiFi.encryptionType(i) == WIFI_AUTH_OPEN});
  }
  WiFi.scanDelete();
  std::sort(nets.begin(), nets.end(),
            [](const Net& a, const Net& b) { return a.rssi > b.rssi; });
  if (nets.size() > kMaxNetworks) nets.resize(kMaxNetworks);

  gVisibleSsids.clear();
  JsonDocument doc;
  JsonArray list = doc.to<JsonArray>();
  for (const Net& net : nets) {
    gVisibleSsids.push_back(net.ssid);
    JsonObject o = list.add<JsonObject>();
    o["s"] = net.ssid;
    o["r"] = net.rssi;
    if (net.open) o["o"] = 1;
  }
  String text;
  serializeJson(doc, text);
  if (gNetworksChar != nullptr) gNetworksChar->setValue(text.c_str());
  Serial.printf("[setup] %d Wi-Fi networks nearby\n",
                static_cast<int>(nets.size()));
}

class SetupServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo&) override {
    gPhoneConnected = true;
    Serial.println("[setup] phone connected over Bluetooth");
  }

  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int) override {
    gPhoneConnected = false;
    NimBLEDevice::startAdvertising();
  }
};

class ConfigCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override {
    JsonDocument doc;
    const std::string value = c->getValue();
    if (deserializeJson(doc, value) || (doc["v"] | 0) != kProtocolVersion) {
      setStatus("bad_request");
      return;
    }
    std::lock_guard<std::mutex> guard(gSetupLock);
    if (strcmp(doc["cmd"] | "", "scan") == 0) {
      gRequest.scan = true;
      return;
    }
    Settings next = gSettings;
    next.ssid = doc["ssid"] | "";
    next.pass = doc["pass"] | "";
    const String key = doc["key"] | "";
    if (!key.isEmpty()) next.key = key;
    next.name = normalizeName(doc["name"] | "");
    next.hub = doc["hub"] | "";
    next.ssid.trim();
    next.key.trim();
    next.hub.trim();
    if (next.ssid.isEmpty() || next.key.isEmpty()) {
      setStatus("bad_request");
      return;
    }
    gRequest.next = next;
    gRequest.apply = true;
  }
};

SetupServerCallbacks gSetupServerCallbacks;
ConfigCallbacks gConfigCallbacks;

void startSetupBluetooth() {
  const String name = "Pahara-Setup-" + gSuffix;
  if (NimBLEDevice::isInitialized()) {
    NimBLEDevice::getScan()->stop();
    NimBLEDevice::stopAdvertising();
  } else {
    NimBLEDevice::init(name.c_str());
  }
  NimBLEDevice::setMTU(247);

  NimBLEServer* server = NimBLEDevice::createServer();
  server->setCallbacks(&gSetupServerCallbacks, false);
  NimBLEService* svc = server->createService(kSetupService);
  gInfoChar = svc->createCharacteristic(kInfoChar, NIMBLE_PROPERTY::READ);
  gNetworksChar =
      svc->createCharacteristic(kNetworksChar, NIMBLE_PROPERTY::READ);
  NimBLECharacteristic* config = svc->createCharacteristic(
      kConfigChar, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  config->setCallbacks(&gConfigCallbacks);
  gStatusChar = svc->createCharacteristic(
      kStatusChar, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  gStatusChar->setValue("{\"s\":\"ready\"}");
  gNetworksChar->setValue("[]");
  publishInfo();
  svc->start();

  // The 128-bit service id fills the advertisement; the name goes in the
  // scan response.
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  NimBLEAdvertisementData advData;
  advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
  advData.setCompleteServices(NimBLEUUID(kSetupService));
  NimBLEAdvertisementData scanData;
  scanData.setName(name.c_str());
  adv->setAdvertisementData(advData);
  adv->setScanResponseData(scanData);
  adv->start();
  Serial.printf("[setup] Bluetooth \"%s\" ready for the app\n", name.c_str());
}

// Joins the hotspot to prove the password, then checks the host phone.
// Returns true when the Wi-Fi works (the host may simply not host yet).
bool tryWifi(const Settings& next) {
  setStatus("joining", next.ssid);
  const bool visible =
      std::find(gVisibleSsids.begin(), gVisibleSsids.end(), next.ssid) !=
      gVisibleSsids.end();
  WiFi.disconnect(false, false);
  delay(100);
  WiFi.begin(next.ssid.c_str(), next.pass.c_str());
  const uint32_t start = millis();
  wl_status_t st = WiFi.status();
  while (st != WL_CONNECTED && millis() - start < kJoinTimeoutMs) {
    if (st == WL_CONNECT_FAILED) break;
    if (st == WL_NO_SSID_AVAIL && millis() - start > 8000) break;
    delay(100);
    st = WiFi.status();
  }
  if (st != WL_CONNECTED) {
    WiFi.disconnect(false, false);
    if (st == WL_NO_SSID_AVAIL || (!visible && !gVisibleSsids.empty())) {
      setStatus("no_network", next.ssid);
    } else if (st == WL_CONNECT_FAILED) {
      setStatus("bad_password", next.ssid);
    } else {
      setStatus("wifi_failed", next.ssid);
    }
    return false;
  }
  setStatus("wifi_ok", WiFi.localIP().toString());

  WiFiClient probe;
  const bool hostUp =
      next.hub.isEmpty()
          ? probe.connect(WiFi.gatewayIP(), HUB_PORT, kHostCheckMs)
          : probe.connect(next.hub.c_str(), HUB_PORT, kHostCheckMs);
  probe.stop();
  setStatus(hostUp ? "host_ok" : "no_host");
  return true;
}

[[noreturn]] void restartSoon() {
  delay(1500);  // let the last notification reach the phone
  ESP.restart();
  for (;;) {
  }
}

[[noreturn]] void runSetup() {
  Serial.println("[setup] open for 5 minutes (Bluetooth + Wi-Fi page)");
  gLed = LedMode::setup;
  WiFi.mode(WIFI_AP_STA);
  WiFi.setAutoReconnect(false);
  startSetupBluetooth();
  scanNetworksForSetup();

  // Fallback web page, non-blocking so Bluetooth requests run alongside.
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

  bool pageSaved = false;
  wm.setSaveParamsCallback([&pageSaved] { pageSaved = true; });
  wm.setSaveConfigCallback([&pageSaved] { pageSaved = true; });
  wm.setBreakAfterConfig(true);  // keep settings even if Wi-Fi test fails
  wm.setConfigPortalBlocking(false);
  wm.setTitle("Pahara sensor node");
  std::vector<const char*> menu = {"wifi", "exit"};
  wm.setMenu(menu);
  const String ap = "Pahara-Setup-" + gSuffix;
  Serial.printf("[setup] Wi-Fi \"%s\", password \"%s\"\n", ap.c_str(),
                SETUP_PASSWORD);
  wm.startConfigPortal(ap.c_str(), SETUP_PASSWORD);

  uint32_t deadline = millis() + kSetupPortalSeconds * 1000UL;
  while (static_cast<int32_t>(millis() - deadline) < 0) {
    // A phone working on it keeps setup open.
    if (gPhoneConnected) deadline = millis() + kSetupPortalSeconds * 1000UL;

    SetupRequest request;
    {
      std::lock_guard<std::mutex> guard(gSetupLock);
      request = gRequest;
      gRequest = SetupRequest();
    }
    if (request.scan) {
      setStatus("scanning");
      scanNetworksForSetup();
      setStatus("ready");
    }
    if (request.apply && tryWifi(request.next)) {
      saveSettings(request.next);
      setStatus("saved", request.next.name);
      Serial.printf("[setup] saved from the app, node name %s\n",
                    request.next.name.c_str());
      restartSoon();
    }

    wm.process();
    if (pageSaved) {
      Settings next = gSettings;
      String key = keyField.getValue();
      key.trim();
      if (!key.isEmpty()) next.key = key;
      next.name = normalizeName(nameField.getValue());
      next.hub = hubField.getValue();
      next.hub.trim();
      // The page saved its own Wi-Fi: forget a hotspot set from the app.
      next.ssid = "";
      next.pass = "";
      saveSettings(next);
      Serial.printf("[setup] saved from the page, node name %s\n",
                    next.name.c_str());
      restartSoon();
    }
    delay(10);
  }
  Serial.println("[setup] closed without changes");
  restartSoon();
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
  Serial.printf("\nPahara node %s (%s)\n", gSettings.name.c_str(),
                gNodeId.c_str());

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFiManager probe;
  const bool appWifi = !gSettings.ssid.isEmpty();
  const bool savedWifi = probe.getWiFiIsSaved();
  if (gSettings.key.isEmpty() ||
      (!appWifi && !savedWifi && strlen(WIFI_SSID) == 0)) {
    Serial.println("[setup] no settings yet");
    runSetup();
  }
  if (bootHeld(kSetupHoldMs)) runSetup();

  if (appWifi) {
    WiFi.begin(gSettings.ssid.c_str(), gSettings.pass.c_str());
  } else if (savedWifi) {
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
    if (now - bootPressedAt >= kSetupHoldMs) runSetup();
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
