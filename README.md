# Universal ThemeCenter Patch

A Magisk/KernelSU/APatch module that enables unlimited custom theme overlays on Samsung devices by patching `ThemeCenter.apk` with smali modifications to remove trial expiration limits and filter dummy overlay APKs.

## 📋 Description

This patch modifies Samsung's theme manager to:
- Remove trial theme expiration limits for **unlimited theme duration**
- Disable version checking and time-based restrictions
- Filter dummy overlay APKs that cause Samsung OverlayManager crashes
- Enable unlimited application of custom theme overlays without restrictions

**Compatible with:**
- 🧲 Magisk
- 🧲 KernelSU
- 🧲 APatch

## 🔧 Core Features

### Smali Modifications
- **`setTrialExpiredPackage`** - Removes trial theme expiration logic, enabling **unlimited theme duration**
- **`setAlarm`** - Disables time-based limitation alarms that enforce expiration
- **Dummy Overlay APK Filter** - Removes placeholder APKs that crash Samsung's OverlayManager

### Embedded Tools Suite
- `apktool` - APK decompilation/recompilation
- `aapt` - APK package analysis
- `zipalign` - APK resource alignment optimization
- `busybox` & `bash` - Core system utilities

## 📦 Installation

1. **Download** the latest module ZIP
2. **Install** via your root manager (Magisk Manager, KernelSU, etc.)
3. **Reboot** your device
4. ✅ Patch is applied automatically

## 🚀 Usage

After installation, you can:
- Access Samsung ThemeCenter without restrictions
- Apply custom theme overlays indefinitely
- Keep themes applied permanently (no expiration)
- Use modified themes without crashes

## ⚙️ Technical Details

### Patching Process

```
1. Localization → Finds ThemeCenter.apk in /system
2. Decompilation → Extracts smali code
3. Patching → Modifies target methods
4. Recompilation → Rebuilds the patched APK
5. Alignment → Optimizes resources (zipalign)
6. Verification → Confirms integrity
```

### Architecture

- **SKIPUNZIP=1** - Handles custom file extraction
- **Embedded tool suite** - Standalone ARM tools compatible with any ROM
- **Smali manipulation** - Regex-based method patching for maximum flexibility
- **Framework integration** - Copies framework-res.apk for proper resource decoding

## ⚠️ Requirements

- ✅ Samsung device (with ThemeCenter.apk)
- ✅ **Deodexed** ThemeCenter.apk (contains `classes.dex`)
- ✅ Root access (Magisk/KernelSU/APatch)

## 🐛 Troubleshooting

**"Can't find ThemeCenter.apk"**
- Verify this is a Samsung device
- Patch only works on official Samsung ROMs

**"ThemeCenter.apk is odexed"**
- Your ROM uses compiled APKs (odexed)
- Requires deodexed version to patch

**Crashes after installation**
- Clear ThemeCenter cache in Settings → Apps
- Reboot your device
- Verify framework-res.apk is accessible

**Themes still expiring**
- Ensure you're on a supported ThemeCenter version
- Check if the patch applied successfully in module logs

## 📝 Credits

- **@BlassGO** - Original DynamicInstaller logic
- **@Benj2557** - Magisk/KernelSU/APatch compatibility

## 📄 License

MIT License - Free to use and modify

---

**Version:** 3.0  
**Last Updated:** 2026
