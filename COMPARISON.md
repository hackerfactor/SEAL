# Verifiable Identity using Distributed Authentication (VIDA): Comparison
Version 1, 2-April-2024

There are a variety of solutions that attempt to address the authentication and provenance problem.

The basic problem is based on "trust".
- **Content**: We _assume_ that the content is unaltered or has acceptable alterations, and that it is not misrepresented. Unfortunately, what is considered an "acceptable alteration" varies by industry and audience; there is no standard for an "acceptable" amount of alteration.
- **Metadata**: Metadata is stored inside the file but is not required for rendering the file. This is information about how the file was created and handled. We _trust_ that the metadata accurately reflects the content. Ultimately, this relies on the _honesty_ of the person inserting the metadata.
- **Validation**: We _trust_ that someone distributing (or redistributing) the content actually validated it first. However, this is _not required_ and rarely the case.
- **Bad Actors**: We _trust_ that any bad actions will be noticed, that there is somewhere to report it, and that there is someone who can do something about it.

Every place you see _trust_, _assume_, _honesty_, and _not required_ is a vulnerable foothold for exploitation. This is how a malicious actor can create fake content, false attribution, and misrepresented content. This reliance on _trust_ is the crux of the problem.

There are a variety of solutions for addressing this problem space.

## Solution #1: Trust but Verify
Today's forensic examiners rely on tools, techniques, and methods to evaluate the content and metadata. They look for artifacts and inconsistencies that denote alterations. This is both a manual process that requires training since nearly every situation has special case considerations.

Even with all of the other solutions identified in this document, the "Trust but Verify" solution is always required.

## Solution #2: IPTC Labeling
The International Press Telecommunications Council ([IPTC](https://iptc.org/)) created a metadata format (also called [IPTC](https://iptc.org/standards/photo-metadata/iptc-standard/)) that records attribution information. This format is primarily used by news outlets to identify sources for media.

The IPTC metadata also defines a [digital source type](https://cv.iptc.org/newscodes/digitalsourcetype). This is a simplified vocabulary for identifying how the media was created. It includes terms like "digitalCapture" for an original capture from a digital camera, and "trainedAlgorithmicMedia" for media that was created algorithmically using a model and derived sample content.

The IPTC labeling is vulnerable to alterations and false attribution. However, it does not add any addition _trust_ requirements and the content can often be readily validated by a forensic examiner.

## Solution #3: Blockchain
There are a variety of companies who have proposed blockchain-based solutions. The basic concept is to sign the meida and associated the signature and provenance metadata with a blockchain entry.

Unfortunately, they all suffer from the same fundamental limitations:
- **Scale**: On any given day, Facebook, Instagram, Google, and other large providers handle millions of photos, videos, documents, and other kinds of media. If every file was digitally signed, then there is no blockchain solution that could handle the volume of signatures. Most blockchain solutions restrict their scope to their own registered customers. But that openly assumes that their solution will never be widely adopted.
- **Cost**: Every blockchain transaction must be verified. This requires significant computational resources that are not free. Someone must pay for these resources.
- **Growth**: When a blockchain is new, it can be relatively easy for someone to download the entire blockchain and validate it. However, as the blockchain is used, it continues to grow. The bitcoin blockchain is over 15 years old. Downloading the entire blockchain can take days or weeks to complete, and months or years to fully validate _before_ you can trust the entire chain and use it. (With bitcoin, new users often _trust_ other providers to validate and only download a portion of the entire chain.)
- **Poisoning**: Anything can be stored in a public blockchain. Back in 2018, researchers discovered that someone had [embedded child exploitation material](https://www.theguardian.com/technology/2018/mar/20/child-abuse-imagery-bitcoin-blockchain-illegal-content) in the bitcoin blockchain! Anyone who downloads the entire blockchain is technically in possession of child exploitation material. (A felony in the United States and illegal in many other countries.) The only solution is to restrict who can add content to the blockchain. However, restricting blockchain access defeats the purpose of using a public blockchain.

In addition to the fundamental limitations, most solutions include additional limtations:
- **Proprietary**: Even if the blockchain is public, the signature and metadata may use proprietary formats. This makes the vendor critical-path to any signing or validation. This deters widespread adoption and introduces privacy issues; as a critical path, a proprietary solution permits the vendor to track who is signing a file and who is validating the signature.

## Solution #4: C2PA
The Coalition for Content Provenance and Authentication ([C2PA](https://c2pa.org/)) is an alliance of large technology companies who are attempting to specify a specification for recording provenance and authenticity.

The general C2PA approach adds an additional metadata block to the file. This block includes a cryptographic signature and information about the file's provenance (where it came from). Unfortunately, even with the support of Adobe, Microsoft, Google, Intel, and other tech giants, it contains fundamental problems that effectively neutralize any potential benefits from this solution. These limitations include:
- **Unverified**: As with the basic problem, the media's content and initial metadata is not verified. The C2PA specification explicitly says that verifying the information is _not required_. Putting a strong cryptographic signature on top of untrusted data does not make the data more trustworthy.
- **Opaque**: The entire C2PA specification has been developed in private. The public is only allowed to see the specification after it is formally released. There is no discussion or insights into how their decisions are made. As a result, many of their implementation requirements appear overly complicated for no disclosed reason. C2PA and it's associated organization, CAI, provide source code in public github repositories, such as [c2patool](https://github.com/contentauth/c2patool), [c2pa-rs](https://github.com/contentauth/c2pa-rs), and the [C2PA specifications](https://github.com/c2pa-org/specifications). The github issues for these projects are often closed without resolution, transfer bugs from the public github to Adobe's private internal bug tracking system for development, and include issues submitted by Adobe developers without any details or descriptions. Although they use public github repositories, all development is opaque.
- **Complexity**: Implementing EXIF metadata requires one data structure: EXIF. Implementing IPTC also requires one data structure: IPTC. However, implementing C2PA requires JUMBF, CBOR, XMP, JSON, and X.509. The standalone "c2patool" (for inserting, viewing, and validating C2PA metadata) compiles to over 16 megabytes in size and has hundreds of external dependencies. Many of these data structures provide the same basic functionality, for example, XMP, JSON, JUMBF, and CBOR are structures for storing nested field:value sets. (Due to the opaque decision making process, it is unclear why C2PA chose to require a variety of equivalent data structures.) The more complexity and dependencies a solution has, the more surface area it has for an attacker to potentially compromise. While we _trust_ that these dependencies do not pose a security risk, given the scope of C2PA's solution, this trust may be misplaced.
- **C2PA Metadata**: C2PA replicates many of the metadata values found in EXIF, IPTC, and other widely-adopted structures into the C2PA data structure. We _trust_ that it accurately reflects the content. However, this is dependent on the _honesty_ of the person inserting the metadata.
- **Certificate**: C2PA uses X.509 certificates for digitally signing. While X.509 certificates are typically used for HTTPS encryption, signing certificates are not the same as TLS certificates. X.509 includes some significant concerns:
  - **Owner**: TLS certificates are expected to be linked to a domain name. In order to acquire the cert, you are expected to validate ownership of the domain. Signing certificates do not have this same requirement. We _trust_ that the certificate is issued to the person or system that is performing the signing. This _trust_ enables impersonators to sign a document on someone else's behalf.
  - **Cost**: Let's Encrypt provides free TLS certificates, but they cannot be used for signing. On 19-Dec-2023, Adobe disabled the ability to use self-signed certificates. This means that you must pay to have a valid signing certificate. (The cost is often over $200USD per year.)
  - **Permit List**: In December 2023, Adobe announced that they were switching to a "known certificate" list. However, there are [no details](https://github.com/c2pa-org/specifications/issues/50) about these requirements, who can access the list, how to register with the list, what companies manage the list, or how the list is vetted. Moreover, this appears to make the solution vendor-centric; validation cannot be performed without consulting the vendor-specific "known certificate" list.
  - **Expiration**: X.509 certificates include an expiration date. The C2PA specification explicitly ignores this expiration date. This permits a malicious user to backdate (or postdate) a signature.
  - **Revocation**: The X.509 standard explicitly requires revocation of known-compromised certificates. The C2PA specification explicitly omits revocation and permits the use of revoked certiifates.
- **Signer**: We _trust_ that the signer validated the metadata and content before signing. However, the C2PA specification explicitly notes that this not required. We also _trust_ that the new signers did not alter any previous C2PA metadata from included content.
- **Validation**: We _trust_ that the signature covers the entire file. However, this is explicitly not required. This directly impacts the "tamper evidence" portion of C2PA detects tampering. We _trust_ that it will detect tampering, but it is trivial to bypass detection.
- **Size**: A typical C2PA metadata entry contains JUMBF and CBOR data structures containing hundreds of bytes. It also contains a minimum of one X.509 certificate (over 1000 bytes) and potentially multiple X.509 certificates. Even without embedded copies of dependent media, the C2PA metadata is often over 10 kilobytes and sometimes is larger than the visible media content itself. When providing a media oriented service (e.g., Facebook, Instagram, Imgur, etc.), these extra bytes directly translated into added costs for storage and bandwidth. Excessively large metadata records are often removed by web serivces in order to reduce the assocaited costs and latency.
- **Privacy**: C2PA permits detaching the C2PA metadata from the file and storing it on a web site (the detached data is called a _sidecar_). The owner of the web site can track every request to validate the C2PA metadata. This permits creating a social graph that tracks creators and validators.
- **Patent Burdened**: C2PA has dozens (hundreds?) of patents around the technology. The C2PA [patent policy](https://c2pa.org/specifications/specifications/1.3/specs/C2PA_Specification.html#_patent_policy) only references the W3C patent model. The W3C patent model permits the use of licensed patents. C2PA does provide the option for patent exclusion, but none of the patent holders have excluded their patents. At any time, C2PA may change to a fee-based solution due to patents.
- **Reviews**: The C2PA specification says that the design was reviewed by experts. However, these experts are unnamed (anonymous). C2PA has also been using press releases to promote their solution, enabling media outlets to review it without actually reviewing it. We _assume_ that the hundreds of companies and thousands of reviewers actually reviewed it and any concers were resolved. However, given all of the serious security flaws with the current specification, this _trust_ is likely misplaced.

As mentioned earlier: every place you see _trust_, _assume_, _honesty_, and _not required_ is a vulnerable foothold for exploitation. C2PA _attempts_ to address many design goals, but _fails_ to resolve any of them. Moreover, it gives a false sense of _trust_ based on peer pressure, lots of corporate support, and technical jargon like "cryptography", "authenticity", "provenance", and "tamper evident".

- Without C2PA, we rely on technical experts to evaluate the content and metadata. The expert only needs to prove that there is an inconsistency in order to identify tampering.
- With C2PA, it is not enough to identify a problem in the metadata or content. The expert must also show that the signature is untrusted, the "tamper evident" failed, and the hundreds of companies that claim C2PA works properly are **wrong**. That is a serious uphill battle.
Trusting C2PA is _worse_ than not having C2PA.

## Solution #5: VIDA
VIDA is an open solution for assigning attribution with authentication to media. It can be easily applied to pictures, audio files, videos, documents, and other file formats. It provides:
- **Attribution**: The signature is attributed to a user or domain name.
- **Validation**: The signature is cryptographically signed and covers the bytes in the file. If the file is altered after signing, then the signature will not match.
- **Authentication**: The strong cryptographic signature ensures that the signature is authentic. A malicious user cannot falsely attribute a signature to someone else.
- **Provenance**: Provenance identifies how a file was created or handled. While VIDA does not directly include this information, other common metadata formats, including EXIF, IPTC, and XMP readily provide this type of detail. VIDA permits signing the existing provenance information, preventing it from being altered after it was digitally signed.
- **Notarized**: VIDA supports using third-party signatures that notarize when a file was digitally signed.
- **Nonrepudiation**: A valid signature can only be provided by the signer. The signer cannot claim that their private key did not create the signature. This prevents false denials.
- **Decentralization**: There is no single vendor who is critical path to the signing or validation process. The public keys are stored in DNS, which is a decentralized service.
- **Privacy**: The public keys are stored in DNS, which uses request relaying. Even if you run the authoritative DNS server, most DNS requests are relayed; the authoritative DNS server does not know the IP address of anyone who is trying to validate a signature. Moreover, due to DNS caching, the authoritative server may not know each time someone tries to authenticate a signature.
- **Revocation**: If a private key is compromised, it can be revoked by updating the DNS entry.
- **Small**: Most signatures are smaller than 500 bytes.
- **Free**: There is no added cost required to implement or use this solution. VIDA does require a domain name for storing the public key(s). However, that is an existing expense for doing work on the internet. For users who do not have a domain name, we expect new vendors to support user validation with signatures.
- **Transparency**: All issues are managed on the public github repository all design decisions are openly discussed.

What VIDA does **not** provide:
- **Content Verification**: The visual, audio, textual, and existing metadata content is not validated by VIDA. VIDA only ensures that the content is not tampered after being signed, and the signature is not falsely attributed.
- **Historical Information**: The pedigree of the file, such as the included components or versions, are not recorded by VIDA. VIDA only provides the last known signature. Other metadata formats, including EXIF, XMP, and MPF, are often used to record historical information. (VIDA does not replicate the work of other existing metadata formats.)

