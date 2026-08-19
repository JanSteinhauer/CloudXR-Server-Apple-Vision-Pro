# CloudXR microphone upgrade

This directory contains the NVIDIA packages required for the audio path:

```text
Apple Vision Pro microphone
  -> CloudXR Framework 6.2.0
  -> CloudXR Runtime 6.2.1 (micStreaming: true)
  -> NVIDIA CloudXR virtual capture endpoint on Windows
  -> Unity Microphone API
  -> RealityStack LiveKit local audio track
```

CloudXR 6.0.x cannot carry upstream microphone audio. The feature first appeared in
CloudXR Framework 6.1.0 and CloudXR Runtime 6.2.0. The downloaded 6.2.x packages are
therefore required; adding `micStreaming` to a 6.0.5 configuration has no effect.

## Included deployment

`Stream-Manager-6.1.0/Server` is ready to use. Runtime 6.2.1 is installed below
`Server/releases/6.2.1`, and `cloudxr-runtime.yaml` enables both downstream audio and
upstream microphone streaming while retaining the alpha channel used for AR passthrough.

Install the virtual driver before starting Stream Manager. In Device Manager choose
**Action > Add legacy hardware > Install the hardware that I manually select > Sound,
video and game controllers > Have Disk**, then select:

`Runtime-6.2.1/CloudXRVirtualAudioDriver/nvcloudxrvad.inf`

In the copied, ready-to-run deployment the same file is at
`Server/releases/6.2.1/CloudXRVirtualAudioDriver/nvcloudxrvad.inf`.

Alternatively, run `Install-CloudXRVirtualAudioDriver.ps1` from an Administrator
PowerShell. It creates the hardware ID NVIDIA documents for this virtual controller and
installs the signed driver package. The script is idempotent and updates an existing
CloudXR device instead of creating a duplicate.

After installation, start `Stream-Manager-6.1.0/Server/NvStreamManager.exe`, start its
6.2.1 runtime, and only then launch the Unity player. The runtime creates an `NVIDIA
CloudXR` capture endpoint. Unity's `CloudXRLiveKitMicrophoneBridge` deliberately waits
for that endpoint, publishes it to LiveKit, and unmutes it.

The Apple Vision Pro must run visionOS 27.0 or later for CloudXR upstream microphone
audio. The Xcode project is pinned to CloudXR Framework 6.2.0 and calls
`setMicEnabled(true)` immediately after connecting.

## Verification

1. Confirm Device Manager contains the `NVIDIA CloudXR` sound controller.
2. Start Stream Manager and the 6.2.1 runtime.
3. Start the Unity player and let its local participant connect to LiveKit.
4. Build and run the visionOS app, connect it to the server, and accept the microphone prompt.
5. Confirm Unity logs `Published microphone successfully` and no missing-endpoint error.
6. Speak in the headset and verify the LiveKit room shows the Unity participant's audio
   level moving and the agent receives the utterance.

UDP port 48002 must be allowed from the Vision Pro to the Windows host.
