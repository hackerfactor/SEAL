# Secure Evidence Attribution Label (SEAL): To-Do List
Version 1, 7-September-2024

## Required Features
Features that are needed (help from other developers would be appreciated):
- Standalone cryptography support, without the need for large dependencies such as OpenSSL or GnuTLS. OpenSSL is amazing, but over 99% of OpenSSL's functionality is not used by SEAL. Reduce the dependency overhead and vulnerability surface area by only including the required cryptographic functions. The required functionality must include:
  - Generating public and private RSA keys
  - Signing data with the private key
  - Validating a signature with the public key
  - Computing the sha256 hash. It must support multiple calls for adding more data to the hash. (Initialize, add, finalize.)
  - Computing the sha512 hash. It must support multiple calls for adding more data to the hash. (Initialize, add, finalize.)
- Create a Python package for SEAL.
- Create a Rust crate for SEAL.
- Incorporate SEAL into ExifTool. (By design, ExifTool does not include cryptography or DNS network access that is required for SEAL validation. I checked with Phil Harvey. He suggested using user-defined tags in a custom ExifTool config file.)
- Incorporate SEAL into OpenCV. (Check with them first!)
- Incorporate SEAL into Pillow. (Check with them first!)
- Incorporate SEAL into ImageMagick. (Check with them first!)
- Incorporate SEAL into ImageJ. (Check with them first!)

## Requested Features

## Completed

