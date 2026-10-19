# Walter Water

A tiny native macOS menu bar app that reminds you to drink water. A translucent floating card glides in from the left and settles at screen center. Its illustrated bottle gently bobs while water bubbles rise. Choose **I drank water** to confirm and watch the card animate away, or snooze for 10 minutes.

## Build and run

Requires macOS 13 or later and Xcode (including its Swift compiler and macOS SDK). From this folder, run:

To create the app bundle, run `./build_app.sh`. To create a macOS installer package, run:

```sh
./package_app.sh
```

This creates `build/Walter Water.pkg`. Open the package and follow the installer prompts; it installs the app in `/Applications`. The app uses an ad-hoc signature, and the installer package is unsigned. Sharing it with others requires Developer ID signing and notarization.

Click the 💧 menu bar item to choose a 30-minute, 1-hour, or 2-hour interval, pause/resume reminders, or show a reminder immediately. The interval and pause state persist between launches. The first reminder appears after the chosen interval.

The app is ad-hoc signed for local use. For personal use, macOS may still ask you to approve the unsigned installer in Privacy & Security. Sharing it with others requires Developer ID signing and notarization.
