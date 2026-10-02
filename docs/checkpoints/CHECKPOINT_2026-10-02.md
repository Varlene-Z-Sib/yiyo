# YIYO Development Checkpoint — 2 October 2026

## Purpose

This checkpoint records the current YIYO implementation before deeper investigation of a venue-map regression.

Development is intentionally being paused at this point so the repository can be reviewed as a whole rather than continuing to patch the map based on assumptions.

## Current Git Work

The current development work has focused on:

- Global application roles
- Business memberships
- Event permissions
- Events backend
- Event engagement
- Event discovery lifetime
- Preparation for the Events frontend

## Backend — Implemented

### Application Roles

Global roles are supported through Firebase authentication/custom claims:

- `user`
- `moderator`
- `super_admin`

The `super_admin` role is intended for internal/developer administration and can bypass normal venue/event restrictions.

### Business Memberships

Business permissions are kept separate from global application roles.

Supported membership types:

- `promoter`
- `venue_manager`

Venue managers are associated with specific venues.

Promoters are organiser identities and are not automatically treated as venue owners/managers.

### Effective Permissions

The backend can derive capabilities such as:

- Moderate content
- Super-admin access
- Create events
- Manage venues

The backend remains the authority for permissions. Flutter UI visibility is not considered a security boundary.

### Event Creation Rules

Current intended behaviour:

**Normal user**
- Cannot create events

**Promoter**
- Can submit events
- Event initially enters `pending` state

**Venue manager**
- Can create events for assigned venues
- Events for their own venue can publish immediately

**Super admin**
- Can create/publish events for any venue

### Event Approval

Pending promoter events can be approved by:

- The appropriate venue manager
- A super admin

### Event API Foundation

The backend currently includes the Events API foundation for:

- Listing public events
- Reading a public event
- Creating an event
- Approving an event
- Hype
- Going
- Reading personalised event engagement state

### Hype and Going

Engagement is stored separately from event documents.

Each account can have at most:

- One Hype reaction per event
- One Going reaction per event

Deterministic reaction document IDs are used to prevent duplicate reactions.

Firestore transactions are used when toggling engagement so event counters remain consistent during concurrent activity.

### Event Discovery Lifetime

Events no longer disappear from discovery immediately after their start time.

Current rule:

- If an explicit event end time exists, discovery remains active until that time.
- If no end time exists, the event remains discoverable for eight hours after its start time.

This is intended to support nightlife events that continue late into the night or early morning.

## Backend Verification

Last verified backend test result:

**98 tests passed**

The backend Events/roles/permissions foundation was passing before this checkpoint.

## Frontend Status

The newer Events/navigation UI work has been backed out to return the app closer to the state immediately following the backend changes.

Any experimental bottom-navigation changes should not be treated as the source of truth unless they are present in the committed repository.

A fresh repository inspection should determine the exact frontend state.

## Known Blocking Issue — Discover Map

The Google Map itself renders, but the expected YIYO discovery behaviour is currently not functioning correctly.

Observed symptoms include:

- Google Map tiles render.
- Venue markers are not appearing as expected.
- The map is not reliably moving to the user's current location.
- Nearby venues are not appearing in the normal discovery experience.

The issue remains present after backing out the most recent navigation/UI changes.

Therefore, the cause should **not currently be assumed to be the new Events navigation work**.

The map should be investigated from the underlying flow:

1. Location permission/service state
2. Geolocator result
3. `_currentLocation`
4. `/venues` request
5. Backend response
6. Flutter venue parsing
7. Marker construction
8. `setState`
9. GoogleMap `markers` state
10. Camera update

The repository and runtime logs should be used to identify exactly where this chain stops.

## Previously Observed Flutter Error

During an experimental navigation change, Flutter produced:

`Draggable scrollable controller is already attached to a sheet.`

This involved the `DraggableScrollableController` used by the map's Top Nearby Spots panel.

However, because venue markers remain missing after backing out the later navigation work, this error should be treated as a separate UI lifecycle issue until proven otherwise.

It should not currently be assumed to explain the marker regression.

## Android / VS Code Diagnostic

VS Code has also shown a Java/Gradle diagnostic referring to a missing Red Hat Java extension initialization script under:

`globalStorage\redhat.java\...init.gradle`

The Android application has still been able to compile and launch.

This diagnostic has therefore not been established as the cause of the runtime map/marker issue.

It can be cleaned up separately after the map problem is understood.

## Next Investigation

Before additional feature development:

1. Inspect the fresh repository ZIP.
2. Compare the repository against this checkpoint.
3. Confirm the actual active `MapScreen`.
4. Trace startup location acquisition.
5. Confirm whether `/venues` is called.
6. Inspect the `/venues` response.
7. Confirm Venue model parsing.
8. Confirm markers are generated.
9. Identify the first point where expected state differs from actual state.
10. Apply the smallest practical fix.
11. Re-run backend tests.
12. Run Flutter analyzer/tests.
13. Verify Discover on-device.
14. Resume Events frontend only after Discover is stable.

## Product Roadmap After Map Stabilisation

Once Discover is stable again:

1. Events discovery UI
2. Event detail screen
3. Hype / Going frontend integration
4. Organiser / venue event creation experience
5. Admin and moderation tooling
6. Google Play closed testing
7. Partner venue/event beta
8. Android soft launch
9. iOS/TestFlight work in parallel

## Development Principle

The repository is the source of truth for implementation.

Do not continue patching the map from assumptions or historical snippets.

The next development session should begin with a fresh inspection of the committed repository.