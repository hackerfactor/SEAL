# VIDA Format Considerations
Different file formats support different storage mechanisms. *Where* the VIDA record is stored is format specific.

Many common data formats divide the structures into sections.
- JPEG calls these sections 'blocks'.
- PNG calls these sections 'chunks'.
- BMFF (MP4, MOV, HEIC, HEIF, etc.) calls these sections 'atoms'.
- Some file formats, like PPM and ZIP, only have headers and data.
- PDF uses 'objects' and each object has an optional 'dictionary' and 'data'. PDF also has an initial header and ending footer.

Although the nomenclature is format-specific, the basic concept is the same:
- The VIDA signature must be stored in a valid data section (block, chunk, atom, header, etc.).
- The VIDA record must not be split between data sections; it must be fully contained within one data section.
- Some data sections permit nesting other media files that may contain their own VIDA records. The scope of the VIDA record (the range `F~f`) is limited to the self-contained file. A nested image's range only covers the nested image.

Processing VIDA records requires parsing the high-level file format. However, it MUST NOT require parsing nested data blocks or having a detailed understanding of the containing structure. For example, many of these storage areas support scanning the data section's range for a VIDA record using a regular expression: `@<vida vida=[0-9]+[^>]\* s=[^>]+/>@`

## EXIF
EXIF is a common metadata structure found in many different file formats. It uses two-byte identifiers ("tag") with offsets to the identifier's data within the EXIF block.
- Tag 0x9286 defines a user comment.
- Tag 0xfffe defines a generic comment.
A single EXIF may contain multiple comments. Any of these comment fields may contain a VIDA record: `<vida .../>`.

EXIF may also contain nested media, such as previews, thumbnails, video clips, or vendor-specific MakerNotes that may contain media. These nested content may contain their own VIDA records.
- Nested media is self-contained; the `F~f` file range refers only to the next media and not the parent container.
- A validating VIDA system should consider recursively scanning nested media, but that is not a requirement.

Generic validators that do not know about the specifics of EXIF processing may fail to validate EXIF that contains VIDA-signed nested media.

## XMP
XMP is a common metadata structure found in many different file formats. XMP data uses an XML file format structure. VIDA supports two types of XMP records:
- `<vida .../>`
- `<xmp:vida .../>`
In both cases, the parameters for the tag includes the pre-defined fields from the specification. (E.g., `<xmp:vida b=F~S,s~f d=domain s=*signature*>`)

Some XMP records can contain nested media. (These are usually base64-encoded files.) The nested media may contain its own VIDA signatures. Those signatures are limited to the scope of the nested media. Generic validators that do not know about the specifics of the XMP processing are not required to evaluate XMP's nested media.

## PNG
PNG stores data in 'chunks'. Each chunk includes:
- Four byte type. These are typically encoded characters:
  - The first letter uses capitalization to denote a critical chunk (required for rendering). Ancillary blocks use lowercase.
  - The second letter denotes whether the chunk is public/registered (uppercase) or private(lowercase).
  - The third position is reserved and is always a capital letter.
  - The fourth character denotes whether the chunk is unsafe to copy (uppercase) or safe to copy (lowercase).
- Four byte length. The maximum chunk size is 4 gigabytes. Each PNG chunk is self-contained; data cannot be split between subsequent chunks. (The exception are the IDAT and fDAT chunks that store the image stream.)
- The data.
- Four byte checksum. The checksum must be computed after the data and is used to validate the data.

Each chunk includes a checksum, so VIDA's `b=` byte range must exclude the chunk's checksum. A byte range for PNG might look like `b=F~S,S~s+4,s+8~f` to skip over PNG's 4-byte chunk checksum.

The VIDA signature can be stored in a variety of chunks:
- A text chunk (iTXt, tEXt, iTXT, and tEXT). These may contain actual text or complex data such as an XMP record. For processing, VIDA looks for any substring that could indicate a VIDA signature. It should match the regular expression: `@<vida vida=[0-9]+[^>]\* s=[^>]+/>@`
- VIDA data cannot be stored in any compressed chunk (e.g., iTXz or zTXt, zTXT). This is because the compression will change the data covered by the VIDA signature.
, EXIF (eXIf or eXIF) store EXIF data and should be processed using the EXIF rules. (VIDA can be stored in an EXIF comment field.)
- A VIDA-specific chunk (vIDa and vIDA).

The PNG chunk type may specify that the chunk's contents can be safely copied during a re-encoding. Re-encoding a PNG will likely invalidate the VIDA signature. However, this is supposed since an invalid signature explicitly denotes that the file has been altered (re-encoded) after signing.

## JPEG
JPEG stores data in blocks that begin with a two-byte tag (`*tag* & 0xffc0 = 0xffc0`). For example, a JPEG begins with 0xffd8 for the start of file, may include EXIF data in an 0xffe1 "APP1" block, etc. Although there are common conventions that recommend putting EXIF and XMP records in APP1 blocks, there is no reason for them to exist in other APP blocks (APP0 through APP14).
- Tags 0xffd8 (start of image) and 0xffd9 (end of image) do not have a length.
- All other tags have a two-byte length that includes its own bytes. (The minimum length is "2".)
- After each JPEG block should be another JPEG block. If the bytes after the end of the JPEG block do not begin with a valid tag, then the bytes are skipped until a valid tag is found.

By itself, JPEG does not have a dedicated comment field. (APP14 0xfffe is earmarked as a comment block but is typically treated as any other APP block. Some applications, including an "Adobe" metadata block, store binary data in APP14.) Instead, each application has their down data type and preferred APP block.

For VIDA, we do not define a dedicated "VIDA" APP block. Instead, VIDA signatures should be stored in existing data types; either EXIF or XMP.

The maximum JPEG APP block data size is 65,533 bytes. Data that is larger than one block size may be split between adjacent APP blocks. (E.g., APP1 followed by another APP1.) However, the VIDA record MUST NOT be split between JPEG blocks. Otherwise, it is possible for an attacker to insert another APP block, potentially changing the contents without altering the signature.

When the VIDA verifying system detects the signature offsets (range `S~s`), is should make sure the length of the signature matches the expected signature length. A signature range that differs from the expected length should immediately be rejected as a failed signature.

## GIF
The GIF format only supports comments and are limited to 255 bytes per comment.
- The VIDA signature MUST fit within a single comment block. (Elliptic curve signatures with base64 encoding are recommended since it's a smaller signature size than RSA with hex encoding.)
- GIF's XMP with a VIDA record is not permitted. GIF's XMP support uses an ugly hack where long XMP records may be split between adjacent comment records. This introduces the risk of splitting the VIDA signature across multiple GIF chunks. Because of the ugly hack, it is possible to insert data into the file if the range `S~s` splits across adjacent GIF comments. For this reason, VIDA is not supported in GIF XMP records.

## PPM and PGM
Portable pixel maps contain a simple header and then the raster map of data.
- The first line defines the type of data.
- The second line defines the image dimensions.
- The third line identifies the number of colors.
- After the third line may be lines beginning with a "#" to denote a comment.
- Then comes the binary (or text) data stream.

The VIDA record can be stored in a single comment line. For example:
```
# <vida ... s=.../>
```

## PDF
The PDF format stores data in objects. Objects may contain page information, structural information, comments, and more. Objects can also be unlinked.
- All PDF files begin with two comments, denoted by an initial "%". The first line identifies the PDF version and the second line is a binary sequence (an unused BOM). VIDA may be stored after these two lines as an initial comment field ("%"). The comment must begin with a "%" and end with a newline (\n, \r, or \r\n).
- VIDA may be stored in any object with a "vida" dictionary entry. The dictionary must contain: "/vida *value*" The value must not contain a "/" character. For example:
```
123 0 obj << /Type vida /Length *data-length-in-bytes* >>
<vida=1 b=F~S,s~f d=domainname s=... >
```

The VIDA record MUST NOT be encrypted or compressed. (Otherwise it cannot be validated without the password, and that defeats the purpose of validating files.)

PDF files are a very complicated structure that requires care when inserting data:
- PDF files include indexes to objects and the objects themselves, and these indexes may be compressed or encrypted. Inserting a new object will alter the indexes. The indexes should be computed before inserting the signature to ensure that the indexes will not change after signing.
- A PDF object may contain nested media, just as an included JPEG, PNG, video, or audio file. Any VIDA record inside the nested media is limited in scope to the nested media.
- Some PDF encoders separate nested media's EXIF and XMP data from the stored media file. In effect, the PDF contains one object with EXIF data, one object with XMP data, and another object with the image information referenced by the EXIF and XMP data. Because encoders can separate parts from the nested media components, the VIDA record MUST NOT be stored in any PDF EXIF or XMP object.

## ISO-14496 / ISO-BMFF (MP4, 3GP, HEIC/HEIF, etc.)
The ISO-BMFF file format is used by a variety of media types, including MP4, 3GP, HEIC/HEIF, and AVIF. The file's structure contains a series of atoms. Each atom contains:
- 4-byte data length
- 4-byte atom type (typically four text characters)
- data

Each atom is fully self-contained; data is not split between atoms.

Some atom types may contain additional nested atoms. These include:
- HEIC/HEIF/AVIF:
  - The `meta` top-level atom
  - `iinf`, `iref`, and `iprp` atoms nested under `meta`
  - `ifne` nested under `iinf`
- Videos:
  - The `moov` top-level atom
  - `trak` and `mdia` nested under `moov`
This is not an exhaustive list of atoms that support nesting.

ISO-BMFF does not have a native comment atom. Instead, VIDA records should be stored in one of these areas:
- EXIF data is typically stored in an `Exif` atom. For HEIC, this usually appears under the nested tree: `meta:iinf:infe:Exif`.
- XMP data is typically stored in a `mime` atom, `xml ` atom (four characters including a space) or `XMP\_` atom. (`xml ` is defined for the JPEG-XL format, `XMP\_` is used for police videos, and `mime` is typical for other file types generated by Adobe products.) For HEIC, this usually appears nested under `meta:iinf:infe:mime`.
- Unknown atoms are ignored by ISO-BMFF processors. The custom atom `vida` can store the VIDA record.

## RIFF
The Resource Interchange File Format (RIFF) is used by webp, avi, and wav. The format uses chunks and is similar to PNG (without the checksum).

The file begins with a header:
- Four-bytes type `RIFF`
- Four-bytes size of the data (should be file size - 8 bytes)
- Four-bytes format, such as `WAVE`

Following the header are the data chunks. Each chunk contains:
- Four-bytes type, which is usually text letters.
- Four-bytes data length
- Data

Only the `LIST` chunk type contains nested chunks.

The VIDA record must appear in a top-level chunk. It can be stored in any of the following locations:
- `EXIF` chunk: This data contains an EXIF record. The VIDA record may be stored as an EXIF comment.
- `XMP ` (with space) chunk: This data contains an XMP record that may contain a VIDA entry.
- `VIDA` chunk: The data is the VIDA record: `<vida ... />`

## Matroska
Matroska is the format used by webm, mka, mkv, and other audio and visual formats.

This file format does not natively support EXIF, XMP, or generic comments.

*TBD*: How to add Matroska support.

## ZIP, RAR, and TAR
Archive formats, including ZIP, RAR, and TAR support a comment field that spans the entire archive. This may include the VIDA record (`<vida ... />`). This includes open document formats like docx, pptx, and xlsx.

The VIDA signature should span the entire archive. Individual files within the archive may have their own signatures that only span the scope of each individual file.

## XML, HTML, SVG
XML-based formats, including HTML and SVG, can include a VIDA tag. The tag must be self-closing (i.e., beginning with `<vida` and ending with `/>`).

NOTE: OpenDocument files use a zip archive with XML-based contents (files in the zip archive). A VIDA record inside any of the XML-based contents only covers that single file and not the entire zip archive.

## Email
VIDA does not support email because the headers and attachments may be re-ordered. Use DKIM instead.

## DICOM
DICOM is a file format commonly used within the medical community.
- The first 128 characters (0x80) of the file are reserved for a global comment.
- The file says `DICM` at position 0x80 into the file.
- Beginning at position 0x84 are a series of elements. Each element contains
  - Two-byte group identifier. Standard data elements have even group numbers (excluding 0x0000 and 0x0002). Private elements use odd numbers (excluding 0x0001, 0x0003, 0x0005, 0x0007, and 0xffff).
  - Two-byte data type.
  - Four-byte data length.
  - The data.

The DICOM file format uses a nested set of groups, lists, and arrays, along with hundreds of pre-defined two-byte tags that identify each element's purpose. These tags are often vendor-specific.
- DICOM does not natively support EXIF, XMP, or other common data structures.
- Because of the plethora of vendor-specific tags, DICOM decoders are permitted to skip any unknown tag.

The VIDA record must be stored as a top-level element (not nested):
- The group must be 0x7661 (private attribute using the letters `va`).
- The data type must be `ST` (short text, not more than 1024 characters) or `LT` (long text). 
- The data contains the VIDA record `<vida ... />`.

## Unknown file formats
Unknown text file formats may include a VIDA record. The record must match the VIDA regular expression: `@<vida vida=[0-9]+[^>]* s=[^>]+/>@`

