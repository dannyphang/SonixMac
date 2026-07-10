# SonixMac

SonixMac is a native macOS application for audio processing, specifically designed to connect with a powerful backend for vocal removing and other audio manipulations.

## Features
- **Vocal Removing**: Isolate vocals from any audio track.
- **Native macOS Interface**: Built with SwiftUI for a seamless and native experience on macOS.
- **Concurrent Processing**: Process multiple songs at the same time, configurable in Settings.
- **Backend Integration**: Easily connect to a local Node.js backend or a remote server (e.g. Vercel) for heavy lifting.

## Requirements
- macOS 14.0 or later.
- A compatible backend server (e.g., vocal-remover-angular's node server).

## Building the App
SonixMac uses a shell script to build the release binary via Swift Package Manager and package it into a proper macOS `.app` bundle.

To build the app, run the following command from the project root:
```bash
./build_app.sh
```

This will:
1. Clean the previous build.
2. Build the release binary using `swift build`.
3. Create the `Sonix.app` bundle.
4. Copy the binary and the `AppIcon.icns` into the bundle.
5. Generate the necessary `Info.plist` with the correct app version (currently v1.0.0).

Once completed, you can find `Sonix.app` in the project root. You can double-click it to run, or drag it to your Applications folder.

## Versioning
The app version is managed via `Version.swift` and is also set in the generated `Info.plist` during the build process. 
A GitHub Action automatically increments the patch version (e.g., `1.0.0` to `1.0.1`) upon every push to the `main` branch.
