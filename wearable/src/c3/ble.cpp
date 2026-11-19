#include "ble.h"

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <freertos/FreeRTOS.h>
#include <freertos/stream_buffer.h>

namespace ble {

namespace {

const char* kSvcUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const char* kRxUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";  // app -> band, write
const char* kTxUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";  // band -> app, notify

constexpr uint16_t kMtu = 247;
constexpr uint32_t kPairTimeoutMs = 60000;
constexpr uint32_t kNotifyGiveUpMs = 3000;

NimBLEServer* server = nullptr;
NimBLECharacteristic* tx = nullptr;
StreamBufferHandle_t rxStream = nullptr;
void (*tickFn)() = nullptr;

// Written by the NimBLE task, read by loop().
volatile bool connected_ = false;
volatile bool secure_ = false;
volatile bool pairing_ = false;
volatile bool newBond_ = false;
volatile bool dropped_ = false;  // connection ended: reset the line reader
volatile bool rxOverflow_ = false;
volatile uint16_t connHandle_ = BLE_HS_CONN_HANDLE_NONE;
volatile uint16_t mtu_ = 23;
volatile uint32_t passkey_ = 0;
volatile uint32_t pairSince_ = 0;
NimBLEAddress peer_;

bbproto::LineReader reader;

class ServerCb : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* s, NimBLEConnInfo& info) override {
    connHandle_ = info.getConnHandle();
    connected_ = true;
    secure_ = false;
    mtu_ = 23;
    // Ask for encryption at once: a bonded phone re-encrypts with its stored key,
    // a new phone starts passkey pairing. Advertising stops while connected, so
    // only one phone can be connected.
    NimBLEDevice::startSecurity(info.getConnHandle());
  }
  void onDisconnect(NimBLEServer* s, NimBLEConnInfo& info, int reason) override {
    connected_ = false;
    secure_ = false;
    pairing_ = false;
    connHandle_ = BLE_HS_CONN_HANDLE_NONE;
    dropped_ = true;
    // advertiseOnDisconnect(true) restarts advertising.
  }
  void onMTUChange(uint16_t mtu, NimBLEConnInfo& info) override { mtu_ = mtu; }
  uint32_t onPassKeyDisplay() override {
    // A new random passkey for every pairing, shown only on the band's screen.
    passkey_ = esp_random() % 1000000UL;
    pairSince_ = millis();
    pairing_ = true;
    return passkey_;
  }
  void onConfirmPassKey(NimBLEConnInfo& info, uint32_t pin) override {
    // DisplayOnly never gets numeric comparison; refuse if a peer asks for it.
    NimBLEDevice::injectConfirmPasskey(info, false);
  }
  void onAuthenticationComplete(NimBLEConnInfo& info) override {
    pairing_ = false;
    if (!info.isEncrypted() || !info.isAuthenticated() || !info.isBonded()) {
      // "Just works" or a failed pairing: no data for this link.
      server->disconnect(info.getConnHandle());
      return;
    }
    peer_ = info.getIdAddress();
    secure_ = true;
    newBond_ = true;
  }
};

class RxCb : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& info) override {
    // The stack already refuses unencrypted/unauthenticated writes (WRITE_ENC +
    // WRITE_AUTHEN); this is a second check.
    if (!info.isEncrypted() || !info.isAuthenticated()) return;
    NimBLEAttValue v = c->getValue();
    if (v.size() == 0) return;
    if (xStreamBufferSend(rxStream, v.data(), v.size(), 0) != v.size()) rxOverflow_ = true;
  }
};

// Sends answers as notifications of up to (MTU - 3) bytes.
class NotifyWriter : public bb::Writer {
 public:
  void write(const char* s) override {
    while (*s) {
      if (dead_) return;
      size_t room = chunk() - len_;
      size_t n = strnlen(s, room);
      memcpy(buf_ + len_, s, n);
      len_ += n;
      s += n;
      if (len_ >= chunk()) flush();
    }
  }
  void flush() {
    if (len_ == 0 || dead_) {
      len_ = 0;
      return;
    }
    uint32_t start = millis();
    // notify() fails when the stack is out of buffers; wait for the radio to drain.
    while (!(connected_ && secure_ && tx->notify(buf_, len_, connHandle_))) {
      if (!connected_ || !secure_ || millis() - start > kNotifyGiveUpMs) {
        dead_ = true;  // phone gone or stuck: drop the rest of this answer
        break;
      }
      if (tickFn) tickFn();
      delay(4);
    }
    len_ = 0;
    if (++sent_ % 32 == 0 && tickFn) tickFn();
  }
  void reset() {
    len_ = 0;
    dead_ = false;
  }

 private:
  size_t chunk() const {
    size_t c = (size_t)mtu_ > 3 ? (size_t)mtu_ - 3 : 20;
    return c > sizeof buf_ ? sizeof buf_ : c;
  }
  uint8_t buf_[kMtu - 3];
  size_t len_ = 0;
  bool dead_ = false;
  uint32_t sent_ = 0;
};

NotifyWriter writer;

// One bonded phone at a time: after a new phone pairs, forget the others.
void keepOnlyNewestBond() {
  for (int i = NimBLEDevice::getNumBonds() - 1; i >= 0; i--) {
    NimBLEAddress a = NimBLEDevice::getBondedAddress(i);
    if (!(a == peer_)) NimBLEDevice::deleteBond(a);
  }
}

}  // namespace

void begin(const char* name, void (*tick)()) {
  tickFn = tick;
  rxStream = xStreamBufferCreate(1024, 1);

  NimBLEDevice::init(name);
  NimBLEDevice::setMTU(kMtu);
  NimBLEDevice::setSecurityAuth(true, true, true);  // bonding, MITM, LE Secure Connections
  NimBLEDevice::setSecurityIOCap(BLE_HS_IO_DISPLAY_ONLY);
  NimBLEDevice::setSecurityInitKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);
  NimBLEDevice::setSecurityRespKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);

  server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCb());
  server->advertiseOnDisconnect(true);

  NimBLEService* svc = server->createService(kSvcUuid);
  NimBLECharacteristic* rx = svc->createCharacteristic(
      kRxUuid, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR | NIMBLE_PROPERTY::WRITE_ENC |
                   NIMBLE_PROPERTY::WRITE_AUTHEN);
  rx->setCallbacks(new RxCb());
  tx = svc->createCharacteristic(kTxUuid, NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ_ENC |
                                              NIMBLE_PROPERTY::READ_AUTHEN);
  server->start();  // also starts the service

  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  NimBLEAdvertisementData ad, sr;
  ad.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
  ad.addServiceUUID(kSvcUuid);  // 128-bit UUID fills most of the 31-byte packet
  sr.setName(name);             // so the name goes in the scan response
  adv->setAdvertisementData(ad);
  adv->setScanResponseData(sr);
  // ~1 s interval (Apple's 1022.5 ms step): found within a few seconds, low current.
  adv->setMinInterval(1636);
  adv->setMaxInterval(1636);
  adv->start();
}

void poll(bbproto::BandHost& host) {
  if (dropped_) {
    dropped_ = false;
    reader.reset();
    xStreamBufferReset(rxStream);
  }
  if (newBond_) {
    newBond_ = false;
    keepOnlyNewestBond();
  }
  if (pairing_ && millis() - pairSince_ > kPairTimeoutMs) pairing_ = false;
  if (rxOverflow_) {
    rxOverflow_ = false;
    reader.reset();
    xStreamBufferReset(rxStream);
    writer.reset();
    writer.write("ERR busy\n");
    writer.flush();
  }
  char buf[128];
  size_t n;
  while ((n = xStreamBufferReceive(rxStream, buf, sizeof buf, 0)) > 0) {
    writer.reset();
    reader.feed(buf, n, host, writer);
    writer.flush();
  }
}

bool connected() { return connected_; }
bool secure() { return secure_; }
bool pairing() { return pairing_; }
uint32_t passkey() { return passkey_; }
int bondCount() { return NimBLEDevice::getNumBonds(); }

void unpairAll() {
  if (connected_ && connHandle_ != BLE_HS_CONN_HANDLE_NONE) server->disconnect(connHandle_);
  NimBLEDevice::deleteAllBonds();
}

}  // namespace ble
