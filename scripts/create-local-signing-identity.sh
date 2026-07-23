#!/bin/bash
# Creates a self-signed "Reword Local Dev" code-signing certificate in the login keychain.
#
# Why: without a paid Apple Developer ID, local builds are normally signed ad-hoc, and ad-hoc
# signatures are derived from the binary's own hash — so every rebuild produces a "different"
# app as far as macOS's permission system (TCC) is concerned, silently revoking Accessibility
# (and other) grants each time. Signing with a stable local identity instead keeps the app's
# signing identity constant across rebuilds, so permissions granted once stick.
#
# This is purely local: nothing is uploaded anywhere, and the resulting signature isn't trusted
# by anyone else's Mac — it only needs to be consistent on this machine. Safe to re-run; it
# replaces any existing "Reword Local Dev" identity.
#
# Usage: scripts/create-local-signing-identity.sh
#
# After running this once, scripts/build-dmg.sh automatically picks up and uses the identity.

set -euo pipefail

CERT_NAME="Reword Local Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cat > "$WORKDIR/ext.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_req
prompt = no

[dn]
CN = $CERT_NAME

[v3_req]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
EOF

echo "==> Removing any existing \"$CERT_NAME\" identity"
security delete-identity -c "$CERT_NAME" "$KEYCHAIN" 2>/dev/null || true

echo "==> Generating self-signed certificate"
# Apple's bundled /usr/bin/openssl (LibreSSL) is used deliberately: Homebrew's OpenSSL 3.x
# produces PKCS12 files `security import` can't parse without the (often-missing) legacy
# provider module.
/usr/bin/openssl req -x509 -newkey rsa:2048 \
  -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
  -days 3650 -nodes -config "$WORKDIR/ext.cnf" -extensions v3_req

/usr/bin/openssl pkcs12 -export \
  -out "$WORKDIR/identity.p12" \
  -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
  -passout pass:reword-local-dev

echo "==> Importing into the login keychain"
security import "$WORKDIR/identity.p12" -k "$KEYCHAIN" -P reword-local-dev \
  -T /usr/bin/codesign -T /usr/bin/security -A

echo "==> Trusting it for code signing"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORKDIR/cert.pem"

echo "==> Done. Verifying:"
security find-identity -v -p codesigning | grep "$CERT_NAME"

echo
echo "The first time codesign uses this identity, macOS may show a one-time keychain prompt —"
echo "click \"Always Allow\". scripts/build-dmg.sh will use this identity automatically from now on."
