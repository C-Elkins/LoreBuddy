# Blizzard API Setup

This guide covers creating a Blizzard Developer Portal client for optional
World of Warcraft Classic data, including the Burning Crusade Classic (TBC)
era. It is setup guidance, not a place to store credentials.

## Intended LoreBuddy Architecture

The Blizzard API should be an optional, source-aware enrichment layer. The core
addon must continue to work offline with packaged data and previously saved
discovery state. Client credentials and API calls must stay in a trusted service
or local development tool; they must never be embedded in the addon or shipped
to players.

## Create the Client

In the [Blizzard Developer Portal](https://develop.battle.net/access/clients/):

1. Open **API Access**.
2. Select **Create New Client**.
3. Use a globally unique client name, such as `LoreBuddy-TBC-Development`.
4. For **Redirect URIs**, use a local callback only if we implement the OAuth
   authorization-code flow. For machine-to-machine data access using the client
   credentials flow, do not invent a player-facing callback; follow the portal's
   required field behavior.
5. For **Service URL**, use the URL of the service that owns the credentials.
   If there is no service yet, select the portal option indicating that no
   service URL exists.
6. For **Intended Use**, describe the actual use plainly:

   > LoreBuddy is an open-source contextual lore companion. It uses optional
   > World of Warcraft and World of Warcraft Classic Game Data APIs to retrieve
   > source-aware reference data for development and optional enrichment. The
   > core addon remains functional offline, does not require player credentials,
   > and does not expose Blizzard client secrets to players.

7. Create the client and store the client ID and secret in a local secret store
   or environment variables.

The portal limits each developer to 50 clients. Create separate clients for
development and production when the service architecture is ready.

## Credentials and OAuth

For server-side Game Data API requests, use the [OAuth client credentials
flow](https://community.developer.battle.net/documentation/guides/using-oauth/client-credentials-flow).
Do not commit secrets, place them in frontend code, or send them to the addon.

Example token request:

```sh
curl -u "$BLIZZARD_CLIENT_ID:$BLIZZARD_CLIENT_SECRET" \
  -d grant_type=client_credentials \
  https://oauth.battle.net/token
```

Use the returned token only from the trusted service:

```sh
curl -H "Authorization: Bearer $BLIZZARD_ACCESS_TOKEN" \
  "https://us.api.blizzard.com/data/wow/token/index?namespace=dynamic-us"
```

The token endpoint and API host are region-specific. Select the region and
locale required by the target data, and confirm the correct World of Warcraft
Classic namespace and endpoint in the current [World of Warcraft Classic API
reference](https://community.developer.battle.net/documentation/world-of-warcraft-classic).
Do not assume a retail namespace is valid for TBC data.

## Source and Offline Requirements

API responses are source material, not an excuse to lose provenance. Any data
we persist should record, where available:

- The Blizzard API resource or endpoint.
- The namespace, region, locale, and retrieval time.
- The API response version or relevant identifiers.
- Whether the resulting explanation is fact, interpretation, or speculation.

Remote data must be cached or transformed into an approved offline format before
the core addon depends on it. A request failure should degrade to local data,
not remove the player's ability to use LoreBuddy.

## Rate Limits

Plan for the documented limit of 36,000 requests per hour and 100 requests per
second. Cache stable resources, avoid requesting data during every UI event, and
handle HTTP 429 responses with backoff. Rate-limit handling should be invisible
to the player wherever possible.

## Secret Rotation

Manage client IDs and secrets through the portal's **Manage Client** page. When
rotating a secret, set an overlap period so the old secret remains valid while
the service is updated, then revoke or expire it after verification. Never place
the old or new secret in an issue, pull request, log, screenshot, or committed
configuration file.

## References

- [Using OAuth](https://community.developer.battle.net/documentation/guides/using-oauth)
- [Game Data APIs](https://community.developer.battle.net/documentation/guides/game-data-apis)
- [Regionality and APIs](https://community.developer.battle.net/documentation/guides/regionality-and-apis)
- [World of Warcraft Classic API](https://community.developer.battle.net/documentation/world-of-warcraft-classic)