# Hostel Booking App (Flutter)

Mobile client for the Hostel Booking platform. Consumes the REST API of the sibling `Hostel-Booking/backend`
(OpenAPI contract at `/api/v1/openapi.json`). Android + iOS. State: Riverpod 3; routing: go_router; HTTP: dio.

## Run

```bash
# backend first (from ../Hostel-Booking): make services && make dev-be && make worker, seeded DB
flutter pub get
flutter run -t lib/main_dev.dart                                   # iOS simulator: localhost:4000
flutter run --flavor dev -t lib/main_dev.dart                      # Android emulator: 10.0.2.2:4000 (Android needs --flavor)
flutter run -t lib/main_dev.dart --dart-define=API_BASE_URL=http://<lan-ip>:4000/api/v1   # a real device
flutter run --flavor prod -t lib/main_prod.dart --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Seed accounts (password `Password@123`): `guest1..5@hostel.dev`, `owner1..3@hostel.dev`, `admin@hostel.dev`.

## What is in it

| Area | Screens |
|---|---|
| Browse | Explore (list + map, filters, sort), property page (gallery, rooms, dates, reviews, map), all reviews |
| Booking | Checkout (guests, contact, coupon, itemised GST price), demo payment sheet, booking page (pay, cancel with refund preview, review, directions) |
| You | Trips, Saved, Account (details, password, notification settings, your reviews), notifications inbox |
| Hosting | Dashboard + earnings, bookings (accept / decline / check in / complete / no-show / cancel), listings status, reviews (reply / report) |

Not built yet: Google Sign-In (needs the OAuth client IDs; the backend verifier is ready), listing create/edit (done on the website).

## Tests

```bash
flutter analyze
flutter test                                   # unit, widget and accessibility-guideline tests (fakes, no network)
flutter test test_live/live_flow_test.dart     # live contract test against a running local backend; cancels what it books
# on a simulator, drives the whole app and writes screenshots to $SHOTS_DIR:
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d <simulator-id>
```

## Conventions worth knowing

- **Money is integer paise** end to end; `money()` formats it (₹, lakh grouping). Stay dates are calendar dates, never UTC instants.
- **The server decides what you can do.** The booking page shows only the buttons in `booking.actions`.
- **Errors surface at once.** `noAutomaticRetry` turns off Riverpod 3's built-in retry (about 40 s of skeleton before an error);
  every error state has its own "Try again" and pull-to-refresh.
- **Booking requests are idempotent.** One `Idempotency-Key` per distinct request, reused on retries; `expectedTotalPaise` makes a
  moved price come back as `PRICE_CHANGED` instead of being charged silently.
- Design tokens are shared with the website (`../Hostel-Booking/docs/design-tokens.md`); change the doc first.
- Code style is wide (150 columns): format with `dart format -l 150`, not the default.
