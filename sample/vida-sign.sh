#!/bin/bash
# VIDA sign: sign a file.
# Requires:
#   "$1" = private key
#   "$2" = unsigned input file
#   "$3" = signed output file
#   exiftool for adding XMP record
#   dd for digest
#   grep for digest
#   openssl for signing
#   tr for formatting the signature
#   sed for inserting the signature
#   cp for making a backup of the unsigned original

#######################################
# Check if commands exist
if ! [ -x "$(command -v exiftool)" ] ; then
  echo "MISSING: exiftool"
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

if ! [ -x "$(command -v tr)" ] ; then
  echo "MISSING: tr"
  exit 1
fi

if ! [ -x "$(command -v sed)" ] ; then
  echo "MISSING: sed"
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

if [ "$4" == "" ] ; then
  echo "Usage: $0 [-v] domain private.key unsigned_image.jpg signed_image.jpg"
  exit 1
fi
DOMAIN="$1"
PRIVATEKEY="$2"
INFILE="$3"
OUTFILE="$4"

# signature placeholder; same length as the actual signature.
PLACEHOLDER=$(echo -n "3031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637" | openssl base64 | tr -d '\n')

if [ "$VERBOSE" == "1" ] ; then
  echo "DOMAIN: $DOMAIN"
  echo "PRIVATEKEY: $PRIVATEKEY"
  echo "INFILE: $INFILE"
  echo "OUTFILE: $OUTFILE"
  echo "PLACEHOLDER: $PLACEHOLDER"
fi

#######################################
# Add xmp record with a placeholder value

# Make a backup
if [ "$VERBOSE" == "1" ] ; then echo "Creating: $OUTFILE" ; fi
cp "$INFILE" "$OUTFILE"

# Create the file with a placeholder for the signature
# The place holder is "0123456789..." for 128 characters encoded as base64
if [ "$VERBOSE" == "1" ] ; then echo "Adding placeholder VIDA record" ; fi
exiftool -config exiftool-vida.config  -overwrite_original -VIDA="vida=\"1\" b=\"~S,s~\" d=\"$DOMAIN\" ka=\"rsa\" s=\"$PLACEHOLDER\"" "$OUTFILE" > /dev/null 2>&1

# Identify where the placeholder is located
if [ "$VERBOSE" == "1" ] ; then echo "Identifying signature location" ; fi
sigstart=$(grep --byte-offset --only-matching --text "$PLACEHOLDER" "$OUTFILE")
sigstart=${sigstart%:*}
siglen=${#PLACEHOLDER}
((sigend=$sigstart + $siglen))
if [ "$VERBOSE" == "1" ] ; then echo "Signature in file: $siglen bytes from offset $sigstart to $sigend" ; fi

#######################################
# Generate the signature

# 1. Sign the file (Everything except the signature placeholder.)
# 2. Use openssl to sign the data using the private key
# 3. Convert the signature to hex
# 4. Replace the signature placeholder with the real signature.
gotsig=$(
(
# TBD: Parse the b=range; for now, assume b=~S,s~
# Everything before the signature
dd if="$OUTFILE" bs=1 count="$sigstart" 2>/dev/null
# Everything after the signature
dd if="$OUTFILE" bs=1 skip="$sigend" 2>/dev/null
) | openssl dgst -sha256 -sign "$PRIVATEKEY" | openssl base64 | tr -d '\n'
)

if [ "$VERBOSE" == "1" ] ; then echo "Generated signature: $gotsig"; fi

#######################################
# Store the signature
# Do an inline-replace of the placeholder string with the signature.
sed -i -e "s@$PLACEHOLDER@$gotsig@" "$OUTFILE"

#######################################
# Double check that the signature didn't change after being inserted
if [ "$VERBOSE" == "1" ] ; then
checksig=$(
(
# TBD: Parse the b=range; for now, assume b=~S,s~
# Everything before the signature
dd if="$OUTFILE" bs=1 count="$sigstart" 2>/dev/null
# Everything after the signature
dd if="$OUTFILE" bs=1 skip="$sigend" 2>/dev/null
) | openssl dgst -sha256 -sign "$PRIVATEKEY" | openssl base64 | tr -d '\n'
)
echo "Verified signature: $checksig"
if [ "$checksig" == "$gotsig" ] ; then
  echo "Signature matched!"
else
  echo "Signature error!"
  exit 1
fi

fi

echo "DONE! $OUTFILE is signed using VIDA!"

