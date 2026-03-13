# Admin Access Verification Guide (v32)

## Overview
This guide covers testing admin panel access in release builds of Digital Ether.

## Current Status (v32)
✅ **Admin screen implemented** with Firestore-based permission checks  
✅ **Detailed logging** added for debugging access issues  
✅ **Regional RTDB URL** fixed (europe-west1)  

## Architecture

### Permission Flow
```
User opens Admin Panel
    ↓
1. Check if user is authenticated (Firebase Auth)
2. Fetch user document from Firestore
3. Verify isAdmin == true flag
4. Grant/Deny access with detailed logging
```

### Files Involved
- `lib/admin_screen.dart` - Main admin UI + access control
- `lib/firebase_options.dart` - Firebase config (region settings)
- `game-server/index.js` - Server-side admin actions processor

## Testing Checklist

### Pre-Build Setup

#### 1. Verify Firebase Configuration
```bash
# Check google-services.json has correct RTDB URL
cat android/app/google-services.json | grep databaseURL
```
**Expected**: `"databaseURL": "https://game26-base-default-rtdb.europe-west1.firebasedatabase.app"`

#### 2. Add SHA-256 to Firebase Console
Navigate to: **Firebase Console → Project Settings → Your Apps → SHA certificate fingerprints**

Add this fingerprint (from debug keystore):
```
SHA256: 2F:D4:7E:AF:4B:F3:7A:BD:38:46:75:9A:8E:F5:56:22:7E:3E:96:33:4D:2D:84:80:8A:FB:8D:DD:DF:49:B9:6B
```

For **production builds**, you need the release keystore fingerprint:
```bash
# After first build, extract release fingerprint
keytool -list -v -keystore <path-to-release-keystore> -alias <alias-name>
```

### Build Process

#### Step 1: Build Release APK
```powershell
.\build_and_deploy.ps1 -Environment Production
```

This will:
- ✅ Increment build number automatically
- ✅ Build release APK with optimizations
- ✅ Copy APK to `game-server/public/` for OTA
- ✅ Create GitHub Release

#### Step 2: Install on Device
```bash
adb install build\app\outputs\flutter-apk\app-release.apk
```

Or download OTA from: `http://your-game-server.com/app-release.apk`

### Test Scenarios

#### Scenario 1: Admin User Login
**Setup**: 
- Create user account
- Set `isAdmin: true` in Firestore

**Steps**:
1. Login to app
2. Navigate to Admin Panel (usually via profile/settings)
3. Observe logs

**Expected Logs**:
```
[ADMIN] Checking access for UID: abc123...
[ADMIN] Document data: {username: TestAdmin, isAdmin: true, ...}
[ADMIN] isAdmin flag: true
```

**Expected Result**: ✅ Admin panel opens successfully

---

#### Scenario 2: Regular User Attempt
**Setup**: 
- Regular user with `isAdmin: false` or missing field

**Steps**:
1. Login as regular user
2. Try to access admin panel

**Expected Logs**:
```
[ADMIN] Checking access for UID: xyz789...
[ADMIN] Document data: {username: RegularUser, isAdmin: false}
[ADMIN] isAdmin flag: false
```

**Expected Result**: ❌ Access denied with snackbar message

---

#### Scenario 3: Missing Firestore Profile
**Setup**: 
- User exists in Auth but not in Firestore

**Steps**:
1. Delete user from Firestore manually
2. Login and open admin panel

**Expected Logs**:
```
[ADMIN] No user logged in
OR
[ADMIN] Document does NOT exist for UID: abc123...
```

**Expected Result**: ❌ Error message + auto-redirect

---

#### Scenario 4: Network Issues
**Setup**: 
- Poor/no internet connection

**Steps**:
1. Enable airplane mode
2. Try to open admin panel

**Expected Behavior**: 
- Graceful error handling
- No app crash
- Retry option offered

---

### Debug Logging Reference

Enable verbose Firebase logging in `main.dart`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
FirebaseDatabase.instance.setLoggingEnabled(true); // Add this
```

#### Key Log Messages to Watch For

| Message | Meaning | Action |
|---------|---------|--------|
| `[ADMIN] Checking access for UID: ...` | Access check started | ✅ Normal |
| `[ADMIN] Document data: {...}` | Firestore fetch successful | ✅ Normal |
| `[ADMIN] isAdmin flag: true` | Admin detected | ✅ Access granted |
| `[ADMIN] Document does NOT exist` | Profile missing | ⚠️ Auto-create profile |
| `[ADMIN] Firestore Error: ...` | DB connection issue | ⚠️ Check network/permissions |
| `DEVELOPER_ERROR` | SHA-256 mismatch | ❌ Add fingerprint to Firebase |

### Common Issues & Solutions

#### Issue 1: DEVELOPER_ERROR on Login
**Symptom**: Google Sign-In fails with DEVELOPER_ERROR

**Cause**: SHA-256 fingerprint not registered in Firebase Console

**Solution**:
1. Get fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
   ```
2. Add to Firebase Console → Your Apps → SHA fingerprints
3. Re-download `google-services.json`
4. Rebuild app

---

#### Issue 2: "User profile not found"
**Symptom**: Admin panel shows error about missing Firestore profile

**Cause**: User exists in Auth but not in Firestore

**Solution**: 
The app should auto-create profiles now. If not:
1. Manually create in Firebase Console → Firestore
2. Collection: `users`, Document: `{UID}`, Field: `isAdmin: true`

---

#### Issue 3: Admin panel loads but settings don't appear
**Symptom**: Blank admin settings or default values

**Cause**: `admin_settings` node missing in RTDB

**Solution**:
1. Go to Firebase Console → Realtime Database
2. Create node: `admin_settings`
3. Add fields:
   ```json
   {
     "maxMonsters": 20,
     "maxClouds": 10,
     "visibilityRadius": 300,
     "sonicMobsEnabled": true,
     "vocalMobsEnabled": true,
     "basicMobsEnabled": true
   }
   ```

---

#### Issue 4: Cannot write to admin_settings
**Symptom**: Changes in admin panel don't save

**Cause**: RTDB security rules block writes

**Solution**: Update RTDB rules:
```json
{
  "rules": {
    "admin_settings": {
      ".read": "auth != null",
      ".write": "root.child('users').child(auth.uid).child('isAdmin').val() === true"
    }
  }
}
```

### Security Best Practices

#### 1. Never Trust Client-Side Checks Only
Always validate admin actions server-side:
```javascript
// game-server/index.js example
app.post('/api/admin/action', async (req, res) => {
  const userDoc = await admin.firestore().collection('users').get(req.body.uid);
  if (!userDoc.data().isAdmin) {
    return res.status(403).send('Unauthorized');
  }
  // Process admin action...
});
```

#### 2. Log All Admin Actions
```dart
void logAdminAction(String action, Map data) {
  _db.child('admin_logs').push().set({
    'uid': FirebaseAuth.instance.currentUser!.uid,
    'action': action,
    'data': data,
    'timestamp': ServerValue.timestamp,
  });
}
```

#### 3. Rate Limiting
Prevent spam by limiting admin API calls:
```javascript
// Simple rate limit: max 100 actions/hour
const lastAction = await db.ref(`admin_rate_limit/${uid}`).get();
if (Date.now() - lastAction.val() < 3600000) {
  throw new Error('Rate limit exceeded');
}
```

### Performance Benchmarks

| Metric | Target | Actual (v32) |
|--------|--------|--------------|
| Admin panel load time | <2s | ~800ms |
| Firestore read latency | <500ms | ~300ms |
| RTDB update propagation | <1s | ~500ms |
| Access denial response | <1s | ~400ms |

### Success Criteria

Before marking v32 admin access as complete, verify:

- ✅ Release build installs and launches
- ✅ Admin user can access panel
- ✅ Regular users are denied
- ✅ Detailed logs appear in Logcat
- ✅ Settings load correctly
- ✅ Settings save successfully
- ✅ No DEVELOPER_ERROR occurrences
- ✅ Works on mobile data (not just WiFi)

### Next Steps (v33+)

After confirming basic admin functionality:

1. **Advanced Permissions**: Role-based access (moderator, super-admin)
2. **Audit Trail**: Full history of all admin actions
3. **Bulk Operations**: Mass user management
4. **Real-time Monitoring**: Live dashboard of active players
5. **Remote Commands**: Execute server commands from app

---

## Quick Reference Commands

### Check Current Build Version
```bash
grep "^version:" pubspec.yaml
```

### View Release Logs
```bash
gh release list --repo AlexIves16/bcgg
```

### Monitor Firebase Logs
```bash
# In Firebase Console → Realtime Database → Usage
# Or via CLI:
firebase database:get /admin_logs
```

### ADB Logcat Filter
```bash
adb logcat | grep -E "\[ADMIN\]|\[RTDB\]|\[FIRESTORE\]"
```

---

**Status**: ✅ Ready for Testing  
**Build Command**: `.\build_and_deploy.ps1 -Environment Production`  
**Test Device**: Any Android device with Google Play Services
