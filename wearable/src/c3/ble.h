// Bluetooth LE link to the phone app: Nordic UART Service, bonded + MITM + LE Secure
// Connections, the band shows a 6-digit passkey (docs/PROTOCOL.md).
#pragma once
#include <stdint.h>

#include "bbproto.h"

namespace ble {

// name: "BloomBack-XXXX". tick: called while waiting for the radio (keeps the
// sensor FIFO read during long syncs).
void begin(const char* name, void (*tick)());

// Runs commands that arrived from the phone and sends the answers. Call from loop().
void poll(bbproto::BandHost& host);

bool connected();      // a phone is connected (maybe not paired yet)
bool secure();         // connected, encrypted and authenticated (bonded phone)
bool pairing();        // passkey is being shown
uint32_t passkey();    // the 6-digit passkey while pairing()
int bondCount();
void unpairAll();      // forget every bonded phone and drop the connection

}  // namespace ble
