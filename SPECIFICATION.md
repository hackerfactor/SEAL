# SEAL Specification
Version 1.2.2, 13-February-2025

Secure Evidence Attribution Label (SEAL) is an open solution for assigning attribution with authentication to media. It can be easily applied to pictures, audio files, videos, documents, and other file formats.

This document provides the technical implementation details, including the high-level overview and low-level implementation details for local signer, local verifier, remote signer, and DNS service.

## Changes
- 1.2.2 (2025-02-13) For readability: Splitting the signing, informational, and source reference fields into separate subsections.
- 1.2.1 (2025-02-12) Adding derived source references.
- 1.1.5 (2024-11-16) Moving all format-specific information into the [Formats](/FORMATS.md) documentation.
- 1.1.4 (2024-10-05) More details about formats and rewording the appending rules for overlap protection.
- 1.1.3 (2024-09-07) Renamed from VIDA to SEAL.

## Solution Intent
SEAL allows a user to cryptographically sign a file. The cryptographic implementation prevents forged signatures, false attribution, and false signing denials (non-repudiation).

What is the intent behind signing a file?
- SEAL doesn't attribute copyright or ownership. A malicious user can easily remove the signature and add in their own signature, claiming ownership. (Copyright or authorship can be declared in an existing EXIF, IPTC, or XMP metadata field.)
- SEAL doesn't prove that a file is authentic or altered. Anyone can digitally sign any kind of media.
- SEAL doesn't prevent the media (picture, audio, video, etc.) from being used out of context. A malicious user can always misrepresent the content.

So what does SEAL provide? Attestation and responsibility. Signing a file puts your name on it. This means: you take responsibility for the content and metadata.
- If an image is represented as real and has your name on it, then you attest that the content is authentic.
- If you claim to be the authorized source of a picture, then put your name on it as the authoritative contact.
- If a third-party signer is signing on behalf of an authenticated user, then specify the user's identifier as the notarized authoritative source. If a picture turns out to be a forgery, then the signature will point to the third-party signer and the signer will point to the authenticated user who requested the signature.

You should not sign a file unless you can vouch for the accuracy of the metadata and content. For a photo, this should be the device's firmware, photographer, publisher, or investigator. For music, this could be the composer, recorder, publisher, or auditor. For any other kind of media, it should be the creator, author, or someone who can vouch for the authenticity.

This attestation means that SEAL should reduce the number of forgeries and misrepresented content. A forgery won't use SEAL to authenticate a file since the false attestation can be easily traced back to the signer.

Other authentication solutions effectively assign blame. SEAL provides accountability.

## Solution Overview
SEAL is based on the same concepts used by DKIM ([RFC6376](https://datatracker.ietf.org/doc/html/rfc6376)) to protect email. The basic DKIM workflow is as follows:

![DKIM workflow](/docs/workflow-dkim.png)

1. The sender generates a public/private key pair. This is only done once.
2. The private key is kept on the sending system. The public key is published in a DNS record.
3. When an email is sent, portions of the email contents are used to generate a hash.  The hash is cryptographically signed using the private key.  The hash components and signature are stored in the email header.
4. The recipient system receives the email.
   - It computes the associated hash based on the email contents.
   - It retrieves the public key from the DNS entry using the domain name specified by the DKIM header.
   - It compares the hash with the signature and public key in in order to see if the signature matches.
   - If the signature matches, then the email is authenticated and validated. If the signature does not match, then the email is tampered or forged, and discarded as spam.

DKIM provides:
- **Authentication**: The email states who sent it and the cryptographic key validates the sender (either the sending system or sending user). This prevents someone from forging an email as the sender.
- **Provenance**: The email header identifies the email's origination system.
- **Tamper Detection**: The cryptographic signature prevents unauthorized changes to the signed email. While someone could remove the DKIM header, the authentication requirement prevents someone from forging the header as the user defined in the provenance.
- **Non-repudiation**: Only the sender has access to the private key used for signing the email. A valid signature must come from the sender.

SEAL extends the time-tested and proven DKIM approach to any file format, including pictures, audio files, videos, and documents.

![SEAL workflow](/docs/workflow-seal.png)

With SEAL:

1. The sender generates a public/private key pair. This is only done once.
2. The private key is kept on the signing system. The public key is published in a DNS record.
3. When a file is signed, portions of the file are used to generate a hash. The hash is cryptographically signed using the private key. The hash components and signature are stored in the metadata.
4. Any recipient of the file can validate the signature:
   - It computes the associated hash based on the file's contents, as specified in the SEAL metadata.
   - It retrieves the public key from the DNS entry using the domain name specified by the SEAL metadata.
   - It compares the hash with the signature (in the metadata) and public key (from DNS) in in order to see if the signature matches.
   - If the signature matches, then the file is authenticated and validated. If the signature does not match, then the file is tampered or forged, and explicitly untrusted.

## About RSA Signing
The RSA algorithm (named after the inventors, Rivest, Shamir, and Adleman) uses a public and private key pair.
- Any data encrypted with the private key can only be decrypted with the public key.
- Any data encrypted with the public key can only be decrypted with the private key.

Signing uses the private key to encrypt a digest and the public key to decrypt it.
- For signing:
  1. Compute a hash of the data, such as a SHA256 digest.
  2. Encrypt the digest using the private key.  The result is the 'signature'.
- For validation:
  1. Compute a hash of the data again, such as a SHA256 digest.
  2. Decrypt the signature using the public key.
  3. Check if the decrypted signature matches the computed digest.

The length of the signature is dependent on the length of the key. For example:
- A 512-bit RSA key pair should generate a 512-bit (64 byte) signature. (Considered 'weak' by today's standards.)
- A 1024-bit RSA key pair should generate a 1024-bit (128 byte) signature.
- A 2048-bit RSA key pair should generate a 2048-bit (256 byte) signature. (The shortest length considered 'strong' by today's standards.)

There exist other public/private key systems, such as DSA (Digital Signature Algorithm), Elliptic Curve, and Lattice-based Cryptography. However, RSA is currently widely used for digital signatures. The current SEAL version only supports RSA; others may be added later.

## Key Generation
SEAL relies on a public/private key pair. (Key creation uses the same steps DKIM uses to create keys for email signing.)
- The private key is kept with the signer and prevents anyone else from creating a forged signature. To create the private key, you can use:
```
openssl genrsa -out seal-private.pem 2048
```
This generates a private key file named "seal-private.pem". It uses 2048-bit RSA encoding.
- The public key is published in a DNS "TXT" record. To create the public key from the private key, you can use:
```
openssl rsa -in seal-private.pem -pubout -outform der 2>/dev/null -out seal-public.der
```
This creates a file named "seal-public.der" that will be shared in the DNS record.

With OpenSSL, there are different file formats, including:
- PEM: A Privacy Enhanced Mail (PEM) file contains base64 encoded data and includes BEGIN and END markers.
- DER: A Distinguished Encoding Rules (DER) file is a raw binary file. It contains the same information as a PEM file, but the DER format is smaller because it is not base64 encoded.

The public DER file contains raw binary and will need to be encoded before being stored in DNS.

## DNS Storage
The public key is stored in a DNS record. This requires access to a domain's DNS service. If you own your own domain name, then adding a DNS entry it typically provided by your domain registrar. However, you cannot add a DNS record to someone else's domain name.

The DNS entry MUST contain a series of field=value pairs. The defined fields are:
- `seal=1` (Required) This specifies a SEAL record for version 1 (the current version). This MUST be the first text in the TXT record.
- `ka=rsa` (Required) The **k**ey **a**lgorithm. This must match the algorithm used to generate the key. For RSA, use "rsa". For elliptic curve algorithms, use "ka=ec".
- `kv=1` (Optional) This specifies the **k**ey **v**ersion, in case you update the keys. When not specified, the default value is "1". The value can be any text string using the character set: [A-Za-z0-9.+/-] (letters, numbers, limited punctuation, and quotes or no spaces).
- `uid=string`. (Optional) This specifies an optional **u**nique **i**dentifier, such as a UUID or date. The value is case-sensitive. The uid permits different users at a domain to have many different keys. When not present, the default value is an empty string: `uid=''`. The string cannot contain single-quote ('), double-quote ("), or space characters.
- `p=base64data` (Required) The base64-encoded **p**ublic key. Ending "=" in the base64 encoding may be omitted. The value may include whitespace and double quotes. For example: `p="abcdefg="` is the same as `p=abcdefg` is the same as `p="abc" "defg" "="`. Double quotes and spaces are permitted because some DNS systems require breaks for long values. The `p=` parameter MUST be the last field in the DNS TXT record.

For revocation:
- `r=date` The timestamp in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html) (year-month-day) format denoting the **r**evocation date in GMT. All signatures after this date are treated as invalid, even if the public key validates the signature. Use this when the key is revoked after a specific date. E.g., `r=2024-04-03T12:34:56`, `r="2024-04-03 12:34:56"`, or `r=2024-04-03`.
- `p=`, `p=revoke`, or no `p=` defined. This indicates that all instances of this public key are revoked. `r=` is not required when revoking all keys.
- If both `r=` is present and `p=` denotes a revocation, then `r=` must be ignored and all keys are revoked. This is because there is no public key available for validating pre-revocation signatures.

DNS has a limit of 255 bytes per text string. Longer SEAL records can be split into strings. For this reason, values cannot contain double quotes. Most DNS providers will automatically split long strings when you create the TXT field.

A complete DNS record may look like:
```
seal.example.com TXT seal=1 ka=rsa p="MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA43KBD2MSnczlYRZJqS9BPjwFK1o+obHy" "oV2II2R2jbug91wzBfUU+uJm3iYbfQWz7CJ5fbzN+OQT+sXM5PjdjCPKI/4o+h58QqBlF8JrS5ip" "QwZtJfgvd7UKYxvL4trDTeU7zqShTHygMNibn9LzcwhHQ2MJvuq76V6W6lobab56oHQjwvH3Rqqw" "YJtOpr3qt3+oIq5Ex++GD9DYuJDQce2KNhAd8zLb8Y0fzpvOEQaOTG6vgnoWJlIWFAkZaHlI5ie2" "lI3YYX5z9+j9wucCEfu3fdm7nB4VzTGyW3D7zdFyMbEbhY6jPv+0k7IWWS5QV8DpTkgPj0VU5Xxw" "ty6cGQIDAQAB"
```

The hostname does *not* need to contain "seal". The only requirement is that it must be a valid DNS name *and* must match the domain name specified in the metadata signature.

## Metadata Signature Format
The SEAL metadata format is very similar to the DNS entry format. It consists of:
- A single text entry with no newlines.
- Multiple field=value pairs separated by a single space.
- There MUST NOT be any spaces around the equal sign.
- Any value that contains spaces must be quoted.
- Binary data must not be quoted.
- The values may be quoted with single quotes ['] or double quotes ["]; "smartquotes" and other quoting characters are not permitted. The quote mark that begins the value must also be used to end the value. E.g., "valid", and 'valid', but 'invalid".
- Unless specified, the valid character set is:
  - All ASCII letters [A-Za-z] and numbers [0-9]
  - Punctuation excluding quotes
  - <i>Either</i> single quote (') or double quote (") but not both. This is because values must be quotable.
  - Space (' ', character code 0x20)
Other characters, including tabs, binary, and multibyte characters are not permitted.

The fields for specifying the signature are as follows:
- `seal=1` (Required) This specifies a SEAL record for version 1 (the current version). This MUST be the first text in the SEAL record.
- `ka=rsa` (Required) The **k**ey **a**lgorithm. This must match the algorithm used to generate the key. For now, you can expect "rsa". For elliptic curve algorithms, use "ec".
- `kv=1` (Optional) This specifies the **k**ey **v**ersion, in case you update the keys. When not specified, the default value is "1". The value can be any text string using the character set: [A-Za-z0-9.+/-] (letters, numbers, and limited punctuation; no spaces).
- `da=sha256` (Optional) The **d**igest **a**lgorithm. This MUST be a NIST-approved algorithm. Current supported values are:
  - "sha256": The default value.
  - "sha512": For much longer digests.
  - "sha1": For shorter digests. (This algorithm is deprecated by NIST, but still widely used.)
- `b=range` (Optional) The **b**yte range to include in the digest. This can be a complex field with sets of ranges *start*~*stop*, using tilda to denote the range deliminator. Multiple ranges may be specified by commas.
  - Each range *start*~*stop* segment must be monotonically increasing. The *stop* value must never be before the *start* value. An invalid range is an error.
  - The *start* value must never be located before the start of the file. This is an invalid range error.
  - The *stop* value must never be located after the end of the file. This is an invalid range error.
  - If the *start* is not specified, then it denotes the beginning of the file.
  - If the *stop* is not specified, then it denotes the end of the file.
  - The range should never include the signature itself. This is because the value of the signature is unknown before it is signed. This type of invalid range will generate an invalid signature.
  - The following literal characters are defined for denoting specific offsets:
    - 'F' denotes the beginning of the file. This is equivalent to "0".
    - 'f' denotes the end of the file.
    - 'S' denotes the beginning of the signature.
    - 's' denotes the end of the signature, including any optional padding.
    - 'P' denotes the beginning of the previous signature. This is useful when a file contains multiple signatures, such as with a periodically-signed video stream. If there is no previous signature, then this is equivalent to zero (0). 
    - 'p' denotes the end of the previous signature. If there is no previous signature, then this is equivalent to zero (0). 
  - Any literal character may be combined with simple arithmetic offsets.
    - For example: `b=F+4~S,s~f-20` This defines two ranges. The first begins 4 bytes into the file and ends at the start of the signature. The second begins after the signature and ends 20 bytes before the end of the file.
    - As another example, PNG files use chunks that end with a four-byte checksum. The checksum is not known until after the signature is computed. As a result, the byte range must exclude the PNG chunk's checksum. After the checksum is computed and inserted into the file, the chunk checksum must be updated. Assuming that the signature ends at the end of the chunk, the range can use `b=F~S,s+4~f` to exclude the signature and PNG checksum.
    - A streaming video may insert SEAL records using `b=P~S` in order to sign the bytes between the previous signature and the appended streaming data. When finalizing (closing) the video stream, the last SEAL entry SHOULD contain `b=P~S,s~f` to sign from the previous signature to the current signature and from the current signature to the end of the file.
  - If `b=` is not defined, then the default range is `b=F~S,s~f`.
- `d=domain`: The domain name containing the DNS TXT record for the SEAL public key.
- `uid=string`. (Optional) This specifies an optional **u**nique **i**dentifier, such as a UUID or date. The value is case-sensitive. The uid permits different users at a domain to have many different keys. The default value is an empty string: `uid=""`.
- `id=text`: (Optional) A unique identifier identifying the signer's account or identity at the signing domain. When present, this impacts the signature generation.
- `sf=base64` (Optional) The **s**ignature **f**ormat. Possible values:
  - "hex": The signature is stored as a two-byte hexadecimal notation using lowercase letters [0-9a-f]. Optional padding can use spaces (character 0x20) after the hexadecimal value.
  - "HEX": The signature is stored as a two-byte hexadecimal notation using uppercase letters [0-9A-F]. Optional padding can
use spaces (character 0x20) after the hexadecimal value.
  - "base64": The signature is stored as a base64-encoded value. Terminating "=" padding may be omitted. Optional padding can use spaces (character 0x20) after the base64 value. `base64` is the default encoding method if `sf=` is not specified.
  - "bin": The signature is stored as a raw binary data. This should only be used in file formats that support storing binary data. (This is also why the signature must always be the last element in the SEAL record. The binary signature ends when the SEAL record ends. Alternately, the `sl=` parameter can be used to specify the signature length.)
  - "date:" Any of the other formats may be preceded by the literal `date:`, such as `sf=date:hex`. This indicates that the signature begins with a timestamp in GMT YYYYMMDDhhmmss. The date is generated by the signer.
  - "date[0-9]:" Date with a number indicates the number of decimal points in the fraction of the date. This is used to specify subseconds. The number of decimal points identifies the accuracy of the timestamp. For example:
    - `date:` may generate "20240326164401:" for 2024-03-26 16:44:01 GMT. The accuracy is +/- 0.5 seconds.
    - `date0:` specifies no fractions and is the same as `date`.
    - `date1:` specifies one decimal point, such as "20240326164401.5" and accuracy to within 0.05 seconds.
    - `date2:` specifies one decimal point, such as "20240326164401.50" and accuracy to within 0.005 seconds.
    - `date3:` specifies one decimal point, such as "20240326164401.500" and accuracy to within 0.0005 seconds. While this `date3` example is numerically equivalent to the `date1` example, they differ in the specified accuracy.
- `sl=hex` The **s**ignature **l**ength is typically optional. It is only required if (A) padding is applied, (B) the length of a signature is variable, or (C) the length cannot be determined based on the SEAL record data storage. The length MUST include whatever padding is required for storing the computed signature. The signature algorithm (`ka=`) MUST know how to identify and handle padding. The current supported algorithm (`ka=rsa`) does not require padding and uses a fixed-length, so `sl=` is unnecessary. If the signature contains any padding characters, then this field MUST be included to prevent tampering with the padding.
- `s=signature` (Required) The computed signature for the SEAL record. This MUST be last value in the SEAL record. If in binary format, the signature must not be quoted. If in base64 or hexadecimal format, the signature may be padded with spaces.

A sample SEAL signature may look like:
```
<seal="1" b="~S,s~" d="seal.hackerfactor.com" ka="rsa" s="OQlSiu3HcMR5P2sZ8yEInAaIFPXII1gZSf1B/1OnP9tTSgz2v96GVooCZ6YOiZwLsMI+sfKqF1cOM4aqBz4ywpV+7HIEfccoCkcYhNvFFP1lQILRdA4qqUl8PKsKiA179oriob3HpXtL+WG5Tr6+C4Ajlkt628bgFH7UYAF0hM68/6DAGHBqwqk0lZmvQdH8hM18WRpTAsWqaglf0XWzfhEX+WgXGY6ilRAtSXoc5E2xo3UlxyRwkXuO8A1gGG1wyA+9NS+h5+GSXo7EPXW52ccrIgOIqd8XXHRLDqpmF4CjASYBRtgdqmDEA4UWKrYTwuQbZ4e9MJcmVSxRXJj0kw==">
```

Additional informative fields are supported in the SEAL signature, but are not required. These include informative fields and referenced source media.

### Informational Fields
Many existing metadata structures, including EXIF, IPTC, and XMP, support copyright information or descriptive comments. SEAL is not intended to replace these existing metadata structures. However, because a file may be stripped of informational metadata and then signed, SEAL does support specifying this additional information in the following fields:

- `copyright="text"`: (Optional) Copyright information.
- `info="text"`: (Optional) Textual comment information.

All text must be in UTF8. Care must be taken to ensure that the quote character is not included in the text value.

### Referencing Source Media
A signed file may not be the source media file. It may be derivation that has been re-encoded, resized, cropped, or have other alterations. For example, many web sites and content delivery services automatically re-encode media for users to download. Examples of common transformations include:
- Converting between file formats, such as PNG, JPEG, and WebP. Similarly, video hosting sites often transcode the video based on the recipient's supported format. As an example, if the file is in a DIVX format but the client only supports MP4, then servers will typically re-encode the file to MP4 before sending it to the client.
- Rescaling, cropping, or rotating the media. For example, if the image is 4000x3000 but the user's mobile device only supports 800x600, then transferring the full size results is a slower download rate and requires more resources from the client's device to store and scale the media. Instead, the server may scale the image smaller first, resulting in faster download speeds, faster client performance, and a better user experience.
- Some metadata, such as EXIF and XMP, are informative but provide no rendering instructions. This can translate into wasted bandwidth since the client typically ignores the data. Many media hosting sites automatically remove optional metadata in order to reduce bandwidth requirements.

If a file is transformed before downloading, then any existing SEAL signature becomes invalid. This is because transformations require altering the file after being signed. To address this problem, a SEAL signature can be applied after the transformation and may include the following fields that reference the source media:

- `src="url"`: (Optional) A URL pointing to the unaltered (pre-transformation) **s**ou**rc** media. Spaces, quotes or invalid characters in the URL MUST be encoded as specified in RFC3986.
- `srcd=digest`: (Optional) The **s**ou**rc**e file **d**igest permits confirming the source file's contents.
- `srca=sha256:base64`: (Optional) The digest **a**lgorithm and encoding for the source file.
  - When `srca` is specified, `srcd` MUST be present.
  - The default digest algorithm is sha256, However any digest algorithm supported by the `da` parameter can be used here.
  - The default digest encoding is `base64`. Other supported encoding include `HEX` and `hex` (see the `sf` parameter for details).

A sample SEAL signature with source reference may look like:
```
seal="1" b="~S,s~" d="seal.hackerfactor.com" ka="rsa" srca="sha256:hex" srcd="7d37530efc241eb3f19d202ebed76e284297427a2f5138e49f4d0c302d109381" src="https://signmydata.com/?logo=seal-fingerprint.jpeg" s="OQlSiu3HcMR5P2sZ8yEInAaIFPXII1gZSf1B/1OnP9tTSgz2v96GVooCZ6YOiZwLsMI+sfKqF1cOM4aqBz4ywpV+7HIEfccoCkcYhNvFFP1lQILRdA4qqUl8PKsKiA179oriob3HpXtL+WG5Tr6+C4Ajlkt628bgFH7UYAF0hM68/6DAGHBqwqk0lZmvQdH8hM18WRpTAsWqaglf0XWzfhEX+WgXGY6ilRAtSXoc5E2xo3UlxyRwkXuO8A1gGG1wyA+9NS+h5+GSXo7EPXW52ccrIgOIqd8XXHRLDqpmF4CjASYBRtgdqmDEA4UWKrYTwuQbZ4e9MJcmVSxRXJj0kw=="
```

When referencing source media:
- The `src` URL should reference the original (pre-transformed) media. This source file may be a normal media file, a media file with other authenticating information, or a file signed with SEAL. When possible, the URL should be a direct link to the media file. However, for services with dynamic content (e.g., a video hosting site like YouTube), the URL may reference a web page containing the media.
- A SEAL-signed file with `src` MUST NOT reference another file with a SEAL-signed `src` record. This is because a transformation of a transformed file is still based on the same source media and should reference the same source file. It is invalid to create a chain of files using `src` fields.
- Web services may change URLs over time. The `src` field is not a guarantee that the file currently exists at that URL at the time of validation. Instead, it denotes that the URL was valid at the time of the signing.
- The `srcd` field contains the digest of the source media. If a source file is identified (either at the `src` URL or through some other means), then the digest permits confirming the source media.
- The source digest (`srcd`) may be provided even if the source location (`src`) is unspecified. 

## Local Signing
Local signing permits a user to directly sign their media. This does not require any third-party services.

The encoding workflow for local signing is as follows:

![SEAL basic signing workflow](/docs/workflow-sign1.png)

1. The byte range (`b=`) is parsed to identify the values to be sent to the digest hashing function.
2. The digest algorithm (`da=`) is used to generate a digest of the file.
3. The private key is used with the key algorithm (`ka=`) to encrypt the digest, resulting in a signature.
4. The signature is stored in the `s=` value.

The use of a date format or `id=` field allows the signer to generate a timestamp and authenticate a user account. This approach uses a double-digest:

![SEAL basic signing workflow](/docs/workflow-sign2.png)

1. The byte range (`b=`) is parsed to identify the values to be sent to the digest hashing function.
2. The digest algorithm (`da=`) is used to generate a first digest of the file.
3. If there is an identifier specified in `id=`, then the value is prepended to the first digest along with a ":" literal.
4. If there is a date format specified in `sf=`, then a timestamp with the correct number of decimal places is generated. This is prepended to the first digest along with a ":" literal. For example, `id=user123 fs=date2:hex` will generate the bytes "20240326164401.50:user123:*digest1*"
5. The combined data is sent though another digest computation (`da=`) to generate the second digest.
6. The private key is used with the key algorithm (`ka=`) to encrypt the digest, resulting in a signature.
7. If a date range was used, then the literal date range is prepended to the signature along with a ":" literal.
8. The complete signature string is stored in the `s=` value.  For example, `fs=date2:hex` might yield `s=20240326164401.50:*signature-in-hex*`.

## Remote Signing
The signer does not need to be the same system that is populating the SEAL record. For example, if the user does not have a domain name, then they may register an account at a signing service and use that service for trusted remote signing.

The remote signer DOES NOT require a copy of the file! This provides content privacy. The remote signer only needs:
- `seal=1` (Required) This specifies a SEAL record for version 1 (the current version). This MUST match the DNS entry for the public key.
- `ka=rsa` (Required) The **k**ey **a**lgorithm. This must match the algorithm used to generate the key. This MUST match the DNS entry for the public key.
- `kv=1` (Optional) This specifies the **k**ey **v**ersion, in case you update the keys. When not specified, the default value is "1". This MUST match the DNS entry for the public key.
- `uid=string`. (Optional) This specifies an optional **u**nique **i**dentifier, such as a UUID or date. This MUST match the DNS entry for the public key.
- `da=sha256` (Optional) The **d**igest **a**lgorithm. This MUST match the `da=` entry in the metadata.
- `id=text` (Optional) This specifies user user's identity at the signing service. This MUST match the `id=` entry in the metadata.
- `sf=hex` (Optional) The **s**ignature **f**ormat. This MUST match the `sf=` entry in the metadata.
- `d=*digest*`: (Required) The digest bytes using case-insensitive hex formatting. This will be converted by the signer to binary data before signing.

These specific values are needed for remotely signing. However, the fields are recommendations. For example, a web-based signing system may use alternate field names to convey the same values.

A remote signer always uses the extended signing workflow, with "Local" referring to work performed by the user's system and "Remote" identifying work performed by the remote signer.

![SEAL basic signing workflow](/docs/workflow-sign2.png)

1. (Local) The byte range (`b=`) is parsed to identify the values to be sent to the digest hashing function.
2. (Local) The digest algorithm (`da=`) is used to generate a first digest of the file. This is sent to the remote signer. This approach guarantees that the remote signer never has direct access to the signing file and provides content privacy.
3. (Remote) If there is an identifier specified in `id=`, then the value is prepended to the digest along with a ":" literal.
4. (Remote) If there is a date format specified in `sf=`, then a timestamp with the correct number of decimal places is generated. This is prepended to the first digest along with a ":" literal. For example, `id=user123 fs=date2:hex` will generate the bytes "20240326164401.50:user123:*digest*"
5. (Remote) The combined data is sent though another digest computation (`da=`) to generate the second digest.
6. (Remote) The private key is used with the key algorithm (`ka=`) to encrypt the digest, resulting in a signature.
7. (Remote) If a date range was used, then the literal date range is prepended to the signature along with a ":" literal.
8. (Remote) The completed value is returned to the local client system.  For example, `fs=date2:hex` might return a value like `20240326164401.50:*signature-in-hex*`
9. (Local) The complete value is stored in the `s=` value.

The remote signer MUST use a clock that is synchronized to an authoritative time authority.

Any invalid parameters, including attempts to sign using a revoked public key, MUST return an error to the local client.

## Validation
Validating a signature follows the same process for generating the digest, but compares the digest against the decoded signature.

For the basic validation workflow:

![SEAL basic signing workflow](/docs/workflow-validate1.png)

1. The byte range (`b=`) is parsed to identify the values to be sent to the digest hashing function.
2. The digest algorithm (`da=`) is used to generate a digest of the file.
3. Retrieve the public key from the DNS entry specified by the domain name (`d=`).
4. The public key is used with the key algorithm (`ka=`) to decrypt the signature (`s=`), resulting in a digest.
5. If the computed digest matches the decrypted digest, then the signature matches. This validates all bytes covered by the byte range (`b=`).

For the extended date and/or id information:

![SEAL basic signing workflow](/docs/workflow-validate2.png)

1. The byte range (`b=`) is parsed to identify the values to be sent to the digest hashing function.
2. The digest algorithm (`da=`) is used to generate a first digest of the file. This is sent to the remote signer.
3. If there is an identifier specified in `id=`, then the value is prepended to the digest along with a ":" literal.
4. If there is a date format specified in `sf=`, then a timestamp found in the signature (`s=`) is prepended to the digest along with a ":" literal. For example, `id=user123 fs=date2:hex` will generate the bytes "20240326164401.50:user123:*digest*"
5. The combined data is sent though another digest computation (`da=`) to generate the second digest.
6. Retrieve the public key from the DNS entry specified by the domain name (`d=`).
7. The public key is used with the key algorithm (`ka=`) to decrypt the signature (`s=`, after any "date:"), resulting in a digest.
8. If the computed digest (from step 5) matches the decrypted digest (from step 6), then the signature matches. This validates all bytes covered by the byte range (`b=`), as well as any timestamp and user id.

All verification is performed locally. There is no need to consult any external service for validating the cryptography. This also permits private verification:
- DNS is required for retrieving the public key. However, DNS is a request-forwarding service. The domain providing the key never knows who is performing the validation. (Unless you intentionally bypass the DNS relaying and contact the authoritative DNS server directly.)
- Your local DNS server only sees a request for a DNS TXT lookup for a domain name. It does not know if you want the SEAL information, DKIM, SPF, or other data that is stored in the DNS TXT fields.
- DNS requests are cached by intermediary services. Repeated DNS lookups are typically fast, and the authoritative domain system never knows when someone does repeated requests.

For offline use, the DNS record may be copied locally and used in place of an active DNS lookup. However, this usage may not notice if there is a revocation posted to DNS at a later time.

## Metadata Signature Storage Area
The SEAL metadata record may be stored in format-specific data blocks, or generic XML-like data records. Although the nomenclature may be format-specific, the basic requirements remain the same:
- The SEAL signature must be stored in a valid data section (block, chunk, atom, header, etc.).
- The SEAL record must not be split between data sections; it must be fully contained within one data section. If there are multiple data sections, then the SEAL record must be in the first data section.
- Some data sections permit nesting other media files that may contain their own SEAL records. The scope of the SEAL record (the range `F~f`) is limited to the self-contained file. A nested image's range only covers the nested image.
- The SEAL record applies to the entire file and must be stored in a data section with an unambiguous scope. For example, videos often have multiple tracks for audio, video, subtitles, etc. Each track may have their own metadata. If the SEAL record is in a track, then it is ambiguous as to whether it applies to the track or the entire file. Whereas if it's at the top-level structure, then it clearly applies to the entire file.

For format specific information, see the [Formats](/FORMATS.md) documentation.

### Appending vs Finalized
The `b=` range for determining the digest permits specifying the start and end of the file (`F`...`f`) or previous signature (`P`...`p`). This is because some file formats permit appending data, such as validating a video or audio stream.

- The first signature SHOULD reference the start of the file (`F`). This prevents prepending data. However, because the SEAL record must end with at least two bytes after the signature (`/>`), it is unlikely that data can be prepended without invalidating the next signature.
- Intermediate signatures should reference the start of the prior signature (`P`). This prevents any alterations between adjacent signatures from being undetected.
- The last signature should finalize the file by referencing the end of the file (`f`). This prevents any addition data.

This *finalizing* approach is similar to the method used for writing to CD or DVD discs. With these write-once-read-many (WORM) media sources, users can append as much as they want. However, eventually the disc must be finalized. You cannot append to a finalized disc.

Signing applications MUST scan the media for prior signatures.
- If any signature is finalized (with `b=` referencing `f`), then another signature MUST NOT be included.
- File formats that do not permit appending MUST always be finalized.
- File formats that permit appending, such as streaming media formats like AJPEG (animated jpeg; common for low-end video camera) and MPEG (for streaming video), do not require any finalized ranges. The finalized range SHOULD only be provided when the stream ends.
- Any new signature MUST be inserted *after* all previous signatures. This prevents the new signature from invalidating any previous signature.
- For appending (not finalizing), the `b=` range SHOULD reference all data up to the next appending point. At minimum, this should include the end of the SEAL record. For example, `b=P~S,s~s+6` will span from the previous signature to the current signature *and* covers 6 bytes after the end of the current signature.
- To retain integrity, appended segments MUST overlap signatures (e.g., `b=P~S`) rather than only signing the appended data (e.g., `b=p~S`). The overlap prevents a malicious user from replacing a signed data segment without detection. Non-overlapping signatures (e.g., `b=p~S`) SHOULD only be used when each appended segment is independent (e.g., hard drive sectors).

### File-specific Formats
The SEAL record always contains the wrapper "<seal seal=*version* ... />". This can appear in XMP, EXIF, or format-specific locations:

- **EXIF**: The tag 0xcea1 should store the SEAL record.
- **XMP**: The namespace should be "seal". The record can be stored as an independent tag or as an attribute:
    <seal:seal>&lt;seal ... &gt;</seal:seal>
    <seal:seal seal='&lt;seal ... &gt;'/>
    <rdf... seal:seal='&lt;seal ... &gt;'>

Other variations, such as looking for non-standard alternate namespaces (`<xmp:seal>`) or EXIF comments, should be supported by the decoder but treated as deprecated encodings.

Both EXIF and XMP are only permitted if the record can be stored as a single block. With some formats, such as JPEG, long EXIF or XMP records may be split between multiple blocks. The splitting can end up altering the signature after computing it. Moreover, if the signature (`s=`) is split between multiple blocks, then it permits insertion attacks. The entire SEAL record MUST be located in the first block. If this is not possible, then the EXIF/XMP record MUST NOT be used to store the SEAL record.

Many file formats support both global and local metadata. For example, MP4 movies often have multiple tracks (one for audio, one for video, one for subtitles, etc.). Each track can have their own metadata. Because SEAL records cover the entire file, they MUST only be stored in global fields.

Format-specific blocks include:
- **JPEG**: A custom JPEG application record can be used to store the SEAL record. It should be an APP8 or APP9 block with the label `SEAL`. (JPEG assumes that adjacent APP blocks with the same numeric identifier are continuations of the previous data. If the previous JPEG block is APP8, then SEAL should use APP9. Otherwise, it should use APP8.)
- **PNG**: A custom PNG chunk can be used to store the SEAL record. PNG chunks use capitalization to determine whether a chunk is required or safe-for-copy. Encoders SHOULD use `seAl`, where the capitalization indicates: not mandatory, public, and safe-to-copy. However, for verifying, any acceptable variation of the capitalization should be considered (SEAL, SEAl, seAl, etc.). PNG may also store the signature in a text or Exif chunk (e.g., teXt, itXt, eXIf). Any SEAL record that isn't in a PNG `seAl` chunk should be treated as non-standard.
- **ISOBMFF** (HEIC, AVIF, MP4, 3GP, etc.): A custom atomic block can be used to store the SEAL record. The atom should use `SEAL`.
- **RIFF** (WebP, AVI, WAV, etc.): A custom atomic block can be used to store the SEAL record. The atom should use `SEAL`.
- **Matroska** (WebM, WKM, WKA, etc.): This format does not have a standard definition for storing EXIF or XMP data. A custom identifier 0x05345414C (SEAL, encoded as 0x085345414C) should store the SEAL chunk.

A file may contain multiple signatures. The specified byte ranges (`b=`) should not overlap subsequent SEAL records. If a file is altered and a new SEAL record is added without removing an older one, then there are two options:
- If the first chunk uses the full file range, such as `b=~S,s~`, then the older SEAL signature should fail to validate but the second SEAL record will validate. This denotes that the subsequent signer takes responsibility (attestation) for the previous content. The signer should not sign the file if the previous SEAL record was invalid.
- If the first chunk does not cover the appended information, such as `b=~S` or `b=P~S`, then the appended information only needs to sign the appended data, such as `b=p~S`. However, nothing prevents the appended signature from covering the entire file, such as `b=~S,s~`.

### Container Formats
Many file formats act as containers.
- The container's SEAL record should cover the container, including any nested contents.
- The inner "contained" files may have their own SEAL records. For those nested files, any internal SEAL record's range is limited to the scope of the contained file and NOT the parent container.

For example, a JPEG may contain an EXIF record that can contain another JPEG as a preview image.
- The SEAL record in the preview image is limited to the contents of the preview image. The SEAL entry `b=~S,s~` specifies a range from the start of the preview image to the end of the preview image.
- The SEAL record in the containing JPEG covers the entire JPEG. The SEAL entry `b=~S,s~` covers the entire JPEG, including the contained preview image. The range `b=p~S` does NOT begin at the SEAL record in the contained preview image.

## Metadata Signature to DNS Matching
A single hostname in DNS may have multiple TXT SEAL records. When looking up a DNS record:
- The hostname must match the name specified in the metadata signature.
- The `seal=` version must match the name specified in the metadata signature.
- The `ka=` key algorithm must match the value in the metadata signature.
- The `kv=` key version must match the name specified in the metadata signature. If `kv` is not defined in the DNS or SEAL record, then it is assumed to be `kv=1`.
- The `uid=` identifier must match the `uid=` specified in the metadata signature. If `uid` is not defined in the DNS or SEAL record, then it is assumed to be an empty value (`uid=""`).

If the DNS record contains no `p=` definition, no value, or the literal value "revoked", then the signature is explicitly invalid due to revocation.

If the DNS record contains `r=` with a date, then a signature with a date is only valid if it predates the `r=` value. If the signature does not include a date, or the `r=` value is after the signature's date, then the signature is explicitly invalid due to revocation.

If the DNS record contains `r=` with an invalid date string, then the signature is explicitly invalid due to revocation.

## Considerations
The following concepts were considered while deciding on the SEAL format:
- **JSON**: The SEAL fields would work really well as a JSON structure. However, JSON does not enforce data ordering without an array. An object is a collection of unordered *field*:*value* pairs, while an ordered list does not permit named fields. Using JSON for SEAL would increase the record size and complexity.
- **JUMBF**: The JPEG universal metadata box format (JUMBF, ISO/IEC 19566-5:2023 Part 5) is a large data structure that carries more overhead than the SEAL data would provide. Moreover, the specifications can only be acquired from ISO after paying a fee, making the format details cost prohibitive to many developers.
- **CBOR**: The Concise Binary Object Representation (RFC 8949) requires the use of binary data to store the record, which can exclude the adoption of SEAL into text-only file formats. In addition, CBOR has a complex data structure that is larger than the format used by SEAL.
- **Double Digest**: Why are the date and id encoded separately from the file digest? If the user supplies the data, date, and identity, then a malicious user can forge an identity or date. However, if the date is set by an unrelated external provider (remote signing), then it restricts the ability to backdate or postdate the timestamp. In addition, if the identity is verified by an external provider, then it cannot be forged. Most hash algorithms (sha, md5, etc.) have three functions: initialize, add data, and finalize. Unfortunately, the finalize step cannot be easily transmitted to a remote system for digest generation. This leaves two alternatives: (A) send the entire file to the external parts (a privacy violation), or (B) send the digest and let the external service generate a second level digest that includes the identity and time stamp.
- **Encrypt vs Double Digest**: Why do the double-digest when I can just encrypt the date and id along with the digest? Two reasons:
  1. If I double-digest and include the `date:id:` in the signature field, then I can see the date even if I can't decrypt the data (e.g., if I'm temporarily offline or unable to get to DNS). This doesn't validate the date, but seeing it is better than nothing.
  2. Encrypting them would be better. However, it has the possibility of changing the signature length. If the signature isn't static, then the client (who is inserting the signature) may not have allocated the correct data size.
- **Double Encryption**: When using a remote signer, why not encrypt the data and have the remote signer also encrypt the data? This is a great solution for using an external notary for witnessing a signature. However, it adds more complexity:
  - There needs to be a way to specify multiple signing domains: one for each signer. The `d=` parameter only supports one domain and overloading it with a list of domains becomes overly complicated.
  - It would require the client to have their own domain for signing. However, the purpose of the external signer is to provide a signature even when the client doesn't have their own domain.
  - If we have two signers, then what about three? Or *n* signers? One DNS signer is fine. Multiple DNS queries for public keys could be used to subtly triangulate someone who is validating a signature, which is a breach of privacy. And if *n* is large, it could be used as the basis for a denial-of-service attack.

