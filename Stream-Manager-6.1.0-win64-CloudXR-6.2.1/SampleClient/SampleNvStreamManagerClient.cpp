// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES.
// All rights reserved. SPDX-License-Identifier: Apache-2.0 or MIT

#include "NvStreamManagerClient.h"
#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <windows.h>


using namespace std;

#define MAX_PATH_SIZE 512
#define MAX_FINGERPRINT_SIZE 256
#define MAX_TOKEN_SIZE 256

// Global function pointers
struct RpcClientFunctions
{
	pfn_nv_rpc_client_create create;
	pfn_nv_rpc_client_destroy destroy;
	pfn_nv_rpc_client_connect connect;
	pfn_nv_rpc_client_disconnect disconnect;
	pfn_nv_rpc_client_start_cxr_service start_cxr_service;
	pfn_nv_rpc_client_stop_cxr_service stop_cxr_service;
	pfn_nv_rpc_client_get_supported_versions get_supported_versions;
	pfn_nv_rpc_client_get_cxr_service_json_path get_cxr_service_json_path;
	pfn_nv_rpc_client_get_crypto_key_fingerprint get_crypto_key_fingerprint;
	pfn_nv_rpc_client_free_string_array free_string_array;
	pfn_nv_rpc_client_get_error_string get_error_string;
	pfn_nv_rpc_client_set_client_id set_client_id;
	pfn_nv_rpc_client_get_cxr_service_status get_cxr_service_status;
	pfn_nv_rpc_client_shutdown_manager shutdown_manager;
};

static RpcClientFunctions g_rpc_functions = {0};
static HMODULE g_dll_handle = nullptr;
static PROCESS_INFORMATION g_stream_manager_process = {0};
static HANDLE g_stream_manager_job = nullptr;

// Helper function to convert string to lowercase
string
str_to_lower(const string &str)
{
	string result = str;
	transform(result.begin(), result.end(), result.begin(), ::tolower);
	return result;
}

// Helper function to trim whitespace
string
trim_whitespace(const string &str)
{
	if (str.empty())
		return str;

	// Find first non-whitespace character
	size_t start = str.find_first_not_of(" \t\n\r\f\v");
	if (start == string::npos)
		return "";

	// Find last non-whitespace character
	size_t end = str.find_last_not_of(" \t\n\r\f\v");

	return str.substr(start, end - start + 1);
}

// Helper function to parse command line input
pair<string, string>
parse_command(const string &input)
{
	string trimmed_input = trim_whitespace(input);
	if (trimmed_input.empty())
		return make_pair("", "");

	// Find first space
	size_t space_pos = trimmed_input.find(' ');
	if (space_pos != string::npos) {
		string command = str_to_lower(trim_whitespace(trimmed_input.substr(0, space_pos)));
		string parameter = trim_whitespace(trimmed_input.substr(space_pos + 1));
		return make_pair(command, parameter);
	} else {
		string command = str_to_lower(trimmed_input);
		return make_pair(command, "");
	}
}

void
print_help()
{
	cout << "Available commands:\n"
	     << "  - StartCxrService <version> - Start the CloudXR service with the "
	        "specified version\n"
	     << "  - StopCxrService           - Stop the running CloudXR service\n"
	     << "  - GetSupportedVersions     - List all supported CloudXR versions\n"
	     << "  - GetCxrServiceJsonPath   - Get the OpenXR Runtime JSON file path\n"
	     << "  - GetCryptoKeyFingerprint <algorithm> - Get the cryptographic key "
	        "fingerprint (algorithms: 0=MD5, 1=SHA-1, 2=SHA-256, 3=SHA-512)\n"
	     << "  - SetClientId <client_id> - Set the client ID and get the token\n"
	     << "  - GetCxrServiceStatus    - Get the current service connection "
	        "status\n"
	     << "  - ShutdownManager        - Shutdown the manager process\n"
	     << "  - help                      - Show this help message\n"
	     << "  - exit/quit                 - End the session\n";
}

// Command handler functions
void
handle_start_cxr_service_command(nv_rpc_client_t client, const string &parameter)
{
	string version = parameter.empty() ? "5.0.0-beta" : parameter;

	if (parameter.empty()) {
		cout << "Using default version: " << version << "\n";
	}

	cout << "Starting CloudXR service with version: " << version << "\n";
	nv_rpc_result_t result = g_rpc_functions.start_cxr_service(client, version.c_str(), version.length());

	if (result == NV_RPC_SUCCESS) {
		cout << "CloudXR service start request successful\n";
	} else {
		cerr << "Failed to start CloudXR service: " << g_rpc_functions.get_error_string(result) << "\n";
	}
}

void
handle_stop_cxr_service_command(nv_rpc_client_t client)
{
	cout << "Stopping CloudXR service\n";
	nv_rpc_result_t result = g_rpc_functions.stop_cxr_service(client);

	if (result == NV_RPC_SUCCESS) {
		cout << "CloudXR service stop request successful\n";
	} else {
		cerr << "Failed to stop CloudXR service: " << g_rpc_functions.get_error_string(result) << "\n";
	}
}

void
handle_get_supported_versions_command(nv_rpc_client_t client)
{
	cout << "Getting supported CloudXR versions\n";
	nv_string_array_t versions;
	nv_rpc_result_t result = g_rpc_functions.get_supported_versions(client, &versions);

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to get supported versions: " << g_rpc_functions.get_error_string(result) << "\n";
		return;
	}

	if (versions.count == 0) {
		cout << "No supported versions found\n";
	} else {
		cout << "Supported versions:\n";
		for (size_t i = 0; i < versions.count; i++) {
			cout << "  - " << versions.strings[i] << "\n";
		}
	}
	g_rpc_functions.free_string_array(&versions);
}

void
handle_get_cxr_service_json_path_command(nv_rpc_client_t client)
{
	cout << "Getting OpenXR Runtime JSON file path\n";

	// Use std::string instead of char array
	string json_path(MAX_PATH_SIZE, '\0');
	nv_rpc_result_t result = g_rpc_functions.get_cxr_service_json_path(client, &json_path[0], json_path.size() - 1);

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to get CXR service path: " << g_rpc_functions.get_error_string(result) << "\n";
		return;
	} else {
		cout << "OpenXR Runtime JSON file path: " << json_path.c_str() << "\n";
	}
}

void
handle_get_crypto_key_fingerprint_command(nv_rpc_client_t client, const string &parameter)
{
	if (parameter.empty()) {
		cout << "Usage: GetCryptoKeyFingerprint <algorithm>\n";
		return;
	}

	int algorithm = stoi(parameter);
	if (algorithm < 0 || algorithm > 3) {
		cout << "Invalid algorithm: " << algorithm << "\n";
		cout << "Valid algorithms: 0=MD5, 1=SHA-1, 2=SHA-256, 3=SHA-512\n";
		return;
	}

	cout << "Getting cryptographic key fingerprint for algorithm: " << algorithm << "\n";

	// Use std::string instead of char array
	string fingerprint(MAX_FINGERPRINT_SIZE, '\0');
	nv_rpc_result_t result = g_rpc_functions.get_crypto_key_fingerprint(client, (nv_crypto_algorithm_t)algorithm,
	                                                                    &fingerprint[0], fingerprint.size() - 1);

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to get crypto key fingerprint: " << g_rpc_functions.get_error_string(result) << "\n";
		return;
	} else {
		cout << "Cryptographic key fingerprint: " << fingerprint.c_str() << "\n";
	}
}

void
handle_set_client_id_command(nv_rpc_client_t client, const string &parameter)
{
	if (parameter.empty()) {
		cout << "Usage: SetClientId <client_id>\n";
		return;
	}

	cout << "Setting client ID: " << parameter << "\n";

	// Use std::string instead of unsigned char array
	string token(MAX_TOKEN_SIZE, '\0');
	size_t token_size = 0;
	nv_rpc_result_t result =
	    g_rpc_functions.set_client_id(client, parameter.c_str(), parameter.length(),
	                                  reinterpret_cast<unsigned char *>(&token[0]), token.size(), &token_size);

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to set client ID: " << g_rpc_functions.get_error_string(result) << "\n";
		return;
	}

	cout << "Client ID set successfully\n";

	// Resize token to actual returned size
	token.resize(token_size);

	if (token.empty()) {
		cout << "No token received\n";
	} else {
		cout << "Token: " << token << "\n";
	}
}

void
handle_get_cxr_service_status_command(nv_rpc_client_t client)
{
	cout << "Getting CloudXR service status\n";

	nv_service_status_t status;
	nv_rpc_result_t result = g_rpc_functions.get_cxr_service_status(client, &status);

	cout << "CloudXR Service Status:\n";

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to get service status: " << g_rpc_functions.get_error_string(result) << "\n";
		cout << "  OpenXR Runtime: Unknown status\n";
		cout << "  OpenXR App: Unknown connection status\n";
		cout << "  CloudXR Client: Unknown connection status\n";
		return;
	}

	// Display the status
	cout << "  OpenXR Runtime: " << (status.openxr_runtime_running ? "Running" : "Stopped") << "\n";
	cout << "  OpenXR App: " << (status.openxr_app_connected ? "Connected" : "Disconnected") << "\n";
	cout << "  CloudXR Client: " << (status.cloudxr_client_connected ? "Connected" : "Disconnected") << "\n";
	cout << "  OpenXR Log File Path: "
	     << (status.openxr_log_file_path_length > 0
	             ? std::string(status.openxr_log_file_path, status.openxr_log_file_path_length)
	             : "[not available]")
	     << "\n";
}

void
handle_shutdown_manager_command(nv_rpc_client_t client)
{
	cout << "Requesting manager shutdown\n";
	nv_rpc_result_t result = g_rpc_functions.shutdown_manager(client);

	if (result == NV_RPC_SUCCESS) {
		cout << "Manager shutdown request successful\n";
	} else {
		cerr << "Failed to shutdown manager: " << g_rpc_functions.get_error_string(result) << "\n";
	}
}

// Helper function to try loading DLL from fallback paths
int
try_load_dll_from_fallback_paths()
{
	const std::array<const char *, 3> dll_paths = {".\\NvStreamManagerClient.dll", "..\\NvStreamManagerClient.dll",
	                                               nullptr};

	for (size_t i = 0; i < dll_paths.size() && dll_paths[i] != nullptr; i++) {
		cout << "Trying to load from: " << dll_paths[i] << "\n";
		g_dll_handle = LoadLibraryA(dll_paths[i]);
		if (g_dll_handle) {
			cout << "Successfully loaded DLL from: " << dll_paths[i] << "\n";
			return 1;
		}
	}
	return 0;
}

// Load the DLL and get function pointers
int
load_rpc_client_dll()
{
	// Try to load the DLL from the same directory first
	g_dll_handle = LoadLibraryA("NvStreamManagerClient.dll");

	if (!g_dll_handle) {
		DWORD error = GetLastError();
		cerr << "Failed to load NvStreamManagerClient.dll (error " << error << ")\n";

		if (!try_load_dll_from_fallback_paths()) {
			cerr << "Could not find NvStreamManagerClient.dll in any search path\n";
			return 0;
		}
	}

	// Get function pointers
	g_rpc_functions.create = (pfn_nv_rpc_client_create)GetProcAddress(g_dll_handle, "nv_rpc_client_create");
	g_rpc_functions.destroy = (pfn_nv_rpc_client_destroy)GetProcAddress(g_dll_handle, "nv_rpc_client_destroy");
	g_rpc_functions.connect = (pfn_nv_rpc_client_connect)GetProcAddress(g_dll_handle, "nv_rpc_client_connect");
	g_rpc_functions.disconnect =
	    (pfn_nv_rpc_client_disconnect)GetProcAddress(g_dll_handle, "nv_rpc_client_disconnect");
	g_rpc_functions.start_cxr_service =
	    (pfn_nv_rpc_client_start_cxr_service)GetProcAddress(g_dll_handle, "nv_rpc_client_start_cxr_service");
	g_rpc_functions.stop_cxr_service =
	    (pfn_nv_rpc_client_stop_cxr_service)GetProcAddress(g_dll_handle, "nv_rpc_client_stop_cxr_service");
	g_rpc_functions.get_supported_versions = (pfn_nv_rpc_client_get_supported_versions)GetProcAddress(
	    g_dll_handle, "nv_rpc_client_get_supported_versions");
	g_rpc_functions.get_cxr_service_json_path = (pfn_nv_rpc_client_get_cxr_service_json_path)GetProcAddress(
	    g_dll_handle, "nv_rpc_client_get_cxr_service_json_path");
	g_rpc_functions.get_crypto_key_fingerprint = (pfn_nv_rpc_client_get_crypto_key_fingerprint)GetProcAddress(
	    g_dll_handle, "nv_rpc_client_get_crypto_key_fingerprint");
	g_rpc_functions.free_string_array =
	    (pfn_nv_rpc_client_free_string_array)GetProcAddress(g_dll_handle, "nv_rpc_client_free_string_array");
	g_rpc_functions.get_error_string =
	    (pfn_nv_rpc_client_get_error_string)GetProcAddress(g_dll_handle, "nv_rpc_client_get_error_string");
	g_rpc_functions.set_client_id =
	    (pfn_nv_rpc_client_set_client_id)GetProcAddress(g_dll_handle, "nv_rpc_client_set_client_id");
	g_rpc_functions.get_cxr_service_status = (pfn_nv_rpc_client_get_cxr_service_status)GetProcAddress(
	    g_dll_handle, "nv_rpc_client_get_cxr_service_status");
	g_rpc_functions.shutdown_manager =
	    (pfn_nv_rpc_client_shutdown_manager)GetProcAddress(g_dll_handle, "nv_rpc_client_shutdown_manager");

	// Check if all functions were loaded
	if (!g_rpc_functions.create || !g_rpc_functions.destroy || !g_rpc_functions.connect ||
	    !g_rpc_functions.disconnect || !g_rpc_functions.start_cxr_service || !g_rpc_functions.stop_cxr_service ||
	    !g_rpc_functions.get_supported_versions || !g_rpc_functions.get_cxr_service_json_path ||
	    !g_rpc_functions.get_crypto_key_fingerprint || !g_rpc_functions.free_string_array ||
	    !g_rpc_functions.get_error_string || !g_rpc_functions.set_client_id ||
	    !g_rpc_functions.get_cxr_service_status || !g_rpc_functions.shutdown_manager) {
		cerr << "Failed to load one or more required functions from DLL\n";
		FreeLibrary(g_dll_handle);
		g_dll_handle = nullptr;
		return 0;
	}

	cout << "Successfully loaded all RPC client functions from DLL\n";
	return 1;
}

void
unload_rpc_client_dll()
{
	if (g_dll_handle) {
		FreeLibrary(g_dll_handle);
		g_dll_handle = nullptr;
	}
	memset(&g_rpc_functions, 0, sizeof(g_rpc_functions));
}

// Start the NvStreamManager as a subprocess
int
start_stream_manager_subprocess(const char *stream_manager_path)
{
	cout << "Starting NvStreamManager subprocess: " << stream_manager_path << "\n";

	// Create a job object to ensure child process dies with parent
	g_stream_manager_job = CreateJobObjectA(nullptr, nullptr);
	if (!g_stream_manager_job) {
		cerr << "Failed to create job object (error " << GetLastError() << ")\n";
		return 0;
	}

	// Configure job to kill all processes when the job handle is closed
	JOBOBJECT_EXTENDED_LIMIT_INFORMATION job_info;
	ZeroMemory(&job_info, sizeof(job_info));
	job_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

	if (!SetInformationJobObject(g_stream_manager_job, JobObjectExtendedLimitInformation, &job_info,
	                             sizeof(job_info))) {
		cerr << "Failed to set job object information (error " << GetLastError() << ")\n";
		CloseHandle(g_stream_manager_job);
		g_stream_manager_job = nullptr;
		return 0;
	}

	// Create log file for the stream manager output with timestamp
	SYSTEMTIME st;
	GetLocalTime(&st);

	char log_filename[256];
	snprintf(log_filename, sizeof(log_filename), "NvStreamManager_%04d%02d%02d_%02d%02d%02d.log", st.wYear,
	         st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

	SECURITY_ATTRIBUTES sa;
	sa.nLength = sizeof(SECURITY_ATTRIBUTES);
	sa.bInheritHandle = TRUE;
	sa.lpSecurityDescriptor = nullptr;

	HANDLE log_file = CreateFileA(log_filename, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
	                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);

	if (log_file == INVALID_HANDLE_VALUE) {
		cerr << "Failed to create log file: " << log_filename << " (error " << GetLastError() << ")\n";
		CloseHandle(g_stream_manager_job);
		g_stream_manager_job = nullptr;
		return 0;
	}

	// Set up process startup info to redirect output
	STARTUPINFOA si;
	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);
	si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdOutput = log_file;
	si.hStdError = log_file;
	si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

	ZeroMemory(&g_stream_manager_process, sizeof(g_stream_manager_process));

	// Create a mutable copy of the command line
	string command_line = string(stream_manager_path);

	// Extract the directory path from the stream manager path
	string working_directory;
	size_t last_slash = command_line.find_last_of("\\/");
	if (last_slash != string::npos) {
		working_directory = command_line.substr(0, last_slash);
		cout << "Setting working directory to: " << working_directory << "\n";
	}

	// Create the process
	BOOL success =
	    CreateProcessA(nullptr,          // Application name (use command line)
	                   &command_line[0], // Command line (mutable)
	                   nullptr,          // Process security attributes
	                   nullptr,          // Thread security attributes
	                   TRUE,             // Inherit handles
	                   CREATE_NO_WINDOW, // Creation flags - no console window
	                   nullptr,          // Environment
	                   working_directory.empty() ? nullptr : working_directory.c_str(), // Current directory
	                   &si,                                                             // Startup info
	                   &g_stream_manager_process                                        // Process information
	    );

	CloseHandle(log_file);

	if (!success) {
		DWORD error = GetLastError();
		cerr << "Failed to start NvStreamManager process (error " << error << ")\n";
		CloseHandle(g_stream_manager_job);
		g_stream_manager_job = nullptr;
		return 0;
	}

	// Assign the process to the job object
	if (!AssignProcessToJobObject(g_stream_manager_job, g_stream_manager_process.hProcess)) {
		cerr << "Failed to assign process to job object (error " << GetLastError() << ")\n";
		TerminateProcess(g_stream_manager_process.hProcess, 1);
		CloseHandle(g_stream_manager_process.hProcess);
		CloseHandle(g_stream_manager_process.hThread);
		CloseHandle(g_stream_manager_job);
		g_stream_manager_job = nullptr;
		ZeroMemory(&g_stream_manager_process, sizeof(g_stream_manager_process));
		return 0;
	}

	cout << "NvStreamManager started successfully (PID: " << g_stream_manager_process.dwProcessId << ")\n";
	cout << "Log output redirected to: " << log_filename << "\n";
	cout << "Process will automatically terminate when client exits\n";

	// Give the process a moment to start
	Sleep(500);

	return 1;
}

// Cleanup the stream manager subprocess
void
cleanup_stream_manager_subprocess()
{
	if (g_stream_manager_process.hProcess) {
		// Check if process is still running
		DWORD exit_code;
		if (GetExitCodeProcess(g_stream_manager_process.hProcess, &exit_code) && exit_code == STILL_ACTIVE) {
			cout << "Terminating stream manager process (PID: " << g_stream_manager_process.dwProcessId
			     << ")\n";
			TerminateProcess(g_stream_manager_process.hProcess, 0);
			// Wait up to 2 seconds for process to terminate
			WaitForSingleObject(g_stream_manager_process.hProcess, 2000);
		}

		CloseHandle(g_stream_manager_process.hProcess);
		CloseHandle(g_stream_manager_process.hThread);
		ZeroMemory(&g_stream_manager_process, sizeof(g_stream_manager_process));
	}

	// Close the job object - this will also kill any processes in the job
	// if they haven't already been terminated
	if (g_stream_manager_job) {
		CloseHandle(g_stream_manager_job);
		g_stream_manager_job = nullptr;
	}
}

// Initialize and connect the RPC client
int
initialize_rpc_client(nv_rpc_client_t *client)
{
	// Create the RPC client
	nv_rpc_result_t result = g_rpc_functions.create("cloudxr-runtime", client);

	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to create RPC client: " << g_rpc_functions.get_error_string(result) << "\n";
		return 0;
	}

	// Try to connect to the server
	result = g_rpc_functions.connect(*client);
	if (result != NV_RPC_SUCCESS) {
		cerr << "Failed to connect to the RPC server: " << g_rpc_functions.get_error_string(result) << "\n";
		cerr << "Make sure the service is running\n";
		g_rpc_functions.destroy(*client);
		return 0;
	}

	return 1;
}

// Run the interactive command loop
void
run_interactive_session(nv_rpc_client_t client)
{
	cout << "Enter commands in the format: <command> [parameters...]\n";
	print_help();

	string user_input;
	bool running = true;

	while (running) {
		// Prompt for user input
		cout << "\n> ";

		if (!getline(cin, user_input))
			break;

		// Skip empty input
		if (user_input.empty())
			continue;

		// Parse the input
		pair<string, string> parsed = parse_command(user_input);
		string command = parsed.first;
		string parameter = parsed.second;
		if (command.empty())
			continue;

		// Process commands
		if (command == "exit" || command == "quit") {
			running = false;
			cout << "Exiting interactive session...\n";
		} else if (command == "startcxrservice") {
			handle_start_cxr_service_command(client, parameter);
		} else if (command == "stopcxrservice") {
			handle_stop_cxr_service_command(client);
		} else if (command == "getsupportedversions") {
			handle_get_supported_versions_command(client);
		} else if (command == "getcxrservicejsonpath") {
			handle_get_cxr_service_json_path_command(client);
		} else if (command == "getcryptokeyfingerprint") {
			handle_get_crypto_key_fingerprint_command(client, parameter);
		} else if (command == "help") {
			print_help();
		} else if (command == "setclientid") {
			handle_set_client_id_command(client, parameter);
		} else if (command == "getcxrservicestatus") {
			handle_get_cxr_service_status_command(client);
		} else if (command == "shutdownmanager") {
			handle_shutdown_manager_command(client);
			return;
		} else {
			cerr << "Unknown command: " << command << "\n";
			cout << "Type 'help' for a list of available commands\n";
		}
	}
}

int
main(int argc, char **argv)
{
	// Parse command line arguments for --run-stream-manager flag
	string stream_manager_path;
	for (int i = 1; i < argc; i++) {
		string arg = argv[i];
		const string flag_prefix = "--run-stream-manager=";

		if (arg.find(flag_prefix) == 0) {
			stream_manager_path = arg.substr(flag_prefix.length());
			break;
		}
	}

	// Start the stream manager subprocess if path was provided
	if (!stream_manager_path.empty()) {
		if (!start_stream_manager_subprocess(stream_manager_path.c_str())) {
			cerr << "Failed to start stream manager subprocess\n";
			return 1;
		}

		// Wait a bit longer for the manager to initialize before connecting
		cout << "Waiting for stream manager to initialize...\n";
		Sleep(2000);
	}

	// Load the DLL dynamically
	if (!load_rpc_client_dll()) {
		cerr << "Failed to load RPC client DLL\n";
		cleanup_stream_manager_subprocess();
		return 1;
	}

	// Initialize and connect the RPC client
	nv_rpc_client_t client;
	if (!initialize_rpc_client(&client)) {
		unload_rpc_client_dll();
		cleanup_stream_manager_subprocess();
		return 1;
	}

	// Run the interactive session
	run_interactive_session(client);

	// Disconnect and cleanup
	g_rpc_functions.disconnect(client);
	g_rpc_functions.destroy(client);
	unload_rpc_client_dll();
	cleanup_stream_manager_subprocess();

	return 0;
}