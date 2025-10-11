# Audio Assets Required

## Required Audio Files

This folder must contain the following audio files for the Fake Call and Emergency Siren features:

### 1. ringtone.mp3
- **Purpose**: Fake incoming call ringtone
- **Format**: MP3
- **Duration**: 10-30 seconds (will loop)
- **Recommended**: Use a standard phone ringtone sound
- **Where to get**:
  - Free ringtones from https://www.zedge.net/ringtones
  - Royalty-free audio from https://freesound.org/
  - Or use your own phone ringtone

### 2. siren.mp3
- **Purpose**: Emergency siren sound
- **Format**: MP3
- **Duration**: 5-10 seconds (will loop continuously)
- **Recommended**: Police or ambulance siren sound
- **Where to get**:
  - Free siren sounds from https://freesound.org/search/?q=siren
  - Police siren from https://www.zapsplat.com/
  - Or search "emergency siren sound effect" on Google

## How to Add Audio Files

1. Download the audio files from the sources above
2. Rename them exactly as:
   - `ringtone.mp3`
   - `siren.mp3`
3. Place both files in this `assets/sounds/` folder
4. Run `flutter pub get` to register the assets

## File Structure

```
assets/
└── sounds/
    ├── ringtone.mp3  ← Add this file
    ├── siren.mp3     ← Add this file
    └── README.md     ← This file
```

## Sample Audio Recommendations

### Ringtone:
- Search: "phone ringtone mp3 free"
- Example: Classic Nokia ringtone, iPhone ringtone, etc.
- File size: < 1MB

### Siren:
- Search: "police siren sound effect mp3 free"
- Example: Police car siren, ambulance siren, emergency alarm
- File size: < 500KB

## Important Notes

⚠️ **Make sure the file names are exactly**:
- `ringtone.mp3` (NOT Ringtone.mp3 or ringtone.wav)
- `siren.mp3` (NOT Siren.mp3 or siren.wav)

⚠️ **Supported formats**: MP3 is recommended for best compatibility across all platforms.

⚠️ **Copyright**: Ensure you have the right to use the audio files. Use royalty-free or creative commons licensed sounds.

## Testing

After adding the audio files:
1. Run: `flutter pub get`
2. Restart the app
3. Test "Fake Call" button on signin screen
4. Test "Emergency Siren" button on signin screen

If no sound plays, check:
- File names are correct (case-sensitive)
- Files are in the correct folder
- pubspec.yaml includes the assets path
- Audio files are valid MP3 format
