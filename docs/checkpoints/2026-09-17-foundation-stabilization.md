# YIYO Foundation Stabilization

**Date:** 17 September 2026
**Merge commit:** `9d8f15e`
**Flutter stabilization commit:** `4461910`
**Backend stabilization commit:** `0dac438`
**Status:** Verified working on physical Android device

## Purpose

This checkpoint establishes a stable technical baseline for YIYO before continuing MVP feature development.

The work focused on stabilizing the existing Flutter, FastAPI, Firebase, Google Maps, Google Places and Firestore foundation rather than adding new product features.

## Verified Working

The following functionality was manually verified on a physical Android device:

* Android application builds and installs successfully.
* Firebase initializes successfully.
* Firebase Authentication login and session persistence work.
* User location is obtained successfully.
* Google Maps base map renders correctly.
* Venue markers render correctly.
* Flutter communicates successfully with the FastAPI backend.
* `/venues` returns venue data successfully.
* Venue data is parsed correctly by Flutter.
* Venue detail screens load.
* Vibe/community reports can be submitted.
* Existing YIYO badge/report behavior remains functional.
* Firestore venue caching works.

## Android / Flutter Stabilization

The Android NDK was pinned to:

`27.0.12077973`

This resolves the mismatch between the previously selected NDK 26.x version and the NDK 27 requirement of Firebase, Google Maps, geolocator and related Flutter plugins.

Flutter analyzer issues were cleaned up without changing intended application behavior.

Changes included:

* Removing `return` statements from `finally` blocks.
* Correctly guarding `BuildContext` usage across asynchronous gaps.
* Updating deprecated Geolocator location configuration.
* Replacing deprecated `Color.withOpacity` usage.
* Removing the obsolete generated Flutter counter test.

The Google Maps blank-map issue was traced to local Android Maps SDK configuration rather than YIYO map code.

The Android Maps API key in the user-level Gradle configuration had accidentally been wrapped in quotation marks, causing Google Maps SDK authorization failures:

`StatusCode=INVALID_ARGUMENT`

After correcting the local Gradle property, Google Maps rendered successfully.

The Maps key remains outside the repository.

## Flutter Tests

The obsolete Flutter starter counter test was replaced with tests relevant to YIYO.

Current tests cover:

* Venue API JSON parsing and defaults.
* Vibe report request serialization.

Verification:

`flutter analyze` → **No issues found**

`flutter test` → **3 tests passed**

## Backend Dependency Baseline

Backend dependencies are now recorded in:

`backend/requirements.txt`

Development/test dependencies are recorded separately in:

`backend/requirements-dev.txt`

The verified environment at this checkpoint is:

* Python 3.13.3
* FastAPI 0.115.12
* Uvicorn 0.34.3
* Firebase Admin 7.3.0
* google-cloud-firestore 2.26.0
* requests 2.32.3
* python-dotenv 1.1.0
* Pydantic 2.11.5
* pytest 8.3.5

This makes the backend environment reproducible without unnecessarily upgrading working dependencies.

## Backend Logic Refactor

Pure application logic was extracted from `main.py` into:

`backend/app/services/yiyo_logic.py`

This allows important YIYO behavior to be tested without initializing Firebase or contacting external services.

Covered logic includes:

* Geographic cache/location keys.
* Contributor levels.
* YIYO badge aggregation.
* Cache freshness decisions.

Google Places service tests cover:

* Haversine distance calculations.
* Google Place normalization.
* Irrelevant-place filtering.
* Nightlife relevance behavior.
* Venue scoring.
* Search score boosts.

Verification:

`python -m pytest -v` → **16 tests passed**

These tests make no Google Places API calls and therefore do not incur Google API costs.

## Privacy Hardening

Public venue report responses previously had the ability to expose internal account information stored with reports, including:

* Firebase UID
* User email
* User display name

`GET /reports/{venue_id}` now removes these identifiers before returning reports publicly.

The internal Firestore records still retain the information required for account ownership, moderation and future abuse-prevention functionality.

## Google Places / Venue Cache

The previous venue caching system could effectively cache venue discovery results indefinitely.

A dedicated area-cache system was added using Firestore.

Each discovery area now records:

* Location key.
* Venue IDs belonging to the cached discovery result.
* Refresh timestamp.

Google-derived venue discovery uses a **7-day cache TTL**.

Flow:

`Flutter → FastAPI → valid Firestore area cache → venue data`

Google Places is only used when the area cache is missing or stale.

After refresh:

`Google Places → Firestore venues + area cache → Flutter`

An empty Google result is also cached so repeated requests do not repeatedly generate unnecessary Google Places API calls.

The cache distinguishes between:

* `None` — no valid cache; Google refresh permitted.
* `[]` — valid cache containing no venues; Google should not immediately be called again.

This provides explicit control over Google Places API usage while allowing YIYO community-generated vibe data to remain dynamic.

The cache behavior was manually verified:

First uncached request may use:

`source = google_places`

Subsequent requests return:

`source = firestore_cache`

## Security Status

The following sensitive files were confirmed ignored by Git:

* Backend `.env`
* Flutter `.env`
* `google-services.json`
* Firebase private credential files
* Keystore files

A repository check confirmed that these files are not currently tracked.

The Android Google Maps key is stored outside the repository in the user's Gradle configuration.

Backend secrets remain in backend environment configuration and are not bundled into the Flutter application.

## Current Technical Baseline

At this checkpoint, the core flow is:

`Android / Flutter`
→ `Firebase Authentication`
→ `Location`
→ `Google Maps`
→ `FastAPI`
→ `Firestore venue cache`
→ `Google Places when cache refresh is required`
→ `Venue discovery`
→ `Venue detail`
→ `Community contribution`
→ `YIYO aggregation`

This foundation has been verified end-to-end.

## Next Development Priority

The project should now move from foundation stabilization into the core YIYO MVP.

The next development focus should be the venue system and venue experience:

1. Review and formalize the YIYO-owned venue model.
2. Clearly separate Google-derived venue data from YIYO/community-owned data.
3. Improve the venue detail experience around current/recent community intelligence.
4. Strengthen the contribution UX and validation model.
5. Add moderation and abuse safeguards before expanding safety functionality.
6. Continue measuring Google Places and Firestore usage before scaling venue coverage.

Events and rewards remain later-stage features and should not displace the venue/discovery/contribution MVP.

## Development Principle

Continue following the established rule:

**Inspect first → identify the root cause → make the smallest practical change → test → verify on-device → commit.**

Working systems should not be rewritten unnecessarily.
