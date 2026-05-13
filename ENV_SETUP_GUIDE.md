# Environment Variables Setup Guide

## Overview

This project now uses environment variables to store sensitive API keys and configuration. This improves security by keeping secrets out of version control.

## Files

- **`.env`** - Your actual secrets (NOT committed to git)
- **`.env.example`** - Template file showing what variables are needed (committed to git)
- **`EnvironmentConfig.swift`** - Swift loader that reads .env file

## Setup

### 1. Create Your .env File

Copy the example file:

```bash
cd "/Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro"
cp .env.example .env
```

### 2. Edit .env With Your Secrets

Open `.env` and replace the placeholder values with your actual credentials:

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=xxx
FIREBASE_API_KEY=xxx

# CloudXR Configuration
CLOUDXR_CLIENT_TOKEN=xxx
```

⚠️ **Important**: The `.env` file is already created with your current credentials!

### 3. Verify .gitignore

The `.gitignore` file has been updated to exclude `.env` files:

```gitignore
# Environment variables - DO NOT COMMIT
.env
*.env
.env.*
!.env.example
```

This ensures your secrets are never committed to git.

## How It Works

### In Swift Code

The `EnvironmentConfig` class loads the `.env` file automatically:

```swift
// Get Firebase config
let (projectId, apiKey) = EnvironmentConfig.firebase
// projectId = "xxx"
// apiKey = "xxx"

// Get CloudXR token
let token = EnvironmentConfig.shared.cloudXRClientToken
// token = "xxx"

// Get any custom variable
if let customValue = EnvironmentConfig.shared.get("MY_CUSTOM_VAR") {
    print(customValue)
}
```

### Fallback Values

If the `.env` file is not found, the app uses fallback values defined in `EnvironmentConfig.swift`. This ensures the app still works during development.

### Debug Information

On app launch, the configuration is printed to console:

```
=== Environment Configuration ===
Loaded keys: CLOUDXR_CLIENT_TOKEN, FIREBASE_API_KEY, FIREBASE_PROJECT_ID
FIREBASE_PROJECT_ID: jansteinhauermasterthesis
FIREBASE_API_KEY: AIza...INII
CLOUDXR_CLIENT_TOKEN: SBl2...bDM
=================================
```

## File Locations

The `.env` loader checks these locations in order:

1. **Project Root** (primary):
   ```
   /Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro/.env
   ```

2. **App Bundle** (if included in build):
   ```
   Bundle.main.path(forResource: ".env", ofType: nil)
   ```

3. **Documents Directory** (for development):
   ```
   ~/Library/Containers/[AppID]/Data/Documents/.env
   ```

## Updated Files

### Files Now Using Environment Variables

✅ **FirebaseConfig.swift**
```swift
static let projectId = EnvironmentConfig.shared.firebaseProjectId
static let apiKey = EnvironmentConfig.shared.firebaseApiKey
```

✅ **My_First_AVP_CloudXR_ClientApp.swift**
```swift
let (projectId, apiKey) = EnvironmentConfig.firebase
_queryService = StateObject(wrappedValue: CloudXRQueryService(
    projectId: projectId,
    apiKey: apiKey
))
```

✅ **ContentView.swift**
```swift
config.connectionType = .localSecure(
    ip: "192.168.137.1",
    clientToken: EnvironmentConfig.shared.cloudXRClientToken,
    // ...
)
```

## Security Best Practices

### ✅ DO:
- Keep `.env` in your local project directory
- Add `.env` to `.gitignore` (already done)
- Use `.env.example` to document required variables
- Share `.env` securely via encrypted channels (1Password, etc.)
- Rotate API keys if they're accidentally committed

### ❌ DON'T:
- Commit `.env` to version control
- Share `.env` in plaintext (email, Slack, etc.)
- Hardcode secrets in Swift files
- Check `.env` into public repositories

## Sharing with Team Members

When a team member clones the repo:

1. They copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. They fill in their own credentials:
   ```bash
   # Open in editor
   nano .env
   ```

3. They run the app - `EnvironmentConfig` loads their secrets automatically.

## Git Status Check

Verify `.env` is not tracked:

```bash
cd "/Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro"
git status --ignored
```

You should see:
```
!! .env
```

## Adding New Variables

### 1. Add to .env
```bash
MY_NEW_SECRET=abc123
```

### 2. Add to .env.example
```bash
MY_NEW_SECRET=your_secret_here
```

### 3. Add to EnvironmentConfig.swift
```swift
var myNewSecret: String {
    config["MY_NEW_SECRET"] ?? "default_value"
}
```

### 4. Use in your code
```swift
let secret = EnvironmentConfig.shared.myNewSecret
```

## Troubleshooting

### "No .env file found, using fallback values"

This warning appears in the console if the `.env` file isn't found. The app will still work with fallback values, but you should create a `.env` file for production.

**Solution:**
```bash
cd "/Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro"
cp .env.example .env
# Edit .env with your values
```

### Changes to .env Not Reflecting

After editing `.env`, rebuild and rerun the app:
1. Stop the app
2. Clean build folder (⇧⌘K)
3. Build (⌘B)
4. Run (⌘R)

### .env Accidentally Committed

If you accidentally commit `.env`:

1. Remove from git (keep local file):
   ```bash
   git rm --cached .env
   git commit -m "Remove .env from version control"
   ```

2. Rotate your API keys immediately:
   - Firebase: Generate new Web API Key
   - CloudXR: Generate new client token

3. Update `.env` with new keys

## Current Configuration

Your `.env` file is located at:
```
/Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro/.env
```

It contains:
- ✅ Firebase Project ID
- ✅ Firebase API Key
- ✅ CloudXR Client Token

All secrets are now loaded from this file instead of being hardcoded! 🎉

## Testing

To verify environment loading works:

1. Run the app
2. Check Xcode console for:
   ```
   ✅ [EnvironmentConfig] Loaded .env from: /Users/.../ClaudeXR-Server-Apple-Vision-Pro/.env
   === Environment Configuration ===
   ...
   ```

3. Test Firebase connection by tapping "Firestore" button
4. Check that your API calls work correctly

## Need Help?

- **File not loading**: Check file path in console output
- **Variables not found**: Verify variable names match exactly (case-sensitive)
- **Git issues**: Run `git status --ignored` to check .env is ignored
- **Security concerns**: Never commit secrets, rotate keys if exposed

---

**Remember**: The `.env` file contains sensitive information. Treat it like a password! 🔒
