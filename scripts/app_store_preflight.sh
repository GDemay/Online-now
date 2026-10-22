#!/usr/bin/env bash
# Read-only App Store Connect inventory. Never logs credentials or mutates Apple resources.
set -euo pipefail
umask 077

app_id=6758242393
bundle_id=com.gdemay.onlinenow
candidate_version=1.2.0
asc_bin=${ASC_BIN:-asc}

if ! command -v "$asc_bin" >/dev/null 2>&1; then
    printf '%s\n' 'asc is unavailable. Put asc 5.16.0 on PATH or set ASC_BIN to its executable path.' >&2
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'python3 is required to summarize the read-only responses.' >&2
    exit 1
fi

inventory_dir=$(mktemp -d)
trap 'rm -rf "$inventory_dir"' EXIT

read_resource() {
    local resource=$1
    shift
    if ! ASC_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1 "$asc_bin" "$@" >"$inventory_dir/$resource.json" 2>"$inventory_dir/$resource.err"; then
        printf 'Read-only preflight failed while reading %s. Verify API authentication and App Manager access; no Apple resources were changed.\n' "$resource" >&2
        exit 1
    fi
}

read_resource app api GET "/v1/apps/$app_id"
read_resource versions versions list --app "$app_id" --platform IOS --paginate --output json
read_resource workflows xcode-cloud workflows list --app "$app_id" --paginate --output json
read_resource tips iap list --app "$app_id" --product-id onlinenow.gdemay --include-versions --paginate --output json
read_resource builds builds list --app "$app_id" --platform IOS --version "$candidate_version" --processing-state all --paginate --output json

python3 - "$inventory_dir" "$app_id" "$bundle_id" "$candidate_version" <<'PY'
import json
from pathlib import Path
import sys

root, expected_app, expected_bundle, candidate = sys.argv[1:]

def load(name):
    with (Path(root) / f'{name}.json').open() as response:
        return json.load(response)

def records(name):
    value = load(name)
    result = value.get('data', []) if isinstance(value, dict) else value
    if not isinstance(result, list):
        raise ValueError(f'Unexpected {name} response shape')
    return result

try:
    app = load('app')['data']
    if app.get('id') != expected_app or app.get('attributes', {}).get('bundleId') != expected_bundle:
        raise ValueError('The authenticated account returned an unexpected app or bundle identifier')
    workflows = records('workflows')
    tips = records('tips')
    valid_tips = [item for item in tips if item.get('attributes', {}).get('productId') == 'onlinenow.gdemay'
                  and item.get('attributes', {}).get('inAppPurchaseType') == 'CONSUMABLE']
    blockers = []
    if not workflows:
        blockers.append('No Xcode Cloud workflow was returned for this app')
    if not valid_tips:
        blockers.append('The expected consumable onlinenow.gdemay was not returned')
    summary = {
        'readOnly': True,
        'appID': expected_app,
        'bundleID': expected_bundle,
        'candidateVersion': candidate,
        'versions': [{
            'id': item.get('id'),
            'version': item.get('attributes', {}).get('versionString'),
            'state': item.get('attributes', {}).get('appVersionState') or item.get('attributes', {}).get('appStoreState')
        } for item in records('versions')[:50]],
        'workflows': [{
            'id': item.get('id'),
            'name': item.get('attributes', {}).get('name'),
            'enabled': item.get('attributes', {}).get('isEnabled')
        } for item in workflows[:50]],
        'tips': [{
            'id': item.get('id'),
            'productID': item.get('attributes', {}).get('productId'),
            'type': item.get('attributes', {}).get('inAppPurchaseType'),
            'state': item.get('attributes', {}).get('state')
        } for item in tips[:50]],
        'candidateBuilds': [{
            'id': item.get('id'),
            'number': item.get('attributes', {}).get('version'),
            'processingState': item.get('attributes', {}).get('processingState')
        } for item in records('builds')[:50]],
        'summaryLimitPerResource': 50,
        'blockers': blockers,
        'releaseReady': 'Not established: inspect workflow actions, run native tests, verify sandbox payments, metadata, and agreements'
    }
    print(json.dumps(summary, indent=2))
    sys.exit(1 if blockers else 0)
except (KeyError, TypeError, ValueError, OSError, json.JSONDecodeError):
    print('The read-only preflight could not validate the expected app or parse its inventory. No Apple resources were changed.', file=sys.stderr)
    sys.exit(1)
PY
