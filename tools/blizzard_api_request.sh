#!/bin/sh

set -eu

: "${BLIZZARD_CLIENT_ID:?Set BLIZZARD_CLIENT_ID in your local environment}"
: "${BLIZZARD_CLIENT_SECRET:?Set BLIZZARD_CLIENT_SECRET in your local environment}"

region="${BLIZZARD_REGION:-us}"
namespace="${BLIZZARD_NAMESPACE:-dynamic-${region}}"
locale="${BLIZZARD_LOCALE:-en_US}"
api_path="${BLIZZARD_API_PATH:-/data/wow/token/index}"
oauth_url="${BLIZZARD_OAUTH_URL:-https://oauth.battle.net/token}"

token_response=$(curl --fail-with-body --silent --show-error \
	--user "$BLIZZARD_CLIENT_ID:$BLIZZARD_CLIENT_SECRET" \
	--data grant_type=client_credentials \
	"$oauth_url")
access_token=$(printf '%s' "$token_response" | jq -er '.access_token')

curl --fail-with-body --silent --show-error \
	--header "Authorization: Bearer $access_token" \
	--get "https://${region}.api.blizzard.com${api_path}" \
	--data-urlencode "namespace=${namespace}" \
	--data-urlencode "locale=${locale}"