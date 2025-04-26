# Mobile App Build and Deployment Guide

## Overview

This guide covers building, signing, debugging, and deploying native iOS and Android apps, including containerized Android builds, iOS build requirements, Google Cloud CLI integration, Play Store API usage, Firebase integration, and web app deployment.

---

## iOS App

- Requires macOS with Xcode installed.
- Use the `scripts/ios_build_sign.sh` script to build and sign the app.
- Update the script variables for your workspace, scheme, and export options.
- Containerizing Xcode is only possible on macOS hosts.
- For debugging, use Xcode's debugger and device logs.
- To test on your device, install the generated IPA via Xcode or TestFlight.

---

## Android App

- Android builds can be done in a Docker container using `docker/android-build.Dockerfile`.
- Build and sign the APK using `scripts/android_build_sign.sh`.
- Update keystore paths and passwords in the script.
- Use the Docker container to ensure consistent build environment.
- For debugging, use Android Studio or React Native Debugger.
- To test on your device, install the signed APK manually or via adb.

---

## Google Cloud CLI and Play Store API

- Authenticate using a service account JSON key.
- Use `scripts/gcloud_playstore_deploy.sh` to upload APKs to Google Play Store.
- Update package name, project ID, and paths in the script.

---

## Firebase Integration

- Integrate Firebase SDKs in your native apps.
- Configure credentials and analytics as per Firebase documentation.
- Use the existing `firebase.json` for emulator and hosting setup for the web app.

---

## Web App Deployment

- The React web app can be deployed officially online using Firebase Hosting.
- Use the command `npm run build` to build the web app.
- Deploy using `firebase deploy` (already configured in package.json).
- For debugging, use `npm start` to run the app locally with hot reload.

---

## Summary

1. Prepare native app projects in `ios/` and `android/`.
2. Use provided scripts and Dockerfile for building, signing, debugging, and deploying.
3. Deploy the web app using Firebase Hosting.
4. Follow Firebase integration steps for analytics and other services.

For detailed Firebase setup, refer to the official Firebase documentation.

