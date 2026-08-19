[CmdletBinding()]
param(
    [string]$DriverDirectory = ''
)

$ErrorActionPreference = 'Stop'
$hardwareId = 'USB\VID_0959&PID_9004'

if ([string]::IsNullOrWhiteSpace($DriverDirectory)) {
    $standaloneDriver = Join-Path $PSScriptRoot 'Runtime-6.2.1\CloudXRVirtualAudioDriver'
    $deployedDriver = Join-Path $PSScriptRoot 'Server\releases\6.2.1\CloudXRVirtualAudioDriver'
    $DriverDirectory = if (Test-Path -LiteralPath $standaloneDriver) {
        $standaloneDriver
    } else {
        $deployedDriver
    }
}

$infPath = [System.IO.Path]::GetFullPath((Join-Path $DriverDirectory 'nvcloudxrvad.inf'))

if (-not (Test-Path -LiteralPath $infPath -PathType Leaf)) {
    throw "CloudXR virtual audio driver INF not found: $infPath"
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated (Administrator) PowerShell session.'
}

$existing = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
    $_.InstanceId -like "*$hardwareId*" -or $_.FriendlyName -eq 'NVIDIA CloudXR'
}

if ($existing) {
    Write-Host 'The NVIDIA CloudXR virtual audio device already exists. Updating its driver package.'
    & pnputil.exe /add-driver $infPath /install
    if ($LASTEXITCODE -ne 0) { throw "pnputil failed with exit code $LASTEXITCODE" }
    exit 0
}

$source = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class CloudXRVirtualAudioInstaller
{
    private const uint DICD_GENERATE_ID = 0x00000001;
    private const uint SPDRP_HARDWAREID = 0x00000001;
    private const uint DIF_REGISTERDEVICE = 0x00000019;
    private const uint INSTALLFLAG_FORCE = 0x00000001;
    private static readonly IntPtr InvalidHandleValue = new IntPtr(-1);

    [StructLayout(LayoutKind.Sequential)]
    private struct SP_DEVINFO_DATA
    {
        public uint cbSize;
        public Guid ClassGuid;
        public uint DevInst;
        public IntPtr Reserved;
    }

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid classGuid, IntPtr parentWindow);

    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool SetupDiCreateDeviceInfo(
        IntPtr deviceInfoSet,
        string deviceName,
        ref Guid classGuid,
        string deviceDescription,
        IntPtr parentWindow,
        uint creationFlags,
        ref SP_DEVINFO_DATA deviceInfoData);

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern bool SetupDiSetDeviceRegistryProperty(
        IntPtr deviceInfoSet,
        ref SP_DEVINFO_DATA deviceInfoData,
        uint property,
        byte[] propertyBuffer,
        uint propertyBufferSize);

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern bool SetupDiCallClassInstaller(
        uint installFunction,
        IntPtr deviceInfoSet,
        ref SP_DEVINFO_DATA deviceInfoData);

    [DllImport("setupapi.dll", SetLastError = true)]
    private static extern bool SetupDiDestroyDeviceInfoList(IntPtr deviceInfoSet);

    [DllImport("newdev.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool UpdateDriverForPlugAndPlayDevices(
        IntPtr parentWindow,
        string hardwareId,
        string fullInfPath,
        uint installFlags,
        out bool rebootRequired);

    public static bool Install(string hardwareId, string fullInfPath)
    {
        var mediaClassGuid = new Guid("4d36e96c-e325-11ce-bfc1-08002be10318");
        var deviceInfoSet = SetupDiCreateDeviceInfoList(ref mediaClassGuid, IntPtr.Zero);
        if (deviceInfoSet == InvalidHandleValue)
            ThrowLastError("SetupDiCreateDeviceInfoList");

        try
        {
            var deviceInfoData = new SP_DEVINFO_DATA();
            deviceInfoData.cbSize = (uint)Marshal.SizeOf(typeof(SP_DEVINFO_DATA));

            if (!SetupDiCreateDeviceInfo(
                    deviceInfoSet,
                    "NVIDIA CloudXR",
                    ref mediaClassGuid,
                    "NVIDIA CloudXR Virtual Audio Device",
                    IntPtr.Zero,
                    DICD_GENERATE_ID,
                    ref deviceInfoData))
                ThrowLastError("SetupDiCreateDeviceInfo");

            var multiString = Encoding.Unicode.GetBytes(hardwareId + "\0\0");
            if (!SetupDiSetDeviceRegistryProperty(
                    deviceInfoSet,
                    ref deviceInfoData,
                    SPDRP_HARDWAREID,
                    multiString,
                    (uint)multiString.Length))
                ThrowLastError("SetupDiSetDeviceRegistryProperty");

            if (!SetupDiCallClassInstaller(DIF_REGISTERDEVICE, deviceInfoSet, ref deviceInfoData))
                ThrowLastError("SetupDiCallClassInstaller(DIF_REGISTERDEVICE)");
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(deviceInfoSet);
        }

        bool rebootRequired;
        if (!UpdateDriverForPlugAndPlayDevices(
                IntPtr.Zero,
                hardwareId,
                fullInfPath,
                INSTALLFLAG_FORCE,
                out rebootRequired))
            ThrowLastError("UpdateDriverForPlugAndPlayDevices");

        return rebootRequired;
    }

    private static void ThrowLastError(string operation)
    {
        throw new Win32Exception(Marshal.GetLastWin32Error(), operation + " failed");
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
$restartNeeded = [CloudXRVirtualAudioInstaller]::Install($hardwareId, $infPath)

& pnputil.exe /scan-devices
if ($LASTEXITCODE -ne 0) { throw "pnputil scan failed with exit code $LASTEXITCODE" }

Write-Host 'NVIDIA CloudXR virtual audio driver installed successfully.'
if ($restartNeeded) {
    Write-Warning 'Windows reported that a restart is required before the audio device can be used.'
}
