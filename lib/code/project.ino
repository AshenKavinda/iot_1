/*
 * ============================================================
 *  WATER TANK AUTO-FILL SYSTEM
 *  Hardware: ESP8266 NodeMCU
 *  Sensors:  SEN18 x3 (A=tank low, B=tank high, C=well low)
 *            YF-S201 flow sensor
 *  Actuator: 5V Relay → 12V Water Pump
 *  Database: Firebase Realtime Database
 * ============================================================
 *
 *  PIN MAPPING
 *  -----------
 *  D1 (GPIO5)  → Sensor A  (Tank LOW  level)
 *  D2 (GPIO4)  → Sensor B  (Tank HIGH level)
 *  D5 (GPIO14) → Sensor C  (Well LOW  level)
 *  D6 (GPIO12) → YF-S201   (Flow sensor pulse)
 *  D7 (GPIO13) → Relay IN   (HIGH = pump ON)
 *  D4 (GPIO2)  → Built-in LED (LOW = ON, active-LOW)
 *               OFF during boot → ON when WiFi + Firebase ready
 *
 *  SENSOR LOGIC
 *  ------------
 *  1 = water NOT detected
 *  0 = water detected
 *
 *  AUTO-FILL LOGIC
 *  ---------------
 *  START  : A==1 AND B==1 AND C==0  (tank empty, well has water)
 *  STOP   : A==0 AND B==0            (tank full)
 *  E-STOP : C==1 while filling       (well ran dry)
 *
 *  MANUAL OVERRIDE
 *  ---------------
 *  Firebase path /pump/manualOverride = true  → force pump ON
 *  Safety gates always enforced even in manual mode:
 *    - C==1 (well dry)       → pump OFF, override cleared
 *    - A==0 && B==0 (tank full) → pump OFF, override cleared
 * ============================================================
 *
 *  CHANGELOG
 *  ---------
 *  v1.5 - Added: Manual fill sessions tracked and logged to Firebase.
 *               Session records now include startReason, startMs, endMs,
 *               and duration for richer history display in the mobile app.
 *  v1.4 - Added: Built-in LED (GPIO2) turns ON once WiFi is
 *               connected AND Firebase is ready, giving a clear
 *               visual "device ready" indicator on the board.
 *  v1.3 - Fixed: OOM crash when flow sensor (YF-S201) is wired.
 *               Root cause: 4 concurrent FirebaseData objects each
 *               hold a 10-15 KB SSL context, exhausting the ~40 KB
 *               heap on first write after pump start.
 *               Fix 1: consolidated from 4 FirebaseData objects down
 *               to 2 (fbdo_read / fbdo_write), saving ~20-30 KB heap.
 *               Fix 2: serialised writes — only one Firebase call fires
 *               per loop tick. Flow data piggybacked into /status push
 *               instead of a separate concurrent write. Session-start
 *               path written on the tick AFTER pushSensors() via a
 *               deferred flag, never in the same tick.
 *  v1.2 - Added: FLOW_SENSOR_ENABLED toggle to disable ISR when sensor
 *               not wired, preventing floating-pin ISR storms → OOM crash
 *  v1.1 - Fixed: manual override now also stops pump when tank is full
 *       - Fixed: session litres logged correctly before reset
 *       - Fixed: auto-fill stop no longer conditionally skipped on manual override
 *       - Fixed: debounce function now correctly returns stable reading
 * ============================================================
 */

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ── WiFi credentials ────────────────────────────────────────
#define WIFI_SSID     "SLT_FIBER"
#define WIFI_PASSWORD "ashen321"

// ── Firebase credentials ─────────────────────────────────────
#define API_KEY       "AIzaSyCrJsZus4m4zRCWZ3K2Aq84-OMCZeSWo2o"
#define DATABASE_URL  "https://iot-2026-tharuka-default-rtdb.firebaseio.com/"
#define USER_EMAIL    "admin@test.com"
#define USER_PASSWORD "12345678"

// ── GPIO Pins ────────────────────────────────────────────────
#define PIN_SENSOR_A   5   // D1 – Tank low level
#define PIN_SENSOR_B   4   // D2 – Tank high level
#define PIN_SENSOR_C  14   // D5 – Well low level
#define PIN_FLOW      12   // D6 – YF-S201 pulse
#define PIN_RELAY     13   // D7 – Relay (active HIGH)
// LED_BUILTIN = GPIO2 (D4) — active-LOW on NodeMCU

// ── Timing constants ─────────────────────────────────────────
#define SENSOR_UPDATE_MS    2000   // Push sensor state every 2 s
#define FLOW_CALC_MS        1000   // Recalculate flow every 1 s
#define HISTORY_INTERVAL_MS 20000  // Write flow history every 20 s

// ── YF-S201 calibration ──────────────────────────────────────
// 7.5 pulses per second = 1 L/min (varies by unit; adjust if needed)
#define FLOW_CALIBRATION 7.5f

// ── Flow sensor toggle ───────────────────────────────────────
// Set to 0 if the YF-S201 is not physically connected.
// This disables the interrupt and flow calculation entirely,
// preventing floating-pin noise from triggering ISR storms -> OOM.
#define FLOW_SENSOR_ENABLED 1   // <- change to 0 when sensor is NOT wired

// ── Firebase objects ─────────────────────────────────────────
// FIX v1.3: Use only 2 shared FirebaseData objects instead of 4.
// Each FirebaseData keeps a live SSL/TLS context (~10-15 KB on heap).
// 4 concurrent objects exhaust the ESP8266's ~40 KB heap the moment
// a Firebase write fires while the pump is running. Two shared objects
// stay within budget and are safe because writes are now serialised —
// never two in the same loop tick.
FirebaseData fbdo_read;   // used for all GET operations
FirebaseData fbdo_write;  // used for all SET/PUSH operations
FirebaseAuth auth;
FirebaseConfig config;

// ── Runtime state ────────────────────────────────────────────
volatile uint32_t pulseCount   = 0;
float    flowRateLPM           = 0.0f;
float    totalLitresSinceBoot  = 0.0f;
float    sessionLitres         = 0.0f;

bool     pumpRunning           = false;
bool     autoFillActive        = false;
bool     manualOverride        = false;
const char* stopReason         = "idle";

// FIX v1.3: deferred session-start write flag.
// Calling setString() and pushSensors() in the same loop tick fires two
// concurrent SSL writes -> OOM. Raise a flag instead; the path is written
// on the NEXT tick, after pushSensors() has already completed.
bool     pendingSessionStart   = false;
uint32_t pendingSessionTs      = 0;
char     pendingSessionReason[16] = "auto_fill";
bool     manualSessionActive   = false;

uint32_t lastSensorUpdate      = 0;
uint32_t lastFlowCalc          = 0;
uint32_t lastHistoryWrite      = 0;
uint32_t sessionStartMs        = 0;

// ── ISR: count YF-S201 pulses ────────────────────────────────
#if FLOW_SENSOR_ENABLED
ICACHE_RAM_ATTR void flowISR() {
  pulseCount++;
}
#endif

// ── Helpers ──────────────────────────────────────────────────
void setPump(bool on) {
  digitalWrite(PIN_RELAY, on ? HIGH : LOW);  // relay is active-HIGH
  pumpRunning = on;
}

// Read a water-level sensor with debounce
int readSensor(uint8_t pin) {
  int v1 = digitalRead(pin);
  delay(10);
  int v2 = digitalRead(pin);
  if (v1 == v2) return v1;
  delay(10);
  return digitalRead(pin);
}

// Clear manual override in Firebase and locally
void clearManualOverride(const char* reason) {
  stopReason     = reason;
  manualOverride = false;
  setPump(false);
  Firebase.RTDB.setBool(&fbdo_write, "/pump/manualOverride", false);
}

// Push a JSON snapshot of all sensor + flow states.
// FIX v1.3: flow fields merged here; no separate concurrent write needed.
void pushSensors(int a, int b, int c) {
  FirebaseJson json;
  json.set("sensorA",              a);
  json.set("sensorB",              b);
  json.set("sensorC",              c);
  json.set("pumpRunning",          pumpRunning);
  json.set("autoFillActive",       autoFillActive);
  json.set("manualOverride",       manualOverride);
  json.set("stopReason",           stopReason);
  json.set("flowRateLPM",          flowRateLPM);
  json.set("sessionLitres",        sessionLitres);
  json.set("totalLitresSinceBoot", totalLitresSinceBoot);
  json.set("timestamp",            (int)millis());
  Firebase.RTDB.setJSON(&fbdo_write, "/status", &json);
}

// Append a periodic flow history record
void writeHistory(int a, int b, int c) {
  FirebaseJson record;
  record.set("sensorA",       a);
  record.set("sensorB",       b);
  record.set("sensorC",       c);
  record.set("pumpRunning",   pumpRunning);
  record.set("flowRateLPM",   flowRateLPM);
  record.set("sessionLitres", sessionLitres);
  record.set("epochMs",       (int)millis());
  Firebase.RTDB.pushJSON(&fbdo_write, "/history/flow", &record);
}

// Log a completed fill session to history
void logSession(uint32_t startTs, uint32_t endTs, float litres,
                const char* startRsn, const char* stopRsn) {
  char path[48];
  snprintf(path, sizeof(path), "/history/sessions/%lu", (unsigned long)startTs);
  FirebaseJson session;
  session.set("startReason",  startRsn);
  session.set("stopReason",   stopRsn);
  session.set("litresPumped", litres);
  session.set("startMs",      (int)startTs);
  session.set("endMs",        (int)endTs);
  session.set("duration",     (int)(endTs - startTs));
  Firebase.RTDB.setJSON(&fbdo_write, path, &session);
}

// ── Setup ────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);

  // Built-in LED: turn OFF during startup (active-LOW, so HIGH = OFF)
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);

  // GPIO init
  pinMode(PIN_SENSOR_A, INPUT);
  pinMode(PIN_SENSOR_B, INPUT);
  pinMode(PIN_SENSOR_C, INPUT);
  pinMode(PIN_FLOW,     INPUT_PULLUP);
  pinMode(PIN_RELAY,    OUTPUT);
  setPump(false);

  // Flow sensor interrupt — only attach if sensor is physically connected.
  // A floating pin with INPUT_PULLUP fires thousands of spurious interrupts
  // per second during Firebase writes, corrupting the heap -> OOM crash.
#if FLOW_SENSOR_ENABLED
  attachInterrupt(digitalPinToInterrupt(PIN_FLOW), flowISR, RISING);
#else
  Serial.println("[FLOW] Sensor disabled — interrupt not attached");
#endif

  // WiFi
  Serial.printf("\nConnecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected: " + WiFi.localIP().toString());

  // Firebase config
  config.api_key               = API_KEY;
  config.database_url          = DATABASE_URL;
  auth.user.email              = USER_EMAIL;
  auth.user.password           = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase initialised. Waiting for ready...");
  while (!Firebase.ready()) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\nFirebase ready!");

  // ── v1.4: All systems go — turn built-in LED ON ──────────
  // LED_BUILTIN (GPIO2 / D4) is active-LOW on NodeMCU:
  // writing LOW completes the circuit and lights the LED.
  digitalWrite(LED_BUILTIN, LOW);
  Serial.println("[LED] Built-in LED ON — WiFi + Firebase ready");
}

// ── Main loop ────────────────────────────────────────────────
void loop() {
  uint32_t now = millis();

  // ── 1. Calculate flow rate every second ──────────────────
  // FIX v1.3: accumulate totals here but do NOT push to Firebase.
  // Flow data is piggybacked into pushSensors() every 2 s,
  // eliminating the concurrent write that caused OOM.
#if FLOW_SENSOR_ENABLED
  if (now - lastFlowCalc >= FLOW_CALC_MS) {
    uint32_t pulses;
    noInterrupts();
    pulses     = pulseCount;
    pulseCount = 0;
    interrupts();

    flowRateLPM = (float)pulses / FLOW_CALIBRATION;

    if (pumpRunning) {
      float litresThisSec   = flowRateLPM / 60.0f;
      totalLitresSinceBoot += litresThisSec;
      sessionLitres        += litresThisSec;
    }
    lastFlowCalc = now;
  }
#endif

  // ── 2. Read sensors & run control logic every 2 s ────────
  if (now - lastSensorUpdate >= SENSOR_UPDATE_MS) {
    int sA = readSensor(PIN_SENSOR_A);
    int sB = readSensor(PIN_SENSOR_B);
    int sC = readSensor(PIN_SENSOR_C);

    // ── Read manual override flag from Firebase ────────────
    if (Firebase.RTDB.getBool(&fbdo_read, "/pump/manualOverride")) {
      manualOverride = fbdo_read.boolData();
    }

    // ══════════════════════════════════════════════════════
    //  AUTO-FILL LOGIC
    // ══════════════════════════════════════════════════════

    if (autoFillActive) {

      // ── Stop condition 1: tank is full ──────────────────
      if (sA == 0 && sB == 0) {
        autoFillActive = false;
        logSession(sessionStartMs, now, sessionLitres, "auto_fill", "tank_full");
        sessionLitres = 0.0f;
        setPump(false);
        stopReason = "tank_full";
        Serial.println("[AUTO] Tank full — pump OFF");

      // ── Stop condition 2: well ran dry during fill ──────
      } else if (sC == 1) {
        autoFillActive = false;
        logSession(sessionStartMs, now, sessionLitres, "auto_fill", "well_dry_during_fill");
        sessionLitres = 0.0f;
        setPump(false);
        stopReason = "well_dry_during_fill";
        Serial.println("[AUTO] Well dry during fill — pump OFF");
      }

    } else {
      // ── Start condition: tank empty AND well has water ───
      if (sA == 1 && sB == 1 && sC == 0 && !manualOverride) {
        autoFillActive      = true;
        sessionLitres       = 0.0f;
        sessionStartMs      = now;
        setPump(true);
        stopReason          = "filling";
        // FIX v1.3: raise flag — do NOT call setString() here.
        // Doing so fires two Firebase writes in one tick (setString +
        // pushSensors) -> OOM. The path is written next tick instead.
        pendingSessionStart = true;
        pendingSessionTs    = now;
        strncpy(pendingSessionReason, "auto_fill", sizeof(pendingSessionReason));
        Serial.println("[AUTO] Tank empty + well OK — pump ON");
      }
    }

    // ══════════════════════════════════════════════════════
    //  MANUAL OVERRIDE LOGIC
    // ══════════════════════════════════════════════════════

    if (manualOverride) {

      if (sC == 1) {
        if (manualSessionActive) {
          logSession(sessionStartMs, now, sessionLitres, "manual", "well_dry_safety");
          sessionLitres = 0.0f;
          manualSessionActive = false;
        }
        clearManualOverride("well_dry_safety");
        Serial.println("[MANUAL] Well dry — pump OFF, override cleared");

      } else if (sA == 0 && sB == 0) {
        if (manualSessionActive) {
          logSession(sessionStartMs, now, sessionLitres, "manual", "tank_full_safety");
          sessionLitres = 0.0f;
          manualSessionActive = false;
        }
        clearManualOverride("tank_full_safety");
        Serial.println("[MANUAL] Tank full — pump OFF, override cleared");

      } else {
        if (autoFillActive) {
          autoFillActive = false;
          Serial.println("[MANUAL] Auto-fill paused by manual override");
        }
        if (!manualSessionActive) {
          manualSessionActive = true;
          sessionLitres       = 0.0f;
          sessionStartMs      = now;
          pendingSessionStart = true;
          pendingSessionTs    = now;
          strncpy(pendingSessionReason, "manual", sizeof(pendingSessionReason));
          Serial.println("[MANUAL] Session started");
        }
        setPump(true);
        stopReason = "manual";
        Serial.println("[MANUAL] Pump ON");
      }

    } else if (!autoFillActive) {
      if (manualSessionActive) {
        logSession(sessionStartMs, now, sessionLitres, "manual", "manual_stopped");
        sessionLitres = 0.0f;
        manualSessionActive = false;
        Serial.println("[MANUAL] Session logged — manual stopped");
      }
      setPump(false);
      if (strcmp(stopReason, "manual") == 0) stopReason = "idle";
    }

    // ── One Firebase write for this tick ──────────────────
    pushSensors(sA, sB, sC);

    lastSensorUpdate = now;
    Serial.printf(
      "[SENSORS] A:%d B:%d C:%d | Pump:%s | Auto:%s | Manual:%s | Stop:%s | Flow:%.2f L/min\n",
      sA, sB, sC,
      pumpRunning    ? "ON"  : "OFF",
      autoFillActive ? "YES" : "NO",
      manualOverride ? "YES" : "NO",
      stopReason,
      flowRateLPM
    );

    return;  // yield — handle deferred write on next loop() call
  }

  // ── 3. Deferred session-start write ──────────────────────
  // FIX v1.3: fires on a separate tick from pushSensors() so only
  // one Firebase SSL call is in-flight at a time.
  if (pendingSessionStart) {
    pendingSessionStart = false;
    char startPath[48];
    snprintf(startPath, sizeof(startPath),
             "/history/sessions/%lu", (unsigned long)pendingSessionTs);
    FirebaseJson startRecord;
    startRecord.set("startReason", pendingSessionReason);
    startRecord.set("startMs",     (int)pendingSessionTs);
    Firebase.RTDB.setJSON(&fbdo_write, startPath, &startRecord);
    Serial.println("[SESSION] Start record written");
    return;  // yield
  }

  // ── 4. Periodic history record while pump is running ─────
  if (pumpRunning && (now - lastHistoryWrite >= HISTORY_INTERVAL_MS)) {
    int sA = readSensor(PIN_SENSOR_A);
    int sB = readSensor(PIN_SENSOR_B);
    int sC = readSensor(PIN_SENSOR_C);
    writeHistory(sA, sB, sC);
    lastHistoryWrite = now;
    Serial.println("[HISTORY] Periodic record written");
  }
}
