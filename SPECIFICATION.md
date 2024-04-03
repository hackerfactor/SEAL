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

