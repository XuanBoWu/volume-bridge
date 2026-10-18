#!/bin/zsh
# Create one stable self-signed code-signing identity for this Mac.
set -euo pipefail

identity="${VB_SIGN_IDENTITY:-VolumeBridge Local Development}"
keychain="${VB_SIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
days="${VB_SIGN_DAYS:-3650}"

[[ -f "$keychain" ]] || { print -u2 "Keychain not found: $keychain"; exit 1; }

if security find-certificate -c "$identity" "$keychain" >/dev/null 2>&1 \
    && security find-key -l "$identity" -s "$keychain" >/dev/null 2>&1; then
    print "Already configured: $identity"
    exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/volume-bridge-signing.XXXXXX")"
cleanup() {
    python3 - "$tmp_dir" <<'PY'
import shutil
import sys
shutil.rmtree(sys.argv[1], ignore_errors=True)
PY
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days "$days" \
    -keyout "$tmp_dir/private-key.pem" \
    -out "$tmp_dir/certificate.pem" \
    -subj "/CN=$identity/O=VolumeBridge Local Development" \
    -addext 'basicConstraints=critical,CA:false' \
    -addext 'keyUsage=critical,digitalSignature' \
    -addext 'extendedKeyUsage=critical,codeSigning,1.2.840.113635.100.6.1.3' \
    >/dev/null 2>&1

password="$(openssl rand -hex 32)"
openssl pkcs12 -export -legacy \
    -out "$tmp_dir/identity.p12" \
    -inkey "$tmp_dir/private-key.pem" \
    -in "$tmp_dir/certificate.pem" \
    -passout "pass:$password" \
    -name "$identity" \
    >/dev/null 2>&1

security import "$tmp_dir/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign >/dev/null

if ! security find-certificate -c "$identity" "$keychain" >/dev/null 2>&1 \
    || ! security find-key -l "$identity" -s "$keychain" >/dev/null 2>&1; then
    print -u2 "The certificate was imported, but its signing key could not be found: $identity"
    exit 1
fi

print "Created stable local signing identity: $identity"
print "Keychain: $keychain"
print "Validity: $days days"
print "This identity is for local development; it is not a Developer ID certificate."
