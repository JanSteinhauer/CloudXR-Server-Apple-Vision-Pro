# CloudXR Local Streaming — Connection Issues

## Setup

- **Client:** Apple Vision Pro running CloudXRKit 6.0.4
- **Server:** Windows PC with NVIDIA GeForce RTX 2070 Super, CloudXR Server 6.0.5
- **Network:** AVP connected via Windows ICS/Mobile Hotspot (`192.168.137.x` subnet)
- **Server IP:** `192.168.137.1`
- **Connection type:** `.localSecure()` with self-signed certificate trust

## Current Status

The client successfully authenticates with the CloudXR server (gets a session ID, creates a streaming session) but fails at the RTSP/WebSocket signaling handshake step.

## Error Progression

| Attempt | Error | Meaning |
|---------|-------|---------|
| 1 | `Timeout: connect timed out: 192.168.137.1:48010` | Firewall blocking port 48010 |
| 2 | `Connection refused` | Firewall disabled, but nothing listening on 48010 |
| 3 | `No message received` | Port proxy forwarded 48010→48322 (wrong port — 48322 is the CXR service port, not the signaling port) |

## Root Cause

The **streamsdk signaling server** (which should listen on port 48010) is not running or not starting properly.

Evidence:
- `netstat -an | findstr "48010"` shows nothing listening after removing port proxy
- `tasklist | findstr -i "cxr"` shows no CloudXR processes running
- The `cxr_streamsdk` log is only 28 lines and ends immediately after `Signaling server started`
- The server log warns about an **unsupported GPU**

## Unsupported GPU Warning

The server log explicitly states:

```
Unsupported GPU detected!
GPU: NVIDIA GeForce RTX 2070 Super (Vendor: 0x10de, Device: 0x1e91)

Supported GPUs:
  - NVIDIA GeForce RTX 4090
  - NVIDIA GeForce RTX 5080
  - NVIDIA GeForce RTX 5090
  - NVIDIA RTX 6000 Ada Generation
  - NVIDIA RTX PRO 6000 Blackwell Server Edition
  - NVIDIA L40
  - NVIDIA L40S
```

CloudXR 6.x likely requires these newer GPUs for the streaming encoder pipeline, causing the signaling server to crash or never fully initialize.

## Why It Worked on the VM

The VM (at `34.158.227.20`, a Google Cloud instance) likely had a supported GPU (e.g., L40 or T4 with different CloudXR version) and proper network configuration where all ports were accessible.

## Port Summary

| Port | Service | Status |
|------|---------|--------|
| 443 | CloudXR Bifrost auth/control | Working (client authenticates successfully) |
| 48322 | CloudXR IPC service | Listening on `0.0.0.0` — but this is NOT the signaling port |
| 48010 | NVST signaling (WebSocket) | NOT listening — this is the broken link |

## Possible Solutions

1. **Use a supported GPU** — Upgrade to RTX 4090 or use a cloud VM with L40/L40S
2. **Downgrade CloudXR** — CloudXR 4.x supported RTX 2070 Super
3. **Check for GPU override** — Look for an environment variable or config flag to bypass the GPU check (may still fail at encode time)
4. **Use the VM** — Continue using the GCP VM (`34.158.227.20`) which was previously working

## Configuration Changes Made

- Changed client IP in `ContentView.swift` from `34.158.227.20` to `192.168.137.1`
- Windows firewall rules added for TCP/UDP 47998-48322
- Windows firewall was fully disabled for testing (still failed)
