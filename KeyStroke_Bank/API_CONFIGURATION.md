# API Configuration Guide

## Current Setup
Your Flutter app is configured to connect to the Flask backend running on `localhost:5000`.

## Environment-Specific URLs

### Android Emulator
- **URL**: `http://10.0.2.2:5000`
- **File**: `lib/config/api_config.dart`
- **Current Setting**: ✅ Configured for emulator

### Physical Android Device
- **URL**: `http://localhost:5000` (or your computer's IP address)
- **To Change**: Edit `lib/config/api_config.dart` line 12
- **Change to**: `return 'http://localhost:5000';`

### iOS Simulator
- **URL**: `http://localhost:5000`
- **File**: `lib/config/api_config.dart`
- **Current Setting**: ✅ Configured

### Physical iOS Device
- **URL**: `http://localhost:5000` (or your computer's IP address)
- **File**: `lib/config/api_config.dart`
- **Current Setting**: ✅ Configured

### Web Browser
- **URL**: Uses proxy configuration
- **File**: `web/proxy.conf.json`
- **Current Setting**: ✅ Configured

## How to Switch Between Emulator and Physical Device

### For Android Physical Device:
1. Open `lib/config/api_config.dart`
2. Change line 12 from:
   ```dart
   return 'http://10.0.2.2:5000';
   ```
   to:
   ```dart
   return 'http://localhost:5000';
   ```
3. Restart your Flutter app

### For Android Emulator:
1. Open `lib/config/api_config.dart`
2. Change line 12 from:
   ```dart
   return 'http://localhost:5000';
   ```
   to:
   ```dart
   return 'http://10.0.2.2:5000';
   ```
3. Restart your Flutter app

## Backend Status
- **Flask Backend**: ✅ Running on `localhost:5000`
- **Database**: ✅ SQLite database active
- **API Endpoints**: ✅ All endpoints working

## Testing Connection
You can test if the backend is working by visiting:
- `http://localhost:5000/api/auth/signup` (should return 201 for POST requests)
- `http://localhost:5000/api/accounts` (should return 401 for GET requests - requires auth)

## Troubleshooting
1. **"Failed to load accounts" error**: Make sure Flask backend is running
2. **Connection refused**: Check if backend is on port 5000
3. **Authentication errors**: Normal - endpoints require login
