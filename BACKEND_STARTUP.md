# Backend Server Startup Guide

## Quick Fix for "Connection Refused" Error

The error you're seeing occurs because the backend server is not running. Here's how to fix it:

### Step 1: Start Backend Server

1. **Open a new terminal/command prompt**
2. **Navigate to backend directory:**
   ```bash
   cd E:\safe_travel_app\Safe_Travel_App_Backend
   ```

3. **Install dependencies (if not done already):**
   ```bash
   npm install
   ```

4. **Start the server:**
   ```bash
   npm start
   ```
   OR
   ```bash
   node server.js
   ```

### Step 2: Verify Server is Running

You should see output like:
```
🚀 Server running on port 3000
📊 Environment: development
🗄️ MongoDB connected successfully
```

### Step 3: Test Connection

Open your browser and go to: `http://localhost:3000`
You should see the API health check response.

### Common Issues & Solutions

#### Issue 1: MongoDB Connection Error
**Error:** `MongooseError: Could not connect to MongoDB`
**Solution:** 
- Check your `.env` file has correct MongoDB URI
- Ensure MongoDB Atlas/local MongoDB is running
- Check network connectivity

#### Issue 2: Port Already in Use
**Error:** `EADDRINUSE: address already in use`
**Solution:**
- Kill process on port 3000: `npx kill-port 3000`
- Or change port in `.env` file: `PORT=3001`

#### Issue 3: Missing Dependencies
**Error:** `Cannot find module 'express'`
**Solution:**
- Run `npm install` in backend directory
- Check package.json exists

### Android Emulator Configuration

If testing on Android emulator, update the API URL:

In `lib/config/api_config.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api/v1';
```

### Physical Device Configuration

If testing on physical device, use your computer's IP address:

1. Find your IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
2. Update API URL:
```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:3000/api/v1';
```

### Verification Steps

1. ✅ Backend server running on port 3000
2. ✅ MongoDB connected successfully  
3. ✅ Frontend API URL matches backend URL
4. ✅ Network connectivity between frontend and backend

### Debug Network Issues

Add this test to your Flutter app (temporary):

```dart
// Test network connectivity
void testConnection() async {
  try {
    final response = await http.get(Uri.parse('http://10.0.2.2:3000'));
    print('Connection test: ${response.statusCode}');
  } catch (e) {
    print('Connection failed: $e');
  }
}
```

### Backend Server Commands Reference

```bash
# Navigate to backend
cd E:\safe_travel_app\Safe_Travel_App_Backend

# Install dependencies
npm install

# Start server (development)
npm start

# Start server (with nodemon for auto-restart)
npm run dev

# Check if running
curl http://localhost:3000
```

After starting the backend server, your Flutter authentication should work properly!