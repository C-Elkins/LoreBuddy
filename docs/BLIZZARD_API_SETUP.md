# Blizzard API Setup

**Status: optional, rarely used.** LoreBuddy's lore database is built from
original writing plus cited secondary sources (Warcraft Wiki, Wowhead); it
does not depend on this API. The Game Data API only returns structured
metadata (IDs, names, taxonomy) -- never narrative lore text -- so its only
realistic use here is occasionally verifying a name/ID already in our
dataset against an official record. Most contributors will never need this
guide.

This guide covers creating a Blizzard Developer Portal client for optional
World of Warcraft Classic data, including the Burning Crusade Classic (TBC)
era. It is setup guidance, not a place to store credentials.

## Intended LoreBuddy Architecture

The Blizzard API should be an optional, source-aware enrichment layer. The core
addon must continue to work offline with packaged data and previously saved
discovery state. Client credentials and API calls must stay in a trusted service
or local development tool; they must never be embedded in the addon or shipped
to players.

## Account Prerequisites

Before creating a client:

1. Log in to your Battle.net account, or [create one](https://account.battle.net/creation).
2. Attach a [Battle.net Authenticator](https://us.battle.net/support/en/article/24520).
   Two-factor authentication is required for any API usage.
3. Accept the [Blizzard Developer API Terms of Use](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use).

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
   or environment variables. Files such as `blizzard-credentials.json` and
   `blizzard-token.json` are ignored by Git in this repository, but do not rely
   on ignore rules alone: never include credentials in a CurseForge upload or
   any addon package.

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

For local development, copy `.env.example` to `.env.local`, fill in the
rotated credentials locally, and load those variables into your shell. The
repository includes `tools/blizzard_api_request.sh` to perform the token flow
and make one authenticated GET request without placing credentials in addon
code.

The helper requires `curl` and `jq`. For example:

```sh
set -a
. ./.env.local
set +a
./tools/blizzard_api_request.sh
```

Set `BLIZZARD_API_PATH`, `BLIZZARD_NAMESPACE`, `BLIZZARD_REGION`, and
`BLIZZARD_LOCALE` to the values documented for the specific WoW Classic/TBC
resource before making a request. The default token endpoint in the example is
only a connectivity check; it does not establish the correct TBC namespace.

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

## Namespaces

Game Data and Profile APIs publish every document to a namespace, which lets
multiple versions of the same document type coexist at one URL without being
overwritten. A namespace is specified either as a query parameter
(`?namespace=dynamic-us`) or a request header (`Battlenet-Namespace`). Do not
treat a namespace as strict or semantic versioning, even when it contains a
version-like string; naming and rotation are decided by the API publisher, not
by a fixed convention we can rely on.

## Response Format And JSON Document Links

Game Data and Profile APIs return one full resource per request, not a
composite of several objects, and responses are only reshaped when a
localization identifier is requested. To reach related data, follow the
`_links`/`key` objects embedded in a response rather than constructing URLs by
hand:

```json
{
  "key": { "href": "https://us.api.blizzard.com/data/wow/journal-instance/758?namespace=static-us" },
  "name": { "en_US": "Icecrown Citadel", "de_DE": "Die Eiskronenzitadelle" },
  "id": 758
}
```

When we persist data from a linked resource, record the `href` alongside the
usual source/provenance fields so the exact resource can be re-fetched or
re-verified later.

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
- [Community APIs](https://community.developer.battle.net/documentation/guides/community-apis)
- [Regionality and APIs](https://community.developer.battle.net/documentation/guides/regionality-and-apis)
- [World of Warcraft Classic API](https://community.developer.battle.net/documentation/world-of-warcraft-classic)
- [World of Warcraft API reference](https://community.developer.battle.net/documentation/world-of-warcraft)
- [Battle.net API reference](https://community.developer.battle.net/documentation/battle-net)