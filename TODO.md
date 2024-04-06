# Verifiable Identity using Distributed Authentication (VIDA): To-Do List
Version 1, 6-April-2024

## Required Features
Features that are needed (help from other developers would be appreciated):
- Standalone cryptography support, without the need for large dependencies such as OpenSSL or GnuTLS. OpenSSL is amazing, but over 99% of OpenSSL's functionality is not used by VIDA. Reduce the dependency overhead and vulnerability surface area by only including the required cryptographic functions. The required functionality must include:
  - Generating public and private RSA keys
  - Signing data with the private key
  - Validating a signature with the public key
  - Computing the sha256 hash. It must support multiple calls for adding more data to the hash. (Initialize, add, finalize.)
  - Computing the sha512 hash. It must support multiple calls for adding more data to the hash. (Initialize, add, finalize.)
- Create a Python package for VIDA.
- Create a Rust crate for VIDA.
- Incorporate VIDA into ExifTool. (By design, ExifTool does not include cryptography or DNS network access that is required for VIDA validation. I checked with Phil Harvey. He suggested using user-defined tags in a custom ExifTool config file.)
- Incorporate VIDA into OpenCV. (Check with them first!)
- Incorporate VIDA into Pillow. (Check with them first!)
- Incorporate VIDA into Imagemagick. (Check with them first!)
- Incorporate VIDA into ImageJ. (Check with them first!)

## Requested Features

## Completed

