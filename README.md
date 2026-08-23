# WineTrail

A personal wine diary iOS app built with SwiftUI. Log your tastings, share with friends, and track your wine journey.

## Features

### Journal
- **Log Tastings** — Record wine tastings with rating (1–5), notes, food pairing, occasion, price, vintage, date, photos, and location
- **Timeline** — Instagram-style feed of your tastings with infinite scroll and sorting (date added, tasting date, rating, last updated)
- **Edit & Delete** — Full edit wizard with photo management (add/delete photos)
- **Wine Search** — Search wines across local database and external providers
- **Create Wines** — Add your own wines when not found in search

### Social
- **Friends Feed** — See your friends' tastings with likes and comments
- **Friend Requests** — Send, accept, reject requests with real-time badge notifications
- **Likes & Comments** — Like tastings, view who liked, comment with pagination
- **User Search** — Find friends by username or display name

### Collection & Stats
- **Wines Collection** — Browse your wines with stats (times drunk, average rating), filterable by color and sortable
- **Wine Detail** — Rating trend chart, price history, tasting history
- **Stats Dashboard** — Color split, top regions/countries, average rating, weekly activity chart, price stats

### Other
- **Push Notifications** — Real-time notifications for likes, comments, friend requests with deep link routing
- **Onboarding** — 3-slide carousel with username setup and inline availability validation
- **Profile** — Edit display name, username, view friends count, sign out, delete account (GDPR)
- **Photo Support** — Camera + library picker, up to 5 photos per tasting
- **GPS Tagging** — Tag tastings with your current location
- **Dark/Light Mode** — Full support with wine-themed accent colors

## Tech Stack

- **UI**: SwiftUI (iOS 18+)
- **Architecture**: MV with `@Observable` (Observation framework)
- **Networking**: Swift OpenAPI Generator (client generated from OpenAPI spec at build time)
- **Auth**: Firebase Authentication (Apple Sign-In, Email/Password)
- **Push Notifications**: Firebase Cloud Messaging with silent push for real-time updates
- **Logging**: Datadog (production) + console (debug)
- **Maps**: MapKit
- **Charts**: Swift Charts

## Project Structure

```
WineTrail/
├── App/                    # App entry point, AppState, SocialState, DeepLink, MainTabView
├── DesignSystem/           # Theme, colors, reusable components (TastingCard, RatingView, etc.)
├── Extensions/             # Error+Cancellation helper
├── Features/
│   ├── Auth/               # Authentication views and view model
│   ├── LogTasting/         # Log new tasting flow (search, form, photo picker, camera)
│   ├── Map/                # Map visualization
│   ├── Onboarding/         # First-time user onboarding with username setup
│   ├── Profile/            # User profile management, account deletion
│   ├── Social/             # Social feed, friends, comments, likes, add friend
│   ├── Stats/              # Statistics dashboard with charts
│   ├── Timeline/           # Journal timeline with detail/edit views
│   └── Wines/              # Wine collection list and detail
├── Generated/              # Type aliases, helpers, and extensions for generated OpenAPI types
├── Models/                 # App-level models (PagedResult, Notifications, etc.)
├── Resources/              # OpenAPI spec, generator config, assets
├── Services/               # API client, auth middleware, retry middleware, domain services
└── Supporting/             # Info.plist, entitlements, GoogleService-Info
```

## Setup

### Prerequisites

- Xcode 16+ with iOS 18 SDK
- A Firebase project with Authentication and Cloud Messaging enabled
- The backend API running (defaults to `https://winetrail.stephantromer.dev`)

### Configuration

1. Clone the repository
2. Place your `GoogleService-Info.plist` in `WineTrail/Supporting/`
3. Create `WineTrail/Supporting/Secrets.xcconfig` with:
   ```
   DATADOG_CLIENT_TOKEN = your_datadog_token
   ```
4. Open `WineTrail.xcodeproj` in Xcode
5. Wait for Swift Package Manager to resolve dependencies
6. Build and run on a simulator or device

### Dependencies (via SPM)

- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) — Auth, Messaging
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) — API client code generation
- [Swift OpenAPI URLSession](https://github.com/apple/swift-openapi-urlsession) — Transport layer
- [Datadog iOS SDK](https://github.com/DataDog/dd-sdk-ios) — Logging

## API

The app consumes a REST API defined in `WineTrail/Resources/openapi.json`. The Swift client is generated at build time by the Swift OpenAPI Generator build plugin. Never edit the spec manually — always fetch from the server:

```bash
curl -s https://winetrail.stephantromer.dev/v3/api-docs -o WineTrail/Resources/openapi.json
```

## Architecture Notes

- **Pull-to-refresh** uses `await Task { }.value` pattern to prevent SwiftUI structured concurrency cancellation
- **Retry middleware** retries GET requests up to 2 times with exponential backoff on transient failures
- **Optimistic updates** on likes with rollback on API failure
- **SocialState** is a shared observable for pending friend request count, synced via silent push + NotificationCenter
- **Deep linking** from push notifications routes to tasting detail or friends screen

## License

Private project.
