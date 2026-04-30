## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Package Contents](#package-contents)
4. [Configuration](#configuration)
5. [Basic Usage](#basic-usage)
6. [Usage Examples](#usage-examples)
7. [OpenXR Runtime Configuration](#openxr-runtime-configuration)
8. [Building from Source](#building-from-source)
9. [Common Workflows](#common-workflows)

## Overview

The CloudXR Stream Manager (NvStreamManager) is a Windows-based service that manages NVIDIA CloudXR runtime instances. It consists of two main components:

- **NvStreamManager.exe**: The server component that hosts the RPC service for managing CloudXR instances
- **SampleNvStreamManagerClient.exe**: A sample client application that demonstrates how to interact with the server

### Architecture

```
┌─────────────────────────────┐     RPC (Named Pipe)     ┌──────────────────────────┐
│ SampleNvStreamManagerClient │◄────────────────────────►│    NvStreamManager.exe   │
│         (Client)            │                          │        (Server)          │
└─────────────────────────────┘                          └────────────┬─────────────┘
                                                                      │
                                                                      │ Manages
                                                                      ▼
                                                         ┌────────────────────────────┐
                                                         │   CloudXR Service          │
                                                         │  (Multiple Versions)       │
                                                         └────────────────────────────┘
```

## Prerequisites

- **Operating System**: Windows 11 (64-bit)

## Package Contents

This release package contains the following components:

**Server/**
- `NvStreamManager.exe`: Main Stream Manager server
- `CloudXrService.exe`: CloudXR Service standalone server
- `cloudxr-runtime.yaml`: Configuration file (optional)

**SampleClient/**
- `SampleNvStreamManagerClient.exe`: Pre-built sample client executable
- `SampleNvStreamManagerClient.cpp`: Sample client source code
- `NvStreamManagerClient.h`: Client library header file
- `NvStreamManagerClient.dll`: Client library DLL
- `CMakeLists.txt`: CMake build file for the sample client

## Configuration

The NvStreamManager.exe will automatically load `cloudxr-runtime.yaml` if present in the same directory. You can customize runtime behavior by editing this file.

**Configuration Options:**
- To disable configuration loading: `NvStreamManager.exe --config ""`
- To use a different config file: `NvStreamManager.exe --config path\to\config.yaml`

## Basic Usage

### Server Setup

1. **Start the server with default settings**:
   ```cmd
   NvStreamManager.exe
   ```
   This starts the server with:
   - Default pipe name: `cloudxr-runtime`
   - Default runtime path: `.\releases`

2. **Start the server with a custom pipe name**:
   ```cmd
   NvStreamManager.exe --pipe my-custom-pipe
   ```
   
   **Note:** When using a custom pipe name, clients must connect using the same pipe name in `nv_rpc_client_create()`.

### Client Commands

The SampleNvStreamManagerClient.exe is an interactive command-line client that demonstrates how to use the NvStreamManager API.

#### Manual Server Start

1. **Ensure the server is running** (see previous section)

2. **Run the client**:
   ```cmd
   SampleNvStreamManagerClient.exe
   ```

3. The client will automatically:
   - Load the NvStreamManagerClient.dll
   - Connect to the server via named pipe
   - Present an interactive command prompt

#### Automatic Server Start

The client can automatically start the NvStreamManager as a background subprocess using the `--run-stream-manager` flag:

```cmd
SampleNvStreamManagerClient.exe --run-stream-manager=<path-to-NvStreamManager.exe>
```

**Example with absolute path:**
```cmd
SampleNvStreamManagerClient.exe --run-stream-manager=C:\CloudXR\Server\NvStreamManager.exe
```

**Example with relative path:**
```cmd
SampleNvStreamManagerClient.exe --run-stream-manager=..\Server\NvStreamManager.exe
```

**Features:**
- Stream manager starts as a background process with no console window
- Log output is redirected to `NvStreamManager_YYYYMMDD_HHMMSS.log` in the current directory (timestamped for each run)
- Working directory is automatically set to the stream manager's location
- The stream manager process automatically exits when the client exits (graceful or ungraceful)
- Client waits for the manager to initialize before attempting connection

**Available Commands:**

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `StartCxrService <version>` | Start CloudXR service | version (optional) | `StartCxrService 6.0.0` |
| `StopCxrService` | Stop running CloudXR service | None | `StopCxrService` |
| `GetSupportedVersions` | List available CloudXR versions | None | `GetSupportedVersions` |
| `GetCxrServiceJsonPath` | Get OpenXR runtime JSON path | None | `GetCxrServiceJsonPath` |
| `GetCxrServiceStatus` | Get service connection status | None | `GetCxrServiceStatus` |
| `GetCryptoKeyFingerprint <algo>` | Get cryptographic fingerprint | 0=MD5, 1=SHA1, 2=SHA256, 3=SHA512 | `GetCryptoKeyFingerprint 2` |
| `SetClientId <id>` | Set client identifier | Client ID string | `SetClientId MyApp123` |
| `ShutdownManager` | Shutdown the manager process | None | `ShutdownManager` |
| `help` | Show help message | None | `help` |
| `exit` or `quit` | Exit the client | None | `exit` |

## Usage Examples

```
> GetSupportedVersions
Getting supported CloudXR versions
Supported versions:
  - 6.0.0

> SetClientId MyApplication_v1.0
Setting client ID: MyApplication_v1.0
Client ID set successfully
Token: AUTH_TOKEN_GENERATED_BY_SERVER

> GetCryptoKeyFingerprint 2
Getting cryptographic key fingerprint for algorithm: 2
Cryptographic key fingerprint: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

> GetCxrServiceStatus
Getting CloudXR service status
CloudXR Service Status:
  OpenXR Runtime: Stopped
  OpenXR App: Disconnected
  CloudXR Client: Disconnected
  OpenXR Log File Path: [not available]

> StartCxrService 6.0.0
Starting CloudXR service with version: 6.0.0
CloudXR service start request successful

> GetCxrServiceJsonPath
Getting OpenXR Runtime JSON file path
OpenXR Runtime JSON file path: C:\CloudXR\Server\releases\6.0.0\openxr_cloudxr.json

> GetCxrServiceStatus
Getting CloudXR service status
CloudXR Service Status:
  OpenXR Runtime: Running
  OpenXR App: Connected
  CloudXR Client: Connected
  OpenXR Log File Path: C:\Users\xxx\AppData\Local\Temp\com.nvidia.CloudXR_6dcbb36963d4c272

> StopCxrService
Stopping CloudXR service
CloudXR service stop request successful

> ShutdownManager
Requesting manager shutdown
Manager shutdown request successful

> exit
Exiting interactive session...
```

## OpenXR Runtime Configuration

To use the CloudXR runtime with OpenXR applications, you need to configure the system to use the NVIDIA CloudXR OpenXR Runtime. There are two methods to accomplish this:

### Method 1: Manual Configuration with XrPicker (Testing Only)

**This method is for testing and development purposes only. Do not use this approach for production or formal integration.**

For manual testing and development, you can use the XrPicker tool to set the active OpenXR Runtime in the system:

1. **Download XrPicker**: Get the latest release from [https://github.com/rpavlik/xr-picker/releases](https://github.com/rpavlik/xr-picker/releases)

2. **Configure the Runtime**:
   - Click the folder icon on the top-right corner
   - Navigate to the `openxr_cloudxr.json` file (typically located in the CloudXR release directory, e.g., `Server\releases\6.0.0\`)
   - Click Open
   - Set the NVIDIA CloudXR Runtime as active by clicking the `make active` button

3. **Verify Configuration**: The XrPicker window should show the CloudXR runtime as the active runtime

### Method 2: Programmatic Configuration (Required for Formal Integration)

**This is the recommended method for production deployments and formal integration.**

For production applications and formal integration, you must dynamically set the OpenXR runtime programmatically using the IPC API and the OpenXR extension `XR_EXT_loader_init_properties`.

**Step 1: Get the OpenXR Runtime JSON Path**

Use the `GetCxrServiceJsonPath` command or API call to retrieve the path:

```cpp
char json_path[1024];
nv_rpc_result_t result = nv_rpc_client_get_cxr_service_json_path(client, json_path, sizeof(json_path));
if (result == NV_RPC_SUCCESS) {
    // json_path now contains the path to openxr_cloudxr.json
}
```

**Step 2: Initialize the OpenXR Loader**

Use the retrieved path to configure the OpenXR loader before creating an instance:

```cpp
// Path queried from Stream Manager
std::string runtime_json_path = json_path;

PFN_xrInitializeLoaderKHR initializeLoader = nullptr;
XrResult result = xrGetInstanceProcAddr(
    XR_NULL_HANDLE,
    "xrInitializeLoaderKHR",
    reinterpret_cast<PFN_xrVoidFunction*>(&initializeLoader));
if (result != XR_SUCCESS) {
    // Handle error
}

std::vector<XrLoaderInitPropertyValueEXT> propertyList = {};
propertyList.push_back(XrLoaderInitPropertyValueEXT{"XR_RUNTIME_JSON", runtime_json_path.c_str()});

XrLoaderInitInfoPropertiesEXT loaderProperties{
    .type = XR_TYPE_LOADER_INIT_INFO_PROPERTIES_EXT,
    .propertyValueCount = static_cast<uint32_t>(propertyList.size()),
    .propertyValues = propertyList.data(),
};

result = initializeLoader((XrLoaderInitInfoBaseHeaderKHR*)&loaderProperties);
if (result != XR_SUCCESS) {
    // Handle error
}

// The OpenXR loader is now setup to load the CloudXR runtime
// You can now call xrEnumerateInstanceExtensionProperties and xrCreateInstance
```

## OpenXR Runtime Configuration

To use the CloudXR runtime with OpenXR applications, you need to configure the system to use the NVIDIA CloudXR OpenXR Runtime. There are two methods to accomplish this:

### Method 1: Manual Configuration with XrPicker (Testing Only)

**This method is for testing and development purposes only. Do not use this approach for production or formal integration.**

For manual testing and development, you can use the XrPicker tool to set the active OpenXR Runtime in the system:

1. **Download XrPicker**: Get the latest release from [https://github.com/rpavlik/xr-picker/releases](https://github.com/rpavlik/xr-picker/releases)

2. **Configure the Runtime**:
   - Click the folder icon on the top-right corner
   - Navigate to the `openxr_cloudxr.json` file (typically located in the CloudXR release directory, e.g., `Server\releases\6.0.0\`)
   - Click Open
   - Set the NVIDIA CloudXR Runtime as active by clicking the `make active` button

3. **Verify Configuration**: The XrPicker window should show the CloudXR runtime as the active runtime

### Method 2: Programmatic Configuration (Required for Formal Integration)

**This is the recommended method for production deployments and formal integration.**

For production applications and formal integration, you must dynamically set the OpenXR runtime programmatically using the IPC API and the OpenXR extension `XR_EXT_loader_init_properties`.

**Step 1: Get the OpenXR Runtime JSON Path**

Use the `GetCxrServiceJsonPath` command or API call to retrieve the path:

```cpp
char json_path[1024];
nv_rpc_result_t result = nv_rpc_client_get_cxr_service_json_path(client, json_path, sizeof(json_path));
if (result == NV_RPC_SUCCESS) {
    // json_path now contains the path to openxr_cloudxr.json
}
```

**Step 2: Initialize the OpenXR Loader**

Use the retrieved path to configure the OpenXR loader before creating an instance:

```cpp
// Path queried from Stream Manager
std::string runtime_json_path = json_path;

PFN_xrInitializeLoaderKHR initializeLoader = nullptr;
XrResult result = xrGetInstanceProcAddr(
    XR_NULL_HANDLE,
    "xrInitializeLoaderKHR",
    reinterpret_cast<PFN_xrVoidFunction*>(&initializeLoader));
if (result != XR_SUCCESS) {
    // Handle error
}

std::vector<XrLoaderInitPropertyValueEXT> propertyList = {};
propertyList.push_back(XrLoaderInitPropertyValueEXT{"XR_RUNTIME_JSON", runtime_json_path.c_str()});

XrLoaderInitInfoPropertiesEXT loaderProperties{
    .type = XR_TYPE_LOADER_INIT_INFO_PROPERTIES_EXT,
    .propertyValueCount = static_cast<uint32_t>(propertyList.size()),
    .propertyValues = propertyList.data(),
};

result = initializeLoader((XrLoaderInitInfoBaseHeaderKHR*)&loaderProperties);
if (result != XR_SUCCESS) {
    // Handle error
}

// The OpenXR loader is now setup to load the CloudXR runtime
// You can now call xrEnumerateInstanceExtensionProperties and xrCreateInstance
```

## Building from Source

If you want to build the sample client from the release package:

1. Navigate to the SampleClient directory:
   ```cmd
   cd SampleClient
   ```

2. Create build directory and configure:
   ```cmd
   mkdir build
   cd build
   cmake ..
   ```

3. Build the project:
   ```cmd
   cmake --build . --config Release
   ```

4. Run the built executable:
   ```cmd
   .\Release\SampleNvStreamManagerClient.exe
   ```
   (or `.\SampleNvStreamManagerClient.exe` for single-config generators)

**Note:** The SampleNvStreamManagerClient requires `NvStreamManagerClient.dll` to be in the same directory as the executable. The CMakeLists.txt automatically copies the DLL to the output directory during build.

## Common Workflows

**Workflow 1: Starting CloudXR for VR Application (Manual Server Start)**

1. Start the NvStreamManager server:
   ```cmd
   NvStreamManager.exe
   ```

2. In another terminal, run the client:
   ```cmd
   SampleNvStreamManagerClient.exe
   ```

3. Check available versions and start the service:
   ```
   > GetSupportedVersions
   > SetClientId MyAVP
   > GetCryptoKeyFingerprint 2
   > StartCxrService 6.0.0
   > GetCxrServiceJsonPath
   > GetCxrServiceStatus
   ```

4. Launch your VR application (it will automatically use the CloudXR runtime)

5. When done, stop the service:
   ```
   > StopCxrService
   ```

**Workflow 1b: Starting CloudXR with Automatic Server Start**

1. Run the client with auto-start flag (no need to manually start server):
   ```cmd
   SampleNvStreamManagerClient.exe --run-stream-manager=..\Server\NvStreamManager.exe
   ```

2. The client will automatically start the stream manager and connect to it

3. Check available versions and start the service:
   ```
   > GetSupportedVersions
   > SetClientId MyAVP
   > GetCryptoKeyFingerprint 2
   > StartCxrService 6.0.0
   > GetCxrServiceJsonPath
   > GetCxrServiceStatus
   ```

4. Launch your VR application (it will automatically use the CloudXR runtime)

5. When done, stop the service and exit:
   ```
   > StopCxrService
   > exit
   ```
   
   The stream manager process will automatically terminate when the client exits.

**Workflow 2: Integration with Application**

For integrating with your own application, use the NvStreamManagerClient.dll API:

```cpp
#include "NvStreamManagerClient.h"

// Create and connect client
// Note: The pipe_name parameter must match the pipe name used when starting NvStreamManager
// Default is "cloudxr-runtime", but can be customized with --pipe argument on server
nv_rpc_client_t client;
nv_rpc_client_create("cloudxr-runtime", &client);  // Use custom pipe name if server was started with --pipe
nv_rpc_client_connect(client);

// Start CloudXR service
nv_rpc_client_start_cxr_service(client, "6.0.0", 5);

// Get OpenXR runtime JSON path for programmatic configuration
// See "OpenXR Runtime Configuration" section for complete integration example
char json_path[1024];
nv_rpc_client_get_cxr_service_json_path(client, json_path, sizeof(json_path));

// Monitor service status during operation
nv_rpc_client_get_cxr_service_status(client, &status);
// status.openxr_app_connected and status.cloudxr_client_connected
// indicate connection states

// Your application logic here...

// Cleanup
// Stop any running CloudXR services first (recommended)
nv_rpc_client_stop_cxr_service(client);

// There are two paths after this - you can shutdown the stream manager (manager process will exit)
// or just disconnect from the stream manager.

// Option 1: Shutdown
nv_rpc_result_t result = nv_rpc_client_shutdown_manager(client);
if (result == NV_RPC_SUCCESS) {
    // Manager is shutting down
}

// Option 2: Disconnect (stream manager keeps running).
nv_rpc_client_disconnect(client);

// Call destroy to free resources (After shutdown or disconnect).
nv_rpc_client_destroy(client);
```

**Note:** The `ShutdownManager` command will gracefully shutdown the NvStreamManager process. Use this when you want to completely stop the manager rather than just exiting the client.

For complete instructions on configuring the OpenXR runtime programmatically, see the [OpenXR Runtime Configuration](#openxr-runtime-configuration) section.
