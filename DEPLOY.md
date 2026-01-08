# Deploy midIDEA to Your iPhone (Without a Mac)

## Option 1: Codemagic (Recommended - Easiest)

Codemagic offers free cloud builds for iOS apps and can deploy directly to TestFlight.

### Setup Steps:

1. **Create Codemagic Account**
   - Go to [codemagic.io](https://codemagic.io)
   - Sign up with GitHub

2. **Connect Your Repository**
   - Click "Add application"
   - Select this GitHub repository
   - Choose "iOS App" as the project type

3. **Apple Developer Setup**
   - You need an Apple Developer account ($99/year)
   - In Codemagic, go to Teams → Integrations → App Store Connect
   - Add your App Store Connect API key

4. **Configure Code Signing**
   - Codemagic can auto-manage signing
   - Or upload your certificates manually

5. **Update Bundle ID**
   - Edit `midIDEA/Info.plist`
   - Change `com.mididea.app` to your unique bundle ID

6. **Trigger Build**
   - Push to `main` branch
   - Codemagic builds and uploads to TestFlight
   - Install via TestFlight app on your iPhone

### Free Tier Limits:
- 500 build minutes/month
- Enough for ~15-20 builds

---

## Option 2: GitHub Actions + Self-Hosted Mac

If you have access to a Mac (friend's, library, etc.) for initial setup:

1. Set up a self-hosted GitHub Actions runner on the Mac
2. Configure code signing certificates
3. Push code → builds automatically

---

## Option 3: Rented Cloud Mac

Services that offer cloud Macs:

- **MacStadium** - $79/month for dedicated Mac mini
- **AWS EC2 Mac** - Pay per hour (~$1.50/hour)
- **MacinCloud** - $20/month for build server access

---

## Quick Start with Codemagic

1. Fork/push this repo to GitHub
2. Sign up at codemagic.io
3. Connect the repo
4. Add App Store Connect API key
5. Click "Start build"
6. Wait ~10-15 minutes
7. Get TestFlight notification on iPhone
8. Install and run!

---

## Required: Apple Developer Account

To install on a physical iPhone, you need:
- Apple Developer Program membership ($99/year)
- OR: Find someone with Xcode to build it for you (free, device-specific)

---

## Bundle ID

Before building, change the bundle identifier to something unique:

1. Open `midIDEA.xcodeproj/project.pbxproj`
2. Find `PRODUCT_BUNDLE_IDENTIFIER`
3. Change `com.mididea.app` to `com.yourname.mididea`

Or in Codemagic's environment variables.

---

## TestFlight Installation

Once Codemagic successfully builds and uploads:

1. You'll get an email from Apple
2. Open TestFlight app on iPhone
3. Accept the test invitation
4. Install midIDEA
5. Start recording!

---

## Troubleshooting

**Build fails with signing error:**
- Check App Store Connect API key is correct
- Ensure bundle ID is registered in App Store Connect

**Build fails with Swift error:**
- Make sure Xcode version is set to "latest" in codemagic.yaml

**Can't find app in TestFlight:**
- Check spam folder for Apple email
- Wait 10-15 minutes for processing
