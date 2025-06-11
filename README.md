# @solutionsmedias360/react-native-vision-camera-text-recognition

> ⚠️ This is a **fork** of [`gev2002/react-native-vision-camera-text-recognition`](https://github.com/gev2002/react-native-vision-camera-text-recognition) with a patch for Android build failures introduced in React Native 0.77+.

---

## Why this fork?

Starting from **React Native 0.77**, the original package fails to compile on Android due to changes in the Android Gradle and Kotlin toolchain compatibility.

This fork applies the fix proposed in the following upstream PR, which has not yet been merged:

- ✅ PR: [Fix Kotlin incompatibility for RN 0.77+](https://github.com/gev2002/react-native-vision-camera-text-recognition/pull/27)
- 🐛 Related Issue: [#25 - Android build fails on RN 0.77](https://github.com/gev2002/react-native-vision-camera-text-recognition/issues/25)

### Changes in this fork:

- Applied the Kotlin compatibility fix for RN 0.77+ (based on the above PR)