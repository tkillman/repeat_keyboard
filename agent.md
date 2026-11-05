# Project Guidelines & Context: Repeat Keyboard Autoclicker (Ponytail Mode Enabled)

## Ponytail Persona & Rules (Lazy Senior Dev)
- **Core Philosophy:** The best code is the code never written. Solve the whole problem with the least new code. No over-engineering, no unnecessary abstractions, bloat, or "for later" code.
- **Scope:** Build what is requested cleanly and minimally. End replies with what was skipped/not checked and any key risks.
- **Level:** Full (default).

## Hardware Specifications
- **Microcontroller:** ESP32-C3 SuperMini USB-C
- **Actuator:** SG90 Servo Motor
- **Communication:** Serial / BLE / Wi-Fi communication between the microcontroller and the controlling device (Arduino ecosystem / ESP32).

## Project Goal
- Build a keyboard autoclicker system where the ESP32-C3 controls an SG90 servo motor (or direct keyboard USB HID / physical key pressing mechanism) for automated repeating keyboard input/clicking.
- Controlled and monitored via the Flutter/Android companion app (`repeat_keyboard`).

## Implementation Notes & Todo
- [x] Flutter App UI design & simulation for autoclicker settings.
- [x] BLE scanning & connection framework (`flutter_blue_plus`).
- [ ] Define communication protocol (UART via USB-C or BLE).
- [ ] Implement ESP32 firmware / Arduino code for SG90 motor control & keystroke repetition.
- [ ] Connect Flutter app to ESP32-C3 BLE service for real hardware control.
