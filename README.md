# Verifiable Identity using Distributed Authentication (VIDA)

VIDA is an open solution for assigning attribution with authentication to media. It can be easily applied to pictures, audio files, videos, documents, and other file formats. It provides:
- **Attribution**: The signature is attributed to a user or domain name.
- **Validation**: The signature is cryptographically signed and covers the bytes in the file. If the file is altered after signing, then the signature will not match.
- **Authentication**: The strong cryptographic signature ensures that the signature is authentic. A malicious user cannot falsely attribute a signature to someone else.
- **Nonrepudiation**: A valid signature can only be provided by the signer. The signer cannot claim that their private key did not create the signature. This prevents false denials.
- **Decentralization**: There is no single vendor who is critical path to the signing or validation process. The public keys are stored in DNS, which is a decentralized service.
- **Privacy**: The public keys are stored in DNS, which uses request relaying. Even if you run the authoritative DNS server, most DNS requests are relayed; the authoritative DNS server does not know the IP address of anyone who is trying to validate a signature. Moreover, due to DNS caching, the authoritative server may not know each time someone tries to authenticate a signature.
- **Revocation**: If a private key is compromised, it can be revoked by updating the DNS entry.
- **Small**: Most signatures are smaller than 500 bytes.
- **Free**: There is no added cost required to implement or use this solution. VIDA does require a domain name for storing the public key(s). However, that is an existing expense for doing work on the internet. For users who do not have a domain name, we expect new vendors to support user validation with signatures.

## Problem Space and Solution Approach
Whether it is AI-generated photos, deep fake videos, altered imagery (e.g., "photoshop"), or a direct-from-the-camera original, there is a growing need to provide proper attribution to media.

This problem is very similar to the spam problem with email. By itself email (the Simple Mail Transport Protocol, SMTP, [RFC5321](https://datatracker.ietf.org/doc/html/rfc5321) and [RFC5322](https://datatracker.ietf.org/doc/html/rfc5322)) is trivial to forge. This permitted spammers to send email as other users (impersonation) and users could deny having sent incriminating email messages (repudiation).

A number of solutions have been widely adopted to combat spam. These include:
- **SPF**: Sender Policy Framework [RFC7208](https://datatracker.ietf.org/doc/html/rfc7208) defines a DNS entry with a list of network addresses that can send email on behalf of a domain. This restricts who can send email as you, but it does not prevent tampering with the email message.
- **DKIM**: DomainKeys Identified Mail [RFC6376](https://datatracker.ietf.org/doc/html/rfc6376) uses a public/private key pair to digitally sign the email message. The sending mail system has a private key that signs the email. The public key is stored in the public DNS system. The SMTP email header includes a DKIM record that identifies what parts of the email message are signed, the domain that contains the public key, and the cryptographic signature. This prevents alteration to the email (validation), authentication and attribution to the sender, nonrepudiation (since only the sender has the private key, a valid signature must come from the sender), plus decentralization and private through the use of DNS.

Today, if you send email, then you are very likely using both SPF and DKIM, even if you don't realize it.

In my opinion, the anti-spam efforts got it right. VIDA applies DKIM to any file format (media), rather than being restricted to only email (as is the case with DKIM).

For the solution details, see the SPECIFICATIONS document.

