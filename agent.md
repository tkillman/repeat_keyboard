# Project Guidelines & Context: Repeat Keyboard Autoclicker

## Hardware Specifications
- **Microcontroller:** ESP32-C3 SuperMini USB-C
- **Actuator:** SG90 Servo Motor
- **Communication:** Serial / BLE / Wi-Fi communication between the microcontroller and the controlling device (Arduino ecosystem / ESP32).

## Project Goal
- Build a keyboard autoclicker system where the ESP32-C3 controls an SG90 servo motor (or direct keyboard USB HID / physical key pressing mechanism) for automated repeating keyboard input/clicking.
- Controlled and monitored via the Flutter/Android companion app (`repeat_keyboard`).

## Implementation Notes & Todo
- [ ] Define communication protocol (UART via USB-C or BLE).
- [ ] Implement ESP32 firmware / Arduino code for SG90 motor control & keystroke repetition.
- [ ] Implement Flutter/Android UI (`repeat_keyboard`) for setting repeat intervals, angles, duration, and start/stop triggers.
