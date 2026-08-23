# Fuel & Bills — Native Android App

Two tabs, one app: **Fuel** (log fill-ups, auto-calculated distance and
km/L) and **Bills** (credit card / utility bills with a real Android
notification the day before each is due — fires even with the app closed).

## Building this with no PC — everything from your phone

Since there's no computer involved, the trick is: your phone pushes the
code to GitHub, and GitHub's free cloud servers do the actual compiling.
You then download the finished APK back onto your phone. Nothing gets
installed on your phone except the final app.

### Step 1 — Create a free GitHub account

Go to **github.com** in your phone's browser and sign up, if you don't
already have an account.

### Step 2 — Create a new repository

- Tap the **+** icon → **New repository**
- Name it `fuel-bills-app`
- Set it to **Public** (required for the free build minutes)
- Leave everything else default → **Create repository**

### Step 3 — Get this project's files into that repository

You have two ways to do this from a phone. Pick whichever feels easier.

**Option A — Termux (recommended, faster for many files)**

1. Install **Termux** from F-Droid (search "F-Droid Termux" — avoid the
   old Play Store version, it's unmaintained).
2. Open Termux and run:
   ```
   pkg update && pkg install git unzip -y
   ```
3. Move the `fuel_bills_app.zip` file (the one you downloaded from this
   chat) into Termux's storage. Easiest way:
   ```
   termux-setup-storage
   ```
   Allow the permission prompt, then copy the zip:
   ```
   cp /sdcard/Download/fuel_bills_app.zip ~/
   cd ~
   unzip fuel_bills_app.zip
   cd fuel_bills_app
   ```
4. On GitHub (in your browser): go to **Settings → Developer settings →
   Personal access tokens → Fine-grained tokens → Generate new token**.
   Give it Read/Write access to your new repo, then copy the token
   somewhere safe — you'll paste it once as your Git password.
5. Back in Termux:
   ```
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/fuel-bills-app.git
   git push -u origin main
   ```
   When prompted for a username/password, use your GitHub username and
   paste the **token** as the password.

**Option B — GitHub's website only (no app installs, more manual)**

1. In your new repo, tap **Add file → Create new file**.
2. In the filename box, type the *full path* — e.g. `pubspec.yaml` —
   then paste that file's contents below it, and commit.
3. Repeat for every file in the zip (you can view each file's contents
   on your phone by extracting the zip with your file manager's
   built-in unzip, or any free "zip viewer" app, then opening each file
   as text). For nested files, typing something like
   `lib/screens/fuel_tab.dart` as the filename automatically creates
   the `lib/screens/` folders for you.
4. This is more tapping but needs nothing installed — just patience for
   ~18 files.

Either way, make sure `.github/workflows/build_apk.yml` ends up at
exactly that path — that file is what tells GitHub to build the APK.

### Step 4 — Let GitHub build the APK

- On GitHub, open your repo → the **Actions** tab
- You should see a run called "Build Android APK" already in progress
  (it starts automatically on push). If not, click **Build Android
  APK** on the left → **Run workflow**.
- Wait 3–6 minutes. A green checkmark means it succeeded.

### Step 5 — Download and install the APK

- Click into the finished run → scroll to **Artifacts** →
  download **fuel-bills-app-apk** (this downloads as a `.zip` containing
  the `.apk` — extract it with your file manager).
- Open the extracted `app-release.apk` file on your phone.
- Android will likely block it the first time — go to **Settings →
  allow installs from this source** when prompted, then try opening
  the file again.
- Tap **Install**.

That's it — the app is now on your phone, fully working, including
real background bill reminders.

## Making changes later

Any time you want to tweak the code, edit the files directly on
GitHub's website (tap a file → pencil/edit icon → commit), or repeat
the Termux `git add / commit / push` steps. Every push automatically
triggers a fresh build in Actions — just repeat Step 5 to grab the new
APK.

## One behavior worth knowing

A bill's due day repeats every month, but "one day before" lands on a
different date each cycle — so each scheduled reminder only covers the
*next* occurrence. The app reschedules automatically every time you
open the Bills tab, so as long as you open the app at least once a
month, you'll never miss a cycle.

## Project structure

```
lib/
  main.dart                  entry point, notification init
  theme/app_theme.dart       shared colors, typography, widget theme
  models/fuel_entry.dart     fuel log entry model
  models/bill.dart           bill model + due-date math
  db/database_helper.dart    sqlite storage for both tables
  services/notification_service.dart   schedules the OS reminders
  screens/home_screen.dart   bottom-nav shell
  screens/fuel_tab.dart      fuel log UI
  screens/bills_tab.dart     bills UI
.github/workflows/build_apk.yml   cloud build config (builds the APK for you)
```
