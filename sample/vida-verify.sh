#!/bin/bash
# VIDA verify: check a VIDA signature.
# TBD:
#   Add support for parsing the various parameters.
#   This code currently assumes the default: vida=1, ka=rsa, sf=hex, b=~S,s~
#   It also has vulnerabilities in case of unchecked quoted variables.
#   THIS IS FOR TESTING and PROOF-OF-CONCEPT DEMO ONLY.

# Requires:
#   "$1" = signed file
#   The domain to query comes from DNS and the VIDA d= parameter.
#   dig retrieves the DNS TXT field.
#   sed for formatting the dig result
#   exiftool for extracting XMP record
#   dd for digest
#   grep for digest
#   openssl for validating the signature

#######################################
# Check if commands exist
if ! [ -x "$(command -v exiftool)" ] ; then
  echo "MISSING: exiftool"
  exit 1
fi

if ! [ -x "$(command -v dig)" ] ; then
  echo "MISSING: dig"
  exit 1
fi

if ! [ -x "$(command -v sed)" ] ; then
  echo "MISSING: sed"
  exit 1
fi

if ! [ -x "$(command -v openssl)" ] ; then
  echo "MISSING: openssl"
  exit 1
fi

if ! [ -x "$(command -v grep)" ] ; then
  echo "MISSING: grep"
  exit 1
fi

if ! [ -x "$(command -v dd)" ] ; then
  echo "MISSING: dd"
  exit 1
fi

if ! [ -x "$(command -v cp)" ] ; then
  echo "MISSING: cp"
  exit 1
fi

VERBOSE=0
if [ "$1" == "-v" ] ; then
  VERBOSE=1
  shift
fi

if [ "$1" == "" ] ; then
  echo "Usage: $0 [-v] signed_image.jpg"
  exit 1
fi
INFILE="$1"

if [ "$VERBOSE" == "1" ] ; then echo "INFILE: $INFILE" ; fi

#######################################
# Extract the VIDA record.
#   - Make sure the VIDA record exists
#   - Retrieve the domain name
#   - Retrieve the signature
#   TBD: This uses XMP. Add support for PNG, JPEG APP, and other formats.
vida=$(exiftool -xmp:vida "$INFILE")
if [ "$vida" == "" ] ; then
  echo "No VIDA record found in $INFILE"
  exit 0
fi

# Find the domain
domain=""
if [[ "$vida" =~ ^.*\ d=[\"\']?([0-9a-zA-Z.-]+) ]] ; then
  domain=${BASH_REMATCH[1]}
else
  echo "ERROR: No domain name found in VIDA record."
  exit 1
fi
if [ "$VERBOSE" == "1" ] ; then echo "Domain from file: $domain" ; fi

# Find the signature
sig=""
if [[ "$vida" =~ ^.*\ s=[\"\']?([0-9a-zA-Z+/]+=*) ]] ; then
  sig=${BASH_REMATCH[1]}
else
  echo "ERROR: No signature found in VIDA record."
  exit 1
fi
if [ "$VERBOSE" == "1" ] ; then echo "Signature from file: $sig" ; fi

#######################################
# Get the public key from the domain
#   TBD: Make sure the TXT record is the correct TXT record.
#   TBD: Support the different sf= values.

# Look for any TXT records that are for vida=1 and not revoked
# DNS might break long lines "abcdef" into "abc" "def". Use sed to recombine them.
dns=$(dig TXT "$domain" | grep TXT | grep 'vida=1' | grep 'ka=rsa' | grep -v ' r=' | sed -e 's@" "@@g')
if [ "$dns" == "" ] ; then
  echo "ERROR: No VIDA public key found at $domain"
  exit 1
fi

if [[ "$dns" =~ ^.*\ p=[\"\']?([0-9a-zA-Z+/]+) ]] ; then
  pubkey=${BASH_REMATCH[1]}
else
  echo "ERROR: No VIDA public key found in DNS record."
  exit 1
fi
if [ "$VERBOSE" == "1" ] ; then echo "Public key from DNS: $pubkey" ; fi

#######################################
# Compute the current digest
#   TBD: Add support for any b= value. Currently assumes b=~S,s~

# Find out where the signature starts
sigstart=$(grep --byte-offset --only-matching --text "$sig" "$INFILE")
sigstart=${sigstart%:*}
siglen=${#sig}
((sigend=$sigstart+$siglen))
if [ "$VERBOSE" == "1" ] ; then echo "Signature in file: $siglen bytes from offset $sigstart to $sigend" ; fi

#######################################
# Decrypt the signature to get the expected digest

# From the command line, openssl only works on files.
# Use a temp files!

# Store the known public key from DNS
PubFile="$INFILE.der"
echo "$pubkey" | openssl base64 -d > "$PubFile"

# Store the known signature from the file
SigFile="$INFILE.sig"
echo "$sig" | openssl base64 -d > "$SigFile"

if [ "$VERBOSE" == "1" ] ; then openssl version ; fi
# See if they match!
  (
  # TBD: Parse the b=range; for now, assume b=~S,s~
  # everything up to the signature
  dd if="$INFILE" bs=1 count=$sigstart status=none 2>/dev/null
  # everything after the signature
  dd if="$INFILE" bs=1 skip=$sigend status=none 2>/dev/null
  ) | openssl dgst -sha256 -keyform der -verify "$PubFile" -signature "$SigFile" -binary
# Openssl will say whether it is validated

# Clean up
unlink "$PubFile"
unlink "$SigFile"

