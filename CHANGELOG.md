# Changelog

All notable changes to WineTrail. Versions follow the app's marketing version
(`MARKETING_VERSION`), and dates are when that version was set in the project.


## [1.3.1] - 2026-09-28

- Tapping the weekly stats notification now opens your stats screen instead of doing nothing

## [1.3.0] - 2026-09-27

- Edit and delete your own post from its detail page opened via your Profile
- The tasting, location, and pairing cards are back on the post detail page (Social and Profile)
- Wine detail history now shows the wine name and each entry is tappable to open the tasting
- Identify a wine from a photo: scan a label with the camera or pick an existing photo when adding a wine, and matching wines come back to choose from (falls back to on-device reading when offline)
- Reorder photos on a tasting by dragging them, when adding or editing
- Profile photos: set, change, or remove your own from your Profile, and see other people's photos on their profile, in the feed, on comments, likes, friends, and search
- Tap the Friends count on someone's profile to see their friends, and open any of them to browse friends of friends
- Photos are shown larger on the feed, post detail, and wine detail screens

## [1.2.0] - 2026-09-26

- Rate wines by dragging across the stars, not just tapping — linked to the bottle-fill slider
- Top Wines on the Stats screen are now tappable and open the wine's detail page
- Tasting date: set it when adding or editing a tasting, shown on the tasting detail
- Location on a tasting is now saved with a place name (reverse-geocoded when you use GPS without typing one), shows for tastings that only have coordinates, and tapping it opens the map at that spot
- Pinch to zoom photos on the tasting, wine, and social detail screens and in the social feed
- Your Profile now shows your wines as full cards (photo, rating, notes) with likes and comments, matching the social feed

## [1.1.0] - 2026-09-24

- AI Sommelier: chat with a wine assistant for pairings, grape and region questions, and tasting or storage advice, with replies streamed in and rendered as Markdown
- Sommelier conversations are saved: start a new chat or reopen and resume a past conversation from the navbar
- WineTrail Pro subscription via RevenueCat, with a paywall for non-subscribers and the Sommelier gated to Pro
- Reworked the tab bar to four tabs: Social, Wines, AI Sommelier, Profile
- New Profile screen showing your stats and tastings, with a gear icon for Settings (the Journal tab was removed and its tastings now live on Profile)
- The Discover tab is now the AI Sommelier; wine search lives on the Wines tab
- Sommelier chat opens scrolled to the newest message, offers a Try Again on a failed reply, and recovers on its own if a reply stalls

## [1.0.0] - 2026-09-22

First public release.

- Reworked the tab bar: Social (now the default tab), Journal, Wines, Discover, Settings
- New Discover tab with AI-powered wine search
- Share a wine with anyone via the system share sheet, with universal links that open the wine in the app (even wines that aren't in your cellar yet)
- Stats screen moved to a page off the Wines tab and gained a Top Wines section
- Friends and Blocked Users moved into the Social tab
- Combined sort and filter into one menu on the Journal screen, with colored dots per wine type
- Wine search now shows the filling wine-glass loader
- App version and build shown at the bottom of Settings
- Combined Sign Out and Delete Account under a Danger section

## [0.3.0] - 2026-09-19

- Switched wine search and journal creation to the v2 API
- Added user-generated-content moderation and an EULA acceptance gate

## [0.2.0] - 2026-09-12

- On-device wine label scanner
- Tag friends on tastings and share tastings
- Comment likes and comment counts
- Add-wine wizard improvements: cancel, location, bottle details
- Clearer error states across Timeline, Wines, Map, and Stats
- Moved to the winetrail-app.com domain
- Xcode Cloud CI enabled

## [0.1.0] - 2026-08-22

- Wine journal: log tastings, rate wines, keep a cellar
- Social features: user profiles, friends, feed, likes, comments, deep linking, push notifications
- Map view, stats, and per-friend wine notifications
- Legal section (Privacy Policy, Terms of Service) and splash screen
