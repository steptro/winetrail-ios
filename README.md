# WineTrail

A personal wine diary iOS app built with SwiftUI. Log your tastings, track your wines, and visualize your wine journey on a map.

## Features

- **Log Tastings** — Record wine tastings with rating (1-10), notes, food pairing, occasion, price, vintage, date, and location
- **Wine Search** — Search wines across local database and external providers
- **Create Wines** — Add your own wines when not found in search
- **Timeline** — Chronological diary of all your tastings with infinite scroll
- **Wines Collection** — Browse your wines with stats (times drunk, average rating), filterable by color and sortable
- **Map** — Visualize where you've tasted wines with location pins
- **Stats Dashboard** — Personal statistics including color split, top regions, average rating, and weekly activity chart
- **Photo Attachments** — Attach up to 5 photos per tasting
- **GPS Tagging** — Tag tastings with your current location

## Tech Stack

- **UI**: SwiftUI (iOS 18+)
- **Architecture**: MVVM with `@Observable` (Observation framework)
- **Networking**: Swift OpenAPI Generator (client generated from OpenAPI spec at build time)
- **Auth**: Firebase Authentication (Apple Sign-In, Google Sign-In, Email)
- **Push Notifications**: Firebase Cloud Messaging
- **Maps**: MapKit
- **Charts**: Swift Charts

## Project Structure

```
WineTrail/
├── App/                    # App entry point, AppState, MainTabView, RootView
├── DesignSystem/           # Theme, colors, reusable components (TastingCard, RatingView, etc.)
├── Features/
│   ├── Auth/               # Authentication views and view model
│   ├── LogTasting/         # Log new tasting flow (search, form, photo picker)
│   ├── Map/                # Map visualization
│   ├── Onboarding/         # First-time user onboarding
│   ├── Profile/            # User profile management
│   ├── Stats/              # Statistics dashboard with charts
│   ├── Timeline/           # Tasting timeline with detail/edit views
│   └── Wines/              # Wine collection list
├── Generated/              # Type aliases, helpers, and extensions for generated OpenAPI types
├── Models/                 # App-level models (PagedResult, WineSort, WineColor, errors)
├── Resources/              # OpenAPI spec, generator config, assets
├── Services/               # API client, auth, location, photo, and domain services
└── Supporting/             # Info.plist, entitlements, GoogleService-Info
```

## Setup

### Prerequisites

- Xcode 16+ with iOS 18 SDK
- A Firebase project with Authentication enabled
- The backend API running (defaults to `http://localhost:8091`)

### Configuration

1. Clone the repository
2. Place your `GoogleService-Info.plist` in `WineTrail/Supporting/`
3. Open `WineTrail.xcodeproj` in Xcode
4. Wait for Swift Package Manager to resolve dependencies
5. Build and run on a simulator or device

### Dependencies (via SPM)

- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) — Auth, Messaging
- [Google Sign-In iOS](https://github.com/google/GoogleSignIn-iOS) — Google authentication
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) — API client code generation
- [Swift OpenAPI URLSession](https://github.com/apple/swift-openapi-urlsession) — Transport layer

## API

The app consumes a REST API defined in `WineTrail/Resources/openapi.json`. The Swift client is generated at build time by the Swift OpenAPI Generator build plugin. Do not edit the generated types directly.

## License

Private project.
