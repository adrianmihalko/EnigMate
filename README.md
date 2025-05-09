# Enigma2 Remote Control App

A simple iOS remote control application for Enigma2-based set-top boxes. This app allows you to control your Enigma2 device over your local network using the OpenWebif API.

## Features

- Numeric keypad (0-9) for direct channel input
- Volume control (Up/Down)
- Channel control (Up/Down)
- Simple and intuitive user interface
- Haptic feedback on button presses
- Error handling for network issues

## Requirements

- iOS 16.0+
- Xcode 16.2+
- Swift 5.0+
- Enigma2-based set-top box with OpenWebif installed

## Installation

1. Clone this repository
2. Open `Enigma2Remote.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

## Usage

1. Launch the app
2. Enter your Enigma2 box's IP address (e.g., "192.168.1.100")
3. Use the numeric keypad to enter channel numbers
4. Use the volume and channel buttons to adjust volume and change channels

## Network Requirements

- The app requires local network access to communicate with your Enigma2 box
- Make sure your iOS device and Enigma2 box are on the same network
- The app uses HTTP to communicate with the Enigma2 box

## Command Reference

The app uses the following Enigma2 remote control commands:

- Numbers 0-9: Commands 100-109
- Volume Up: Command 115
- Volume Down: Command 114
- Channel Up: Command 402
- Channel Down: Command 403

## Troubleshooting

If you experience issues:

1. Verify that your Enigma2 box's IP address is correct
2. Ensure both devices are on the same network
3. Check that OpenWebif is properly installed and running on your Enigma2 box
4. Verify that your network allows HTTP traffic to the Enigma2 box

## License

This project is available under the MIT license. See the LICENSE file for more info. 