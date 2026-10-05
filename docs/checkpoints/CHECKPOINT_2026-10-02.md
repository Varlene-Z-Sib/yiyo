# YIYO Development Checkpoint — 2 October 2026

## Purpose

This checkpoint records the YIYO implementation after completion of the roles, permissions, business-membership, and Events backend foundation.

A Discover-map issue observed around this checkpoint was subsequently investigated and resolved. The cause was backend IP configuration rather than the Flutter map implementation.

## Current Development Branch

`feat/roles-permissions`

## Backend — Implemented

### Application Roles

Global application authority is managed separately from business relationships.

Supported application roles:

- `user`
- `moderator`
- `super_admin`

Firebase custom claims are used for application-level authority.

`super_admin` is intended for internal/developer administration and can bypass normal venue/event restrictions.

### Business Memberships

Business permissions are stored separately from application roles.

Supported memberships:

- `promoter`
- `venue_manager`

Promoters are organiser identities.

Venue managers are associated with specific venues.

This separation allows a normal application user to also have business permissions without incorrectly giving them global administrative access.

### Effective Permissions

The backend derives effective permissions from:

Firebase authentication/custom claims

plus

Firestore business memberships.

Current derived capabilities include:

- Moderate content
- Super-admin access
- Create events
- Manage venues

The FastAPI backend remains the authority for permissions.

Flutter UI visibility is not considered a security boundary.

## Event Creation Rules

### Normal user

Cannot create events.

### Promoter

Can submit events.

Promoter-created events initially enter:

`pending`

They require approval before becoming publicly visible.

### Venue manager

Can create events for venues they manage.

Events created for an assigned venue can publish immediately.

### Super admin

Can create and publish events for any venue.

## Event Approval

Pending promoter events can be approved by:

- The appropriate venue manager
- A super admin

This prevents a promoter from automatically publishing an event on behalf of a venue they do not control.

## Events API Foundation

The backend currently supports the foundation for:

- Public event listing
- Public event details
- Authenticated event creation
- Event approval
- Hype
- Going
- Personalised event engagement state

## Hype and Going

Event engagement is stored separately from the event document.

Each user account may have at most:

- One Hype reaction per event
- One Going reaction per event

Deterministic reaction document IDs are used to prevent duplicate reactions.

Firestore transactions are used when reactions are toggled so event counters remain consistent during concurrent activity.

Event documents contain materialised counters:

- `hype_count`
- `going_count`

## Event Discovery Lifetime

Events should remain discoverable while they are actually happening.

Current rule:

If an explicit event end time exists:

`visible until ends_at`

If an explicit end time does not exist:

`visible until eight hours after starts_at`

This prevents nightlife events from disappearing from YIYO immediately after their scheduled start time.

## Backend Verification

Last verified backend test result:

**98 tests passed**

The roles, permissions, memberships, Events, and engagement foundation passed the backend test suite at this checkpoint.

## Frontend State

The experimental Events frontend and bottom-navigation implementation were intentionally backed out before this checkpoint.

The authenticated application continues to enter the existing Discover `MapScreen`.

The Events backend therefore exists before the production Events frontend.

This was intentional so the existing Discover experience could be stabilised before adding the Events interface again.

## Resolved Issue — Discover Map / Missing Markers

An apparent Discover regression was investigated after this checkpoint.

Observed symptoms included:

- Google Map tiles rendered.
- Venue markers did not appear.
- The map did not move to the expected current location.
- Nearby venues did not populate correctly.

Initial investigation considered:

- `MapScreen`
- `DraggableScrollableController`
- Google Maps rendering
- Flutter navigation changes
- Venue parsing
- Backend venue processing

The repository was then rolled back to the frontend state immediately following the backend changes.

The problem remained.

Further tracing showed that the Flutter marker pipeline only executes after:

`ApiService.getVenues()`

successfully completes.

The actual cause was **backend IP configuration**.

The Flutter application was pointing at an incorrect or unreachable backend address, preventing the expected `/venues` request flow from completing correctly.

After correcting the IP/backend configuration:

- The map worked.
- Current-location behaviour worked.
- Venue loading worked.
- Venue markers worked.

No Google Maps or `MapScreen` rewrite was required to resolve the marker issue.

### Important lesson

For physical-device development, the Flutter application must use a backend address reachable from the device.

`127.0.0.1`

inside an Android device refers to the Android device itself, not the development PC.

The runtime `BACKEND_BASE_URL` configuration must therefore point to the correct reachable backend address.

## Separate UI Lifecycle Observation

During experimental navigation work, Flutter produced:

`Draggable scrollable controller is already attached to a sheet.`

The map contains a `DraggableScrollableController` for the Top Nearby Spots panel.

Because the actual marker/location failure was resolved through backend IP configuration, this controller issue should be treated as a separate UI lifecycle concern rather than the root cause of the venue-loading problem.

It can be addressed independently if reproduced.

## Android / VS Code Diagnostic

VS Code has also displayed a Java/Gradle diagnostic referring to a missing Red Hat Java extension initialisation script under:

`globalStorage\redhat.java\...init.gradle`

The Android application can still build and launch.

This diagnostic has not been established as a runtime YIYO failure and should be investigated separately rather than mixed with product debugging.

## Verified Product Foundation

At this checkpoint the following major systems have been established:

Firebase authentication

Venue discovery

Google Maps

Google Places-backed venue discovery

Venue markers

Venue details

Quick Vibe contributions

Current Vibe community summaries

Contribution freshness

Contribution moderation and reporting

Contributor profiles

Contribution history

Application roles

Moderator authority

Super-admin authority

Promoter memberships

Venue-manager memberships

Event permissions

Event creation backend

Event approval backend

Hype backend

Going backend

Event discovery lifetime

## Next Development Stage

The next feature is the production Events frontend.

Recommended implementation order:

Events data models

→ Events API integration

→ Events discovery screen

→ Event details

→ Hype / Going controls

→ Navigation integration

→ Super-admin event creation

→ Promoter event creation

→ Venue-manager event management

→ Real event end-to-end test

## Events Product Goal

The initial Events experience should support YIYO's soft-launch strategy.

Users should be able to:

Discover nightlife events

See where and when they are happening

Build Hype before the night

Indicate they are Going

Open the associated venue

Eventually see the Current Vibe while the event is happening

Organisers and venues should eventually be able to use event engagement as a useful marketing signal.

## Development Principle

The repository is the source of truth for implementation.

When a regression occurs:

Identify the first broken point in the actual runtime path.

Do not rewrite working systems based on assumptions.

Apply the smallest practical fix.

Verify with automated tests and on-device testing before continuing feature development.