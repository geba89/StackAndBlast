# Xcode Cloud → TestFlight setup

One-time setup (~10 minutes) so every push to a branch builds the app in Apple's
cloud and delivers it to TestFlight. Apple handles code signing and build numbers.
Xcode Cloud includes 25 free compute hours per month with the Apple Developer Program.

Everything the repository needs is already in place:

| File | Why Xcode Cloud needs it |
|------|--------------------------|
| `ci_scripts/ci_post_clone.sh` | Writes `GoogleService-Info.plist` (gitignored) from a secret variable before the build |
| `StackAndBlast.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Xcode Cloud never resolves Swift packages itself — without this lockfile every build fails |
| `StackAndBlast.xcodeproj/xcshareddata/xcschemes/StackAndBlast.xcscheme` | Shared scheme (Xcode Cloud only sees shared schemes) |
| `Info.plist` → `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` | Lets Xcode Cloud set a fresh build number for every upload |

## 1. Prepare the Firebase secret (on your Mac)

In Terminal, in the folder that holds your real `GoogleService-Info.plist`:

```sh
base64 -i GoogleService-Info.plist | pbcopy
```

The encoded file is now on your clipboard — you'll paste it in step 3.

## 2. Commit your signing team (once)

Xcode Cloud builds from GitHub, not from your Mac, so the project in the repository
must name your team. The committed project currently has no `DEVELOPMENT_TEAM`.

1. Open `StackAndBlast.xcodeproj` in Xcode (signed in with your Apple ID under
   **Xcode → Settings → Accounts**).
2. Select the **StackAndBlast** target → **Signing & Capabilities** → tick
   **Automatically manage signing** and choose your **Team**.
3. Commit and push the resulting change to `project.pbxproj`. To keep it when you
   regenerate the project with XcodeGen, also add `DEVELOPMENT_TEAM: <your team ID>`
   under `settings: base:` of the target in `project.yml`.

## 3. Create the workflow in Xcode

1. **Product → Xcode Cloud → Create Workflow…**
2. Pick the **Stack & Blast** app and click **Next**, then **Edit Workflow**.

## 4. Configure it

- **General** — Name: `TestFlight`.
- **Environment**
  - Xcode version: *Latest Release* · macOS: *Latest Release*
  - **Environment Variables → +**: name `GOOGLE_SERVICE_INFO_PLIST_BASE64`,
    value: paste from step 1, tick **Secret**.
- **Start Conditions** — *Branch Changes*: choose the branch to build
  (e.g. `claude/gracious-euler-xe2ohk` to test this work now, `main` later).
- **Actions** — *Archive – iOS*, Deployment Preparation: **TestFlight (Internal Testing Only)**.
- **Post-Actions** — **+ → TestFlight Internal Testing**, and pick (or create) a
  tester group containing your Apple ID.

Click **Save**. Xcode then asks you to **grant access to the GitHub repository**
(a browser window opens to install/authorize the Xcode Cloud GitHub app) — allow it.

## 5. Build

Click **Start Build** (or push a commit to the chosen branch). After roughly
15–25 minutes the build shows up in the **TestFlight** app on your iPhone.
Build progress and logs are in Xcode's **Report navigator (⌘9) → Cloud**, or in
App Store Connect → your app → **Xcode Cloud**.

## Good to know

- **Version**: the project is at **1.1.0**. If an uploaded version was already
  approved on the App Store, TestFlight needs a higher one — change
  `MARKETING_VERSION` in `project.yml` / the project's build settings.
- **Updating packages** (Firebase, AdMob): after *File → Packages → Update to
  Latest Package Versions*, commit the changed `Package.resolved`, or Xcode Cloud
  keeps using the old versions. (The GitHub CI build fails if it's stale.)
- **External testers** (people outside your team) additionally need a short
  Beta App Review by Apple before the build reaches them.
- A build that fails in `ci_post_clone.sh` with
  *"GOOGLE_SERVICE_INFO_PLIST_BASE64 environment variable is not set"* means step 4's
  secret is missing or misspelled.

## Also running: GitHub compile check

Independently of Xcode Cloud, `.github/workflows/ios-ci.yml` runs on every push:
the engine unit tests (`swift test`) and an unsigned simulator build with Xcode.
It needs no Apple account and is free for this public repository.

`.github/workflows/ui-screenshots.yml` additionally takes screenshots in the iPhone SE,
iPhone Pro and iPad simulators: the menu, the daily missions, the tutorial, a new Classic
game, a crowded board with the blast preview and danger warning, and the game over screen
(the last few with staged content, see `ScreenshotScenario` in `ContentView.swift` —
debug builds only). Each run keeps them as a downloadable artifact ("screenshots", on the
run's page under Actions). Put `[screenshots]` in a commit message, or start the workflow
by hand, and it also commits small JPEG copies to `Docs/screenshots/` on that branch.
If the app crashes in the simulator, the job log shows the crash reason.
