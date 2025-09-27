# Safe Travel App Authentication System

## Overview
The Safe Travel App now features a complete authentication system that integrates with a MongoDB backend, ensuring users can only sign in with created accounts and proper user data management.

## Features

### ✅ Complete Authentication Flow
- **User Registration**: Full signup with name, email, phone, and password
- **User Login**: Secure signin with email and password validation
- **Automatic Login**: Persistent authentication on app restart
- **Token Management**: JWT token with automatic refresh
- **Secure Logout**: Complete data clearing on signout

### ✅ Backend Integration
- **MongoDB Database**: Full integration with Express.js backend
- **JWT Authentication**: Secure token-based authentication
- **User Validation**: Server-side validation matching frontend
- **Error Handling**: Comprehensive error responses and handling

### ✅ User Interface
- **Loading States**: Visual feedback during authentication processes
- **Error Display**: Clear error messages for failed operations
- **Form Validation**: Client-side validation with helpful error messages
- **Professional Design**: Consistent with app's design system

## How It Works

### 1. User Registration
- Users enter: Full Name, Email, Phone Number, Password, Confirm Password
- Frontend validates all fields before submission
- Backend creates user account in MongoDB
- JWT token generated and stored locally
- User automatically logged in after successful registration

### 2. User Login
- Users enter: Email and Password
- Credentials validated against MongoDB database
- JWT token generated and stored locally
- User data loaded from database
- Home screen displays actual user information

### 3. Persistent Authentication
- On app startup, checks for existing valid JWT token
- If token exists and not expired, user automatically logged in
- If token expired, attempts to refresh automatically
- If refresh fails, user redirected to login screen

### 4. User Data Display
- Home screen shows personalized greeting with user's first name
- Profile screen populated with actual user data from database
- All user-specific features use real authenticated user data

## Configuration

### Backend URL Configuration
Update the backend URL in `/lib/config/api_config.dart`:

```dart
class ApiConfig {
  // Update this URL to match your backend server
  static const String baseUrl = 'http://your-backend-url:3000/api/v1';
}
```

For local development, use:
- `http://localhost:3000/api/v1` (if running on same machine)
- `http://YOUR_IP_ADDRESS:3000/api/v1` (if running on different device)

### Backend Requirements
Ensure your backend server is running with:
1. MongoDB database connection
2. User registration endpoint: `POST /auth/signup`
3. User login endpoint: `POST /auth/signin`
4. Token refresh endpoint: `POST /auth/refresh`
5. User logout endpoint: `POST /auth/signout`

## File Structure

### New Authentication Files
```
lib/
├── services/
│   └── auth_service.dart          # Complete authentication service
├── config/
│   └── api_config.dart           # Centralized API configuration
└── screens/
    ├── signin_screen.dart        # Updated with loading states
    └── signup_screen.dart        # Updated with name/phone fields
```

### Updated Files
- `lib/main.dart` - Authentication state management
- `lib/screens/home_screen.dart` - Real user data display
- `lib/services/emergency_contact_service.dart` - Updated API config

## Authentication Flow

```
App Start
    ↓
Check for stored JWT token
    ↓
    ├── Token exists & valid → Load user data → Home Screen
    ├── Token exists & expired → Refresh token → Home Screen or Login
    └── No token → Login Screen

Login/Register
    ↓
Validate credentials with backend
    ↓
    ├── Success → Store JWT & user data → Home Screen
    └── Failure → Show error message

Logout
    ↓
Call backend logout endpoint
    ↓
Clear all stored authentication data
    ↓
Redirect to Login Screen
```

## Security Features

1. **JWT Token Authentication**: Secure token-based authentication
2. **Token Expiration**: 24-hour token expiry with automatic refresh
3. **Secure Storage**: Authentication data stored using SharedPreferences
4. **Password Validation**: Minimum 6 characters with frontend/backend validation
5. **Input Sanitization**: Email and phone number format validation
6. **Error Handling**: No sensitive data exposed in error messages

## Testing the Authentication

1. **Start Backend Server**: Ensure your Express.js/MongoDB backend is running
2. **Configure API URL**: Update `ApiConfig.baseUrl` to point to your backend
3. **Build & Run**: `flutter run` or `flutter build apk`
4. **Test Registration**: Create a new account with valid data
5. **Test Login**: Sign in with the created account
6. **Test Persistence**: Close and reopen app to verify automatic login
7. **Test Logout**: Sign out and verify complete data clearing

## Error Handling

The authentication system handles various error scenarios:
- Network connectivity issues
- Invalid credentials
- Server errors
- Token expiration
- Validation errors
- Duplicate account registration

## Next Steps

1. **Backend Configuration**: Update backend URL in ApiConfig
2. **Database Setup**: Ensure MongoDB is properly configured
3. **Testing**: Test all authentication flows with live backend
4. **Production**: Deploy backend and update production URL

## Support

The authentication system is fully integrated with:
- Emergency contacts management
- SOS alert system
- User profile management
- Real-time location tracking
- All other app features

Users can now only access the app with valid accounts, and all user-specific data will be properly managed through the authenticated user system.