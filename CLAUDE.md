# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeyKeeper is a secure Flutter password manager with biometric unlock and TOTP support. The app uses system-level encryption and biometric authentication to secure stored passwords.

## Common Commands

### Development
- `flutter pub get` - Install dependencies
- `flutter run` - Run the app (defaults to first available device/emulator)
- `flutter run -d <device>` - Run on specific device
- `flutter run --debug` - Run in debug mode
- `flutter run --profile` - Run in profile mode

### Build
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires macOS)
- `flutter build macos` - Build macOS app
- `flutter build windows` - Build Windows executable
- `flutter build web` - Build for web

### Code Quality
- `flutter analyze` - Run static analysis
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run specific test file

### Code Generation
- `flutter pub run build_runner build` - Generate Hive models (after adding TypeAdapters)
- `flutter pub run build_runner build --delete-conflicting-outputs` - Regenerate models

## Architecture

### Security Architecture
The app uses a layered security approach:
1. **Biometric Authentication** (local_auth) - Required to unlock the app
2. **Secure Storage** (flutter_secure_storage) - Stores encryption key at system level
3. **Encrypted Database** (Hive with HiveAesCipher) - All data encrypted with AES-256
4. **Field Encryption** (encrypt package) - Individual passwords encrypted with AES

### Key Components

**Main Initialization** (`main.dart`):
- Initializes Hive with encryption cipher
- Generates/retrieves 32-byte AES key from secure storage on first launch
- Opens encrypted Hive box named `account_entry_box`
- Configures go_router with two routes: `/unlock` (entry point) and `/home`

**Routes** (go_router):
- `/unlock` - Biometric authentication page (initial route)
- `/home` - Main password management interface

**Global Constants** (defined in main.dart):
- `hiveBoxName`: `'password_box'` - Hive database name
- `secureKeyName`: `'encryption_key'` - Key for secure storage
- `secureStorage`: FlutterSecureStorage instance
- `localAuth`: LocalAuthentication instance

### Database Schema (Hive)
The app uses Hive for local encrypted storage. When adding new models:
1. Annotate with `@HiveType(typeId: n)`
2. Add fields with `@HiveField(n)` annotations
3. Register TypeAdapters in main.dart before opening the box
4. Run `flutter pub run build_runner build` to generate TypeAdapter

### State Management
Currently uses StatefulWidget for page-level state. Consider implementing a state management solution (Provider, Riverpod, or Bloc) as the app grows.

### Dependencies
- `local_auth: ^2.1.6` - Biometric authentication
- `flutter_secure_storage: ^8.0.0` - Secure key storage
- `hive: ^2.2.3` - Encrypted local database
- `encrypt: ^5.0.1` - AES encryption for passwords
- `otp: ^3.1.0` - TOTP code generation
- `go_router: ^12.1.0` - Declarative routing

## Important Security Considerations

1. **Never hardcode encryption keys** - Keys must only exist in secure storage
2. **Always use HiveAesCipher** - Never open Hive boxes without encryption
3. **Biometric fallback** - The app is configured to show system password if biometric fails (biometricOnly: false)
4. **Key management** - The AES key is generated once on first launch and persisted in secure storage; loss of this key means loss of all data

## Code Structure

- `lib/main.dart` - App entry point, initialization, and routing configuration
- `lib/pages/unlock_page.dart` - Biometric authentication interface
- `lib/pages/home_page.dart` - Main password management interface (placeholder)
- `lib/models/` - Hive models (to be added)
- `lib/services/` - Data services (to be added)

## Platform-Specific Notes

- **iOS**: Requires Face ID/Touch ID capability in Xcode
- **Android**: Requires fingerprint permission in AndroidManifest.xml
- **Windows/macOS**: Biometric support varies by platform version
