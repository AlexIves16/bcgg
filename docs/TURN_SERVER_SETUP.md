# TURN Server Setup Guide for Digital Ether

## Quick Start (Testing)
The app now includes **free public TURN servers** from OpenRelay project for immediate testing:
- ✅ Pre-configured in `lib/network/webrtc_manager.dart`
- ✅ Works on mobile networks (4G/5G)
- ⚠️ Limited bandwidth - for development/testing only

## Production Setup (Recommended)

### Option 1: Metered.ca (Easiest - Free Tier)

1. **Register for Free Account**
   - Go to https://www.metered.ca/tools/
   - Sign up with email
   - Get your credentials instantly

2. **Get Your Credentials**
   ```
   Username: your-username
   Password: your-password
   Server: ca.turn.metered.ca (or eu.turn.metered.ca)
   ```

3. **Update webrtc_manager.dart**
   
   Find the `_turnServers` list and uncomment Metered section:
   
   ```dart
   final List<Map<String, dynamic>> _turnServers = [
     {
       'urls': ['turn:ca.turn.metered.ca:443', 'turns:ca.turn.metered.ca:443'],
       'username': 'your-username',
       'credential': 'your-password'
     },
     // Remove or comment out openrelay servers below
   ];
   ```

4. **Rebuild App**
   ```powershell
   .\build_and_deploy.ps1 -Environment Production
   ```

### Option 2: Self-Hosted coturn (Advanced)

1. **Install on Ubuntu/Debian**
   ```bash
   sudo apt-get install coturn
   ```

2. **Configure /etc/turnserver.conf**
   ```
   listening-port=3478
   tls-listening-port=5349
   min-port=49152
   max-port=65535
   realm=your-domain.com
   server-name=turn.your-domain.com
   user=username:password
   cert=/etc/ssl/certs/turn_fullchain.pem
   pkey=/etc/ssl/private/turn_privkey.pem
   ```

3. **Start Service**
   ```bash
   sudo systemctl start coturn
   sudo systemctl enable coturn
   ```

4. **Add to App**
   ```dart
   {
     'urls': ['turn:turn.your-domain.com:3478', 'turns:turn.your-domain.com:5349'],
     'username': 'username',
     'credential': 'password'
   }
   ```

## Testing P2P Connection

### Test Scenarios:
1. **WiFi to WiFi** - Should work with STUN only
2. **WiFi to Mobile Data** - Requires TURN
3. **Mobile Data to Mobile Data** - Requires TURN

### Debug Logs:
Enable verbose WebRTC logging:
```dart
// In webrtc_manager.dart init method
RTCConfiguration.enableRtcEventLog = true;
```

Watch for these logs:
- `[WebRTC] ICE connection state changed` → Should reach "connected" or "completed"
- `[WebRTC] Added ICE candidate` → Shows relay candidates if TURN is working

### Success Indicators:
✅ Connection established within 5-10 seconds  
✅ No timeout errors  
✅ Chat messages flow bidirectionally  
✅ Distance updates correctly  

### Failure Indicators:
❌ "Connection failed" after 30+ seconds  
❌ Only host/srflx candidates, no relay candidates  
❌ One-way communication (only one peer receives data)  

## Troubleshooting

### Issue: DEVELOPER_ERROR with Google Sign-In
**Solution**: Add SHA-256 fingerprint to Firebase Console
```
SHA256: 2F:D4:7E:AF:4B:F3:7A:BD:38:46:75:9A:8E:F5:56:22:7E:3E:96:33:4D:2D:84:80:8A:FB:8D:DD:DF:49:B9:6B
```
See Firebase Console → Project Settings → Your Apps → SHA certificate fingerprints

### Issue: TURN not working on mobile
**Check**:
1. Firewall allows UDP/TCP ports 3478, 5349, 49152-65535
2. TURN server has public IP (not behind NAT)
3. Credentials are correct (case-sensitive!)
4. Using `turns:` (TLS) for stricter networks

### Issue: High latency through TURN
**Solutions**:
- Choose geographically closer TURN server
- Use TCP instead of UDP (`?transport=tcp`)
- Consider paid tier with dedicated servers (Metered: $9/month)

## Cost Estimates

| Provider | Free Tier | Paid Plans | Best For |
|----------|-----------|------------|----------|
| Metered.ca | 1TB/month | $9/mo for 2TB | Most projects |
| Twilio | 10GB/month trial | $0.015/GB after | Short trials |
| Self-hosted | ~$5/month VPS | Unlimited | Full control |

## Security Notes

⚠️ **Never commit production credentials to Git!**

Use environment variables or secure config:
```dart
final String turnUsername = const String.fromEnvironment('TURN_USERNAME');
final String turnPassword = const String.fromEnvironment('TURN_PASSWORD');
```

Build with:
```bash
flutter build apk --dart-define=TURN_USERNAME=xxx --dart-define=TURN_PASSWORD=yyy
```

---

**Current Status (v32)**: ✅ Configured with free OpenRelay servers for testing  
**Next Step**: Register at Metered.ca for production credentials
