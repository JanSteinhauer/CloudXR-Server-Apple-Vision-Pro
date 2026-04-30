# ClaudeXR Server & Apple Vision Pro Client

This project establishes a high-performance streaming connection between a Windows-based Server (often hosted on Google Cloud) and an Apple Vision Pro client. It leverages NVIDIA CloudXR and OpenXR technologies to stream immersive spatial computing content directly to the headset.

## Architecture Overview

The system is separated into two main environments:

*   **Windows (Server Side)**: The `Stream-Manager` directory contains the server components. It runs the OpenXR applications and the NVIDIA CloudXR Server. It captures the application rendering output, encodes the video, and streams it securely to the client. This is often hosted on an external machine, such as a Google Cloud VM.
*   **Mac / VisionOS (Client Side)**: The `My First AVP CloudXR Client` directory contains an Apple Vision Pro application. Built with Swift, RealityKit, and CloudXRKit on the Mac, this client decodes the incoming stream and presents the immersive spatial content to the user.

## Quick Setup Guide

Because the server and client run on distinct operating systems, the setup is split into two parts:

### 1. Windows Server Setup
1. Copy or extract the `Stream-Manager-6.0.4-win64` directory to your Windows machine (or cloud VM).
2. **Configure OpenXR Runtime Path**: You must ensure that the OpenXR configuration points to the correct location of the `openxr_cloudxr.dll` on your Windows system.
   *   **File to edit**: `Stream-Manager-6.0.4-win64 - Copy/Server/releases/6.0.5/openxr_cloudxr.json`
   *   **Action**: Change the `library_path` to match the exact absolute path where the `.dll` is located on the Windows machine.
   *   _Example Configuration:_
       ```json
       {
         "file_format_version": "1.0.0",
         "runtime": {
           "name": "NVIDIA™ CloudXR™ Runtime (based on Monado™)",
           "library_path": "C:\\Users\\jan_armin_steinhauer\\Downloads\\Stream-Manager-6.0.4-win64\\Server\\releases\\6.0.5\\openxr_cloudxr.dll"
         }
       }
       ```
3. **Launch the Server Application**: To correctly route the OpenXR traffic through CloudXR, you must launch your VR/AR application using the provided batch script (`Start_CloudXR.bat`) which sets the `XR_RUNTIME_JSON` environment variable before starting the application.
   *   **File to edit**: `New folder/Start_CloudXR.bat` (or move it to your preferred location)
   *   **Action**: Ensure that the `XR_RUNTIME_JSON` path within the `.bat` file points correctly to your `openxr_cloudxr.json` file. Note that we wrap the assignment in quotes `set "XR_RUNTIME_JSON=..."` to safely handle spaces in the folder path.
   *   _Example Configuration:_
       ```bat
       @echo off
       echo Setting OpenXR Runtime to NVIDIA CloudXR...
       set "XR_RUNTIME_JSON=C:\Users\jan_armin_steinhauer\Downloads\Stream-Manager-6.0.4-win64 - Copy\Server\releases\6.0.5\openxr_cloudxr.json"
       
       echo Starting Unity Game...
       start "" "CloudXRStreamingTest.exe"
       
       echo Game launched! Waiting for connection...
       pause
       ```
   * Then just double-click the `Start_CloudXR.bat` to run the game!

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
