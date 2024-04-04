# VIDA Specification
Version 1, 2-April-2024

The Verifiable Identity using Distributed Authentication (VIDA) is an open solution for assigning attribution with authentication to media. It can be easily applied to pictures, audio files, videos, documents, and other file formats.

This document provides the technical implementation details, including the high-level overview and low-level implementation details for local signer, local verifier, remote signer, and DNS service.

## Overview
VIDA is based on the same concepts used by DKIM ([RFC6376](https://datatracker.ietf.org/doc/html/rfc6376)) to protect email. The basic DKIM workflow is as follows:

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
- **Nonrepudiation**: Only the sender has access to the private key used for signing the email. A valid signature must come from the sender.

VIDA extends the time-tested and proven DKIM approach to any file format, including pictures, audio files, videos, and documents.

![VIDA workflow](/docs/workflow-vida.png)

With VIDA:

1. The sender generates a public/private key pair. This is only done once.
2. The private key is kept on the signing system. The public key is published in a DNS record.
3. When a file is generated, portions of the file are used to generate a hash.  The hash is cryptographically signed using the private key.  The hash components and signature are stored in the metadata.
4. Any recipient of the file can validate the signature:
   - It computes the associated hash based on the file's contents, as specified in the VIDA metadata.
   - It retrieves the public key from the DNS entry using the domain name specified by the VIDA metadata.
   - It compares the hash with the signature and public key in in order to see if the signature matches.
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
  2. Decrypt the signature using the private key.
  3. Check if the decrypted signature matches the computed digest.

The length of the signature is dependent on the length of the key. For example:
- A 512-bit RSA key pair should generate a 512-bit (64 byte) signature. (Considered 'weak' by today's standards.)
- A 1024-bit RSA key pair should generate a 1024-bit (128 byte) signature.
- A 2048-bit RSA key pair should generate a 2048-bit (256 byte) signature. (The shortest length considered 'strong' by today's standards.)

There exist other public/private key systems, such as DSA (Digital Signature Algorithm), Elliptic Curve, and Lattice-based Cryptography. However, RSA is currently widely used for digital signatures.

## Key Generation
VIDA relies on a public/private key pair. (Key creation uses the same steps DKIM uses to create keys for email signing.)
- The private key is kept with the signer and prevents anyone else from creating a forged signature. To create the private key, you can use:
```
openssl genrsa -out vida-private.pem 2048
```
This generates a private key file named "vida-private.pem". It uses 2048-bit RSA encoding.
- The public key is published in a DNS "TXT" record. To create the public key from the private key, you can use:
```
openssl rsa -in vida-private.pem -pubout -outform der 2>/dev/null -out vida-public.der
```
This creates a file named "vida-public.der" that will be shared in the DNS record.

With OpenSSL, there are different file formats, including:
- PEM: A Privacy Enhanced Mail (PEM) file contains base64 encoded data and includes BEGIN and END markers.
- DER: A Distinguished Encoding Rules (DER) file is a raw binary file. It contains the same information as a PEM file, but the DER format is smaller because it is not base64 encoded.

The public DER file contains raw binary and will need to be encoded before inserting into DNS.

### DNS Storage
The public key is stored in a DNS record. This requires access to a domain's DNS service. If you own your own domain name, then adding a DNS entry it typically provided by your domain registrar. However, you cannot add a DNS record to someone else's domain name.

The DNS entry MUST contain a series of field=value pairs. The defined fields are:
- `vida=1` (Required) This specifies a VIDA record for version 1 (the current version). This MUST be the first text in the TXT record.
- `kv=1` (Optional) This specifies the key version, in case you update the keys. When not specified, the default value is "1". The value can be any text string using the character set: [A-Za-z0-9.+/-] (letters, numbers, limited punctuation, and quotes or no spaces).
- `id=string". (Optional) This specifies an optional unique identifier, such as an account name (case-sensitive), account id, or date. This way, different users at a domain can have different keys.
- `ka=rsa` (Optional) The key algorithm. This must match the algorithm used to generate the key. By default, it is "rsa".
- `p=base64data` (Required) The base64-encoded public key. Ending "=" in the base64 encoding may be omitted. The value may include whitespace and double quotes. The `p=` parameter MUST be the last field in the DNS TXT record. For example:
  - `p="abcdefg="` is the same as `p=abcdefg` is the same as `p="abc" "defg" "="`. Double quotes and spaces are permitted because some DNS systems require breaks for long values.

For revocation:
- `r=date` The timestamp in ISO 8601 format denoting the revocation date in GMT. All signatures after this date are treated as invalid, even if the public key validates the signature. Use this when the key is revoked after a specific date. E.g., `r=2024-04-03T12:34:56` or `r=2024-04-03`.
- `p=`, `p=revoke`, or no `p=` defined. This indicates that all instances of this key are revoked. `r=` is not required when revoking all keys.

A complete DNS record may look like:
```
vida.example.com TXT vida=1 p="MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA43KBD2MSnczlYRZJqS9BPjwFK1o+obHy" "oV2II2R2jbug91wzBfUU+uJm3iYbfQWz7CJ5fbzN+OQT+sXM5PjdjCPKI/4o+h58QqBlF8JrS5ip" "QwZtJfgvd7UKYxvL4trDTeU7zqShTHygMNibn9LzcwhHQ2MJvuq76V6W6lobab56oHQjwvH3Rqqw" "YJtOpr3qt3+oIq5Ex++GD9DYuJDQce2KNhAd8zLb8Y0fzpvOEQaOTG6vgnoWJlIWFAkZaHlI5ie2" "lI3YYX5z9+j9wucCEfu3fdm7nB4VzTGyW3D7zdFyMbEbhY6jPv+0k7IWWS5QV8DpTkgPj0VU5Xxw" "ty6cGQIDAQAB"
```
or:
```
vida.example.com TXT vida=1 ka=rsa kv=1 id=Neal p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA43KBD2MSnczlYRZJqS9BPjwFK1o+obHyoV2II2R2jbug91wzBfUU+uJm3iYbfQWz7CJ5fbzN+OQT+sXM5PjdjCPKI/4o+h58QqBlF8JrS5ipQwZtJfgvd7UKYxvL4trDTeU7zqShTHygMNibn9LzcwhHQ2MJvuq76V6W6lobab56oHQjwvH3RqqwYJtOpr3qt3+oIq5Ex++GD9DYuJDQce2KNhAd8zLb8Y0fzpvOEQaOTG6vgnoWJlIWFAkZaHlI5ie2lI3YYX5z9+j9wucCEfu3fdm7nB4VzTGyW3D7zdFyMbEbhY6jPv+0k7IWWS5QV8DpTkgPj0VU5Xxwty6cGQIDAQAB
```

The hostname does *not* need to begin with "vida". It could be shorter (e.g., `example.com`) or longer (`neal.vida.example.com`). The only requirement is that it must be a valid DNS name *and* must match the domain name specified in the metadata signature.

### Metadata Signature Storage

### Metadata Signature to DNS Matching
A single hostname in DNS may have multiple TXT VIDA records. When looking up a DNS record:
- The hostname must match the name specified in the metadata signature.
- The `vida=` version must match the name specified in the metadata signature.
- The `kv=` version must match the name specified in the metadata signature. If `kv` is not defined in the DNS or VIDA signature, then it is assumed to be `kv=1`.
- The `id=` identifier must match the `id=` specified in the metadata signature. If `id` is not defined in the DNS or VIDA signature, then it is assumed to be an empty value (`id=""`).
- The `ka=` algorithm must match the value in the metadata signature. If `ka` is not defined in the DNS or VIDA signature, then it is assumed to be `ka=rsa`.

If the DNS record contains no `p=` definition, no value, or the literal value "revoked", then the signature is explicitly invalid due to revocation.

If the DNS record contains `r=` with a date, then a signature with a date is only valid if it predates the `r=` value. If the signature does not include a date, or the `r=` value is invalid, then the signature is explicitly invalid due to revocation.

