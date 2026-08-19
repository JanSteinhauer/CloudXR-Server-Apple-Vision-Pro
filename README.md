# ClaudeXR Server & Apple Vision Pro Client

This project establishes a high-performance streaming connection between a Windows-based Server (often hosted on Google Cloud) and an Apple Vision Pro client. It leverages NVIDIA CloudXR and OpenXR technologies to stream immersive spatial computing content directly to the headset.

## Architecture Overview

The system is separated into two main environments:

*   **Windows (Server Side)**: The `Stream-Manager` directory contains the server components. It runs the OpenXR applications and the NVIDIA CloudXR Server. It captures the application rendering output, encodes the video, and streams it securely to the client. This is often hosted on an external machine, such as a Google Cloud VM.
*   **Mac / VisionOS (Client Side)**: The `My First AVP CloudXR Client` directory contains an Apple Vision Pro application. Built with Swift, RealityKit, and CloudXRKit on the Mac, this client decodes the incoming stream and presents the immersive spatial content to the user.

## Quick Setup Guide

Because the server and client run on distinct operating systems, the setup is split into two parts:

### 1. Windows Server Setup
1. Keep `Stream-Manager-6.1.0-win64-CloudXR-6.2.1` beside the dated Unity build folders.
2. Install the virtual audio driver as described in
   `Stream-Manager-6.1.0-win64-CloudXR-6.2.1/MICROPHONE_SETUP.md`.
3. Double-click the `Start_CloudXR.bat` inside the build you want to run, for example
   `August19/Start_CloudXR.bat`.

The per-build launchers call the shared repository-root `Start_CloudXR.bat`. That script
resolves every path relative to its own location, starts Stream Manager 6.1.0 and Runtime
6.2.1 when necessary, sets `XR_RUNTIME_JSON` to the 6.2.1 runtime, and launches the selected
Unity executable. No machine-specific absolute paths need to be edited.

### 2. Mac Client Setup (Apple Vision Pro)
1. Open the project folder `My First AVP CloudXR Client` in Xcode on your Mac.
2. **Configure Connection Properties**: To successfully connect to your Windows server, you need to update the IP address and access token.
   *   **File to edit**: `My First AVP CloudXR Client/My First AVP CloudXR Client/ContentView.swift`
   *   **Action**: Locate the `Button("Connect")` action starting around line 61, and replace the `ip` and `clientToken` values within `.localSecure` configuration to match your server instance.
   *   _Example snippet to modify:_
       ```swift
       config.connectionType = .localSecure(
           ip: "34.158.227.20", // Replace with your Server's IP address
           clientToken: "CLIENT_TOKEN", // Replace with your server's secure token
           certificateValidationHandler: { challenge in
               // Automatically trusts the self-signed cert from the VM
               if let trust = challenge.protectionSpace.serverTrust {
                   return (.useCredential, URLCredential(trust: trust))
               }
               return (.performDefaultHandling, nil)
           }
       )
       ```
3. Build and Run the application on your Apple Vision Pro device or the VisionOS Simulator via Xcode.

## Documentation Reference
For deeper instructions including how to securely stream from Unity to the AVP over Google Cloud, check out the included guide:
*   `The Ultimate Master Guide Streaming Unity to Apple Vision Pro via NVIDIA CloudXR on Google Cloud (Secure Edition).pdf`
