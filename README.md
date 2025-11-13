# X2D GPS Companion

A specialized iOS companion app for Hasselblad X2D camera users. Automatically geotags your photos by monitoring the photo library in real-time and applying precise GPS coordinates from your device's location services.

## ⚠️ Important Notes

- **Mainland China Users**: Location data is recorded using the GCJ-02 coordinate system (Mars Coordinates) when operating in mainland China. Initial location previews in Apple Photos may appear offset. To resolve this, simply reopen the Photos app or tap the location for accurate positioning details.

## Key Features

- **Automatic Geotagging**: Seamlessly embeds GPS coordinates into photos from your Hasselblad X2D
- **Background Recording**: Continuous location tracking even when the app is not in the foreground
- **Live Activity Support**: Real-time recording status on lock screen and Dynamic Island
- **Multi-Language Support**: Fully localized in English, German, French, Japanese, and Simplified Chinese
- **Granular Permission Management**: Fine-grained control over photo library and location access
- **Auto-Start Recording**: Optionally begin recording automatically on app launch
- **Comprehensive Logging**: Detailed activity logs for troubleshooting and monitoring

## System Requirements

- iOS 26.0 or later
- Hasselblad X2D camera

## Required Permissions

The app requires two separate authorizations:

1. **Photo Library Access** (Full Access)
   - Enables automatic GPS coordinate embedding in photo metadata
   - Full library access is required (limited access is insufficient)

2. **Location Services** (Always Allow)
   - Enables continuous background GPS tracking
   - Must be set to "Always Allow" for background recording functionality

## Supported Languages

- 🇬🇧 English
- 🇩🇪 German (Deutsch)
- 🇫🇷 French (Français)
- 🇯🇵 Japanese (日本語)
- 🇨🇳 Simplified Chinese (简体中文)

## Getting Started

1. Download and install [**Phocus 2**](https://apps.apple.com/app/id1452280435) from the App Store to enable the Street Shot Assistant workflow
2. Install **X2D GPS Companion** on your iOS device
3. Grant the required location and photo library permissions when prompted
4. Tap the recording button to begin location tracking
5. The app will automatically geotag new photos from your Hasselblad X2D

### Live Activity

When recording is active, a Live Activity widget displays on your lock screen and Dynamic Island with real-time status updates. **Do not dismiss the Live Activity during recording**, as this may interrupt location tracking.

## Privacy & Security

- **Fully Offline Operation**: No internet connection required—all processing occurs locally on your device

For comprehensive privacy details, see the [Privacy Statements](Resources/Privacy/PrivacyStatements-2025.10.19.md).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

For bug reports, feature requests, or questions, please [open an issue](https://github.com/Lakr233/X2D-GPS-Companion/issues) on GitHub.
