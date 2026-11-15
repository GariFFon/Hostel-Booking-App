# Hostel Booking App (Flutter)

> **Live website: https://hostel-booking-web.onrender.com**
> API used by the app: https://hostel-booking-api-u2po.onrender.com/api/v1
>
> The backend runs on Render's free tier, so the first request after a quiet period can take 30 to 60 seconds. Debug builds talk to this live API by default.

The mobile client (Android and iOS) for the Hostel Booking platform: find a hostel, PG or hotel, book a night, or rent a bed long-term and manage your stay. Owners can run their property from the same app. It consumes the REST API of the sibling repo [`Hostel-Booking`](../Hostel-Booking) (OpenAPI contract at `/api/v1/openapi.json`).

## Contents

1. [Features](#features)
2. [Tech stack](#tech-stack)
3. [Getting started](#getting-started)
4. [Choosing the backend](#choosing-the-backend)
5. [Demo accounts](#demo-accounts)
6. [Running on a real phone](#running-on-a-real-phone)
7. [Push notifications](#push-notifications)
8. [Project structure](#project-structure)
9. [Testing](#testing)
10. [Conventions](#conventions)
11. [Not built yet](#not-built-yet)
12. [Troubleshooting](#troubleshooting)

## Features

| Area | What you can do |
|---|---|
| **Browse** | Explore as a list or map with filters and sort; property page with gallery, rooms, dates, reviews and a map; all reviews |
| **Nightly booking** | Checkout (guests, contact, coupon, itemised GST price), demo payment sheet, booking page (pay, cancel with refund preview, review, directions) |
| **Long-term stay (tenant)** | Ask for a bed, accept or decline an owner's invitation, **My stay**, monthly **rent** (pay online, see PDF invoices and receipts), **complaints** with photos, give move-out notice, review and accept or dispute the **deposit settlement** |
| **You** | Trips, Saved, Account (details, password, notification settings, your reviews), notifications inbox, phone push |
| **Hosting (owner)** | Dashboard and earnings; bookings (accept, decline, check in, complete, no-show, cancel); listings status; reviews (reply, report); **tenants** (approve or decline requests, add a tenant by email, record deposit and rent, move in, end a stay); **deposit deductions editor** with evidence photos; complaints; staff; join a team by invite |

The server decides what you can do: screens show only the actions the API returns.

## Tech stack

| Concern | Choice |
|---|---|
| State | Riverpod 3 |
| Routing | go_router |
| HTTP | dio |
| Models | json_serializable (generated `*.g.dart`) |
| Sign-in | Email and password, Google Sign-In |
| Images | image_picker (complaint and deposit evidence photos) |
| Push | firebase_core, firebase_messaging (Android) |
| Links | url_launcher (PDF documents, directions) |

## Getting started

Requirements: Flutter (stable), Android Studio or Xcode, a device or emulator.

```bash
cd Hostel-Booking-App
flutter pub get
flutter run                  # debug build: uses the live Render API by default
```

After changing a model, regenerate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

In VS Code open the **parent** folder (it holds `.vscode/launch.json`). "Run | Debug" above `main()` ignores launch configurations; choose a configuration in the Run and Debug dropdown and press **Ctrl+F5** (Run Without Debugging) instead.

## Choosing the backend

The base URL is set in [`lib/core/config/env.dart`](lib/core/config/env.dart).

| Goal | Command |
|---|---|
| Live (Render), the default in debug | `flutter run` |
| Your local backend on an emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` (Android emulator) |
| Local backend on iOS simulator | `flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1` |
| Local backend on a real phone | `flutter run --dart-define=API_BASE_URL=http://<your-mac-lan-ip>:4000/api/v1` |
| Release build against a custom API | `flutter run --release --dart-define=API_BASE_URL=https://api.example.com/api/v1` |

The app prints `Base URL ...` at start-up; check it to confirm where it points.

To run against a local backend, start it first (see the backend README): `make services`, then `pnpm dev:all` in `Hostel-Booking/backend`, with a seeded database.

## Demo accounts

Password for all: `Password@123` (local and demo data only).

| Role | Email |
|---|---|
| Guest / tenant | `guest1@hostel.dev` to `guest5@hostel.dev` |
| Owner | `owner1@hostel.dev` to `owner3@hostel.dev` (owner3 runs the PG) |
| Admin | `admin@hostel.dev` (website only) |

These exist on a locally seeded database. The live (production) database is not seeded with demo users.

## Running on a real phone

1. Put the phone and the Mac on the **same Wi-Fi**, enable developer mode and USB debugging.
2. If you use a local backend, pass `--dart-define=API_BASE_URL=http://<lan-ip>:4000/api/v1`. A phone cannot reach `localhost`.
3. Debug builds reached a LAN `http` address in testing; release builds should use `https`.
4. Quick reachability test: open `http://<lan-ip>:4000/api/v1/health` in the phone's browser.

## Push notifications

The backend sends push through Firebase Cloud Messaging; the app registers its device token after sign-in and removes it on sign-out.

- `android/app/google-services.json` belongs to the Firebase project and holds client identifiers only (the server key is never in this repo).
- Android 13+ asks for notification permission at first sign-in.
- Tapping a notification opens the right screen (for example **My stay**).
- Push is Android-only for now; iOS needs an APNs key in Firebase.
- To test: sign in as a guest, put the app in the background, then trigger an event from the website (for example an owner adding that guest as a tenant).

Per-category switches (bookings, reviews, rent, complaints) live in **Account → Notification settings**.

## Project structure

```
lib/
  main.dart, bootstrap.dart, app.dart     entry points and app shell
  core/
    config/      environment and base URL
    network/     dio client, envelope, ApiException
    router/      routes and guards
    paging/      shared paged-list notifier
    format/      money (paise to ₹), dates
    theme/       design tokens (shared with the website)
  shared/widgets/    buttons, chips, states (empty, error, skeleton), toasts
  features/
    auth/  hostels/  bookings/  wishlist/  reviews/  notifications/
    account/  tenancy/  rent/  complaints/  host/
      domain/ models     data/ repositories     application/ providers     presentation/ screens
test/            unit, widget and accessibility tests with fakes
test_live/       contract test against a running backend
integration_test/, test_driver/   whole-app driver with screenshots
android/, ios/   platform projects
```

Each feature follows the same four layers: **domain → data → application → presentation**. Repositories are interfaces, so tests inject fakes without any network.

## Testing

```bash
flutter analyze
flutter test                                    # unit, widget and accessibility tests (fakes, no network); about 213 tests
flutter test test_live/live_flow_test.dart      # live contract test against a running local backend; cancels what it books
# on a simulator: drives the whole app and writes screenshots to $SHOTS_DIR
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d <simulator-id>
```

## Conventions

- **Money is integer paise** end to end; `money()` formats it (₹, lakh grouping). Stay dates are calendar dates, never UTC instants.
- **The server decides what you can do.** Screens show only the buttons in the object's `actions`.
- **Errors surface at once.** `noAutomaticRetry` turns off Riverpod 3's built-in retry (about 40 s of skeleton before an error); every error state has "Try again" and pull-to-refresh.
- **Lists load fresh.** Screens that can change while the app is open (for example My stay) refetch when opened.
- **Requests are idempotent.** One `Idempotency-Key` per distinct request, reused on retries; `expectedTotalPaise` makes a moved price come back as `PRICE_CHANGED` instead of being charged silently.
- Design tokens are shared with the website ([`../Hostel-Booking/docs/design-tokens.md`](../Hostel-Booking/docs/design-tokens.md)); change the doc first.
- Code style is wide (150 columns). Format only the files you touch, with `dart format -l 150 <files>`; the repository is not formatter-clean, so never format all of `lib` or `test`.

## Not built yet

- Listing create and edit (done on the website).
- iOS push (needs an APNs key) and Google Sign-In on iOS (needs the iOS OAuth client ID).
- Real payment gateway: the app uses the demo gateway today.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| App calls the Render URL when you wanted local | Pass `--dart-define=API_BASE_URL=...`, run with Ctrl+F5 from the Run and Debug dropdown, and check the `Base URL` log line |
| Phone cannot reach the local backend | Same Wi-Fi, use the Mac's LAN IP (not `localhost`), allow the port in the firewall |
| Screen does not show new data | Pull down to refresh; after code changes use a hot **restart** (Shift+R), because hot reload does not apply some changes |
| No push arrives | App in background, notification permission allowed, backend `PUSH_DRIVER=fcm` and the worker running; check the worker log for `push dispatched` or `push send failed` |
| First request is slow | Render free tier is waking up; wait up to a minute |
| `*.g.dart` missing or stale | `dart run build_runner build --delete-conflicting-outputs` |
