#!/bin/bash

#set -euo pipefail
set -o pipefail

PLUGIN_DEBUG=true
[ -n "${PLUGIN_DEBUG:-}" ] && set -x

# Get a token via Github API using app private key -> installation token -> token

# github-app-jwt.sh from https://gist.github.com/carestad/bed9cb8140d28fe05e67e15f667d98ad
# Generate JWT for Github App
#
# Inspired by implementation by Will Haley at:
#   http://willhaley.com/blog/generate-jwt-with-bash/
# From:
#   https://stackoverflow.com/questions/46657001/how-do-you-create-an-rs256-jwt-assertion-with-bash-shell-scripting

# Shared content to use as template
header='{
    "alg": "RS256",
    "typ": "JWT"
}'
payload_template='{}'

build_payload() {
	jq -c \
		--arg iat_str "$(date +%s)" \
		--arg app_id "${PLUGIN_APP_ID}" \
		'($iat_str | tonumber) as $iat
        | .iat = $iat
        | .exp = ($iat + 300)
        | .iss = ($app_id | tonumber)' <<<"${payload_template}" | tr -d '\n'
}

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
rs256_sign() { openssl dgst -binary -sha256 -sign <(printf '%s\n' "$1"); }

sign() {
	local algo payload sig
	algo=${1:-RS256}
	algo=${algo^^}
	payload=$(build_payload) || return
	signed_content="$(json <<<"$header" | b64enc).$(json <<<"$payload" | b64enc)"
	sig=$(printf %s "$signed_content" | rs256_sign "${PLUGIN_APP_PRIVATE_KEY}" | b64enc)
	printf '%s.%s\n' "${signed_content}" "${sig}"
}

# end github-app-jwt.sh
###

gh_app_login() {
	local error
	error=0
	if [ -z "${PLUGIN_APP_ID}" ]; then
		echo "app_id isn't set"
		error=1
	fi
	if ! echo "${PLUGIN_APP_PRIVATE_KEY}" | grep KEY; then
		echo "app_private_key is not set or doesn't look right"
		error=1
	fi
	if [ ${error} != 0 ]; then
		exit $error
	fi

	GH_JWT=$(sign)

	INST_RES=$(curl \
		-H "Authorization: Bearer $GH_JWT" \
		-H "Accept: application/vnd.github+json" \
		https://api.github.com/app/installations)

	INST_ID=$(echo "${INST_RES}" | jq -r "map(select(.account.login == \"${PLUGIN_GITHUB_ORG}\"))[0].id")

	if [ "z${INST_ID}z" == "znullz" ]; then
		echo could not retrieve installation ID
		exit 1
	fi

	INST_TOKEN=$(curl \
		-X POST \
		-H "Authorization: Bearer $GH_JWT" \
		-H "Accept: application/vnd.github+json" \
		https://api.github.com/app/installations/$INST_ID/access_tokens |
		jq -r .token)

	if [ "z${INST_TOKEN}z" == "znullz" ]; then
		echo could not retrieve installation token
		exit 1
	fi

	echo ${INST_TOKEN} | gh auth login --with-token
	gh auth status
	gh auth setup-git
}

echo "# plugin starting"
eval "${PLUGIN_SCRIPT}"
echo "# plugin done"
