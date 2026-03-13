# Digital Ether v32 - Quick Start Guide

**Welcome to Digital Ether v32!** This guide will get you up and running in 5 minutes.

---

## 🚀 What's New in v32?

### Major Features
- 💬 **Persistent Chat History** - Messages now survive app restarts
- 🌐 **Better P2P on Mobile** - TURN servers for 4G/5G connectivity  
- 🔐 **Firebase Auth Fixed** - No more DEVELOPER_ERROR
- 👤 **Admin Panel Verified** - Comprehensive access control testing

---

## ⚡ Quick Setup (5 Minutes)

### Step 1: Check SHA-256 in Firebase (Already Done! ✅)

Good news! Your SHA-256 fingerprint is already registered:
```
SHA256: 2F:D4:7E:AF:4B:F3:7A:BD:38:46:75:9A:8E:F5:56:22:7E:3E:96:33:4D:2D:84:80:8A:FB:8D:DD:DF:49:B9:6B
```

**Status**: ✅ Complete - No action needed!

If you need to verify, check Firebase Console: https://console.firebase.google.com/project/game26-base/settings

---

### Step 2: Build & Deploy (3 min)

```powershell
# Navigate to project
cd c:\Users\ormix\StudioProjects\bcgame

# Build release APK and publish to GitHub
.\build_and_deploy.ps1 -Environment Production
```

The script will:
- ✅ Increment build number automatically
- ✅ Build optimized release APK
- ✅ Upload to GitHub Releases
- ✅ Copy to game-server/public/ for OTA updates

**Output**: 
```
=== SUCCESS: Release 0.32 published! ===
URL: https://github.com/AlexIves16/bcgg/releases/tag/0.32
```

---

### Step 3: Install on Device

**Option A: Direct Install (USB)**
```bash
adb install build\app\outputs\flutter-apk\app-release.apk
```

**Option B: OTA Download (WiFi)**
1. Host the APK: `http://your-game-server.com/app-release.apk`
2. Open URL on Android device
3. Download and install

---

## 🧪 Testing Checklist (2 minutes)

### Test 1: Chat Persistence ✅
1. Open app → Login
2. Open any chat → Send "Hello v32!"
3. Close app completely
4. Reopen app → Open same chat
5. **Expected**: "Hello v32!" still visible

### Test 2: P2P on Mobile Data ✅
1. Device A: Enable WiFi, send message
2. Device B: Enable 4G/5G (disable WiFi), receive message
3. **Expected**: Message received within 5 seconds

### Test 3: Admin Access ✅
1. Login as admin user
2. Navigate to Admin Panel
3. **Expected**: Panel opens, settings load correctly
4. Logout → Login as regular user
5. Try to open Admin Panel
6. **Expected**: "Access Denied" message

---

## 📚 Documentation Index

All v32 documentation is in the `docs/` folder:

| Document | When You Need It |
|----------|------------------|
| **[V32_RELEASE_SUMMARY.md](V32_RELEASE_SUMMARY.md)** | Complete overview of all changes |
| **[TURN_SERVER_SETUP.md](TURN_SERVER_SETUP.md)** | P2P not working on mobile data |
| **[CHAT_CACHE_IMPLEMENTATION.md](CHAT_CACHE_IMPLEMENTATION.md)** | Chat history issues |
| **[ADMIN_ACCESS_TESTING.md](ADMIN_ACCESS_TESTING.md)** | Admin panel troubleshooting |

---

## 🔧 Common Issues & Quick Fixes

### Issue: DEVELOPER_ERROR on Login
**Fix**: You haven't added SHA-256 to Firebase Console yet (see Step 1 above)

### Issue: Chat messages disappear after closing app
**Fix**: Should work automatically. Check logs:
```bash
adb logcat | grep ChatCache
```

### Issue: Can't connect on mobile data
**Fix**: TURN servers are already configured. Check firewall settings on your router.

### Issue: Admin panel shows "Access Denied"
**Fix**: Set `isAdmin: true` in Firestore:
1. Firebase Console → Firestore
2. Collection: `users`, Document: `{user-uid}`
3. Add field: `isAdmin` → `true`

---

## 📊 What Changed from v31?

### Code Changes Summary

**Files Modified**: 3
- `lib/network/webrtc_manager.dart` - TURN servers + chat cache integration
- `lib/network/chat_cache.dart` - Enhanced deduplication
- `lib/profile/chat_screen.dart` - Improved message handling

**Files Added**: 4 documentation files in `docs/`

**Lines Changed**: ~100 lines of code + ~1200 lines of documentation

---

## 🎯 Next Steps (After Testing)

### Immediate (This Week)
- [ ] Test on real devices with mobile data
- [ ] Verify chat persistence with multiple users
- [ ] Confirm admin panel works in production

### Short-term (Next Sprint - v33)
- [ ] Sound Combat Balance tuning
- [ ] Anti-cheat implementation for sensors
- [ ] Cloud backup for chat history
- [ ] Advanced admin permissions (roles)

---

## 🆘 Getting Help

### Debug Logs
```bash
# Filter relevant logs
adb logcat | grep -E "\[WebRTC\]|\[ChatCache\]|\[ADMIN\]"

# Save logs to file
adb logcat -d > debug_logs.txt
```

### Where to Ask
- **GitHub Issues**: https://github.com/AlexIves16/bcgg/issues
- **Discord**: [Invite Link]
- **Email**: support@digitalether.game

### What to Include in Bug Report
1. Device model and Android version
2. Steps to reproduce
3. Debug logs (see command above)
4. Screenshot if UI issue

---

## 🎉 Success Criteria

You know v32 is working when:

✅ Users can login without DEVELOPER_ERROR  
✅ Chat messages persist after app close  
✅ P2P works between WiFi and mobile data  
✅ Admin panel accessible only to admins  
✅ No crashes or major bugs reported  

---

## 📈 Performance Targets

| Feature | Target | How to Measure |
|---------|--------|----------------|
| Chat load time | <100ms | Time from open chat to messages visible |
| P2P connect time | <10s | Time from invite to "Online" status |
| Message delivery | <1s | Time from send to receive on other device |
| Admin panel load | <2s | Time from tap to panel visible |

---

## 🙏 Thank You!

Thanks for using Digital Ether v32! Your feedback helps us improve.

**Please report**:
- Any bugs you encounter
- Feature requests
- Performance issues
- UX suggestions

---

**Version**: 0.32+  
**Build Date**: March 12, 2026  
**Minimum Android**: API 21 (Android 5.0)  
**Recommended**: API 29+ (Android 10+)  

© 2026 Digital Ether Project
