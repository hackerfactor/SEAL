# SEAL Format Considerations
Different file formats support different storage mechanisms. *Where* the SEAL record is stored is format specific.

Many common data formats divide the structures into sections.
- JPEG calls these sections 'blocks'.
- PNG calls these sections 'chunks'.
- RIFF (WebP, WebM, WAV, , etc.) calls these sections 'atoms'.
- BMFF (MP4, MOV, HEIC, HEIF, etc.) calls these sections 'atoms'.
- Some file formats, like PPM and ZIP, only have headers and data.
- PDF uses PDF comments.
- XML (XML, SVG, HTML) support document declarations.

Although the nomenclature is format-specific, the basic concept is the same:
- The SEAL signature must be stored in a valid data section (block, chunk, atom, header, etc.).
- The SEAL record must not be split between data sections; it must be fully contained within one data section. If there are multiple data sections, then the SEAL record must be in the first data section.
- Some data sections permit nesting other media files that may contain their own SEAL records. The scope of the SEAL record (the range `F~f`) is limited to the self-contained file. A nested image's range only covers the nested image.
- The SEAL record applies to the entire file and must be stored in a data section with an unambiguous scope. For example:
  - Videos often have multiple tracks for audio, video, subtitles, etc. Each track may have their own metadata. If the SEAL record is in a track, then it is ambiguous as to whether it applies to the track or the entire file. Whereas if it's at the top-level structure, then it clearly applies to the entire file.
  - PDF may have objects containing metadata. The scope of a PDF object is dependent on the parent object that links to it. The SEAL record must be stored in a location that has global scope.

Processing SEAL records requires parsing the high-level file format. However, it MUST NOT require parsing nested data blocks or having a detailed understanding of the containing structure. For example:
- Many of these storage areas support scanning the data section's range for a SEAL record using a regular expression: `@<seal seal=[0-9]+[^>]\* s=[^>]+/>@`
- JPEG APP blocks may contained nested images, such as preview pictures, thumbnail images, or depth maps. Each of these nested images may have their own SEAL signature than only spans the scope of the individual nested image. A JPEG parser must ensure that it does not confused a nested image's SEAL signature with the parent image's signature.

## EXIF
EXIF is a common metadata structure found in many different file formats. It uses two-byte identifiers ("tag") with offsets to the identifier's data within the EXIF block. For example:
- Tag 0x9286 defines a user comment.
- Tag 0xfffe defines a generic comment.

EXIF has both well-defined tags and non-standard tags. Since EXIF does not have a specific numeric code for SEAL records, we will use the non-standard tag 0xcea1. (The tag looks like it spells "ceal" or "seal".) This tag may conflict with other non-standard tags. However, the value of the tag MUST be a SEAL record (`<seal .../>`) and should avoid any ambiguity.

## XML, SVG, and HTML
XML formats, including SVG and HTML, support [document definitions](https://www.w3.org/TR/xml/#sec-prolog-dtd). These are tags that begin with `<!`. Definition tags are global in scope and define properties about the document. By definition, unknown properties can be ignored by the document parser; adding a SEAL record to an XML document will not alter the schema or corrupt the file format. A sample HTML document with a SEAL record may look like:
```html
<!DOCTYPE html>
<!SEAL seal="1" ... s="abcd1234"/>
<html lang="en">
 <head><meta charset="utf-8"><title>my website</title></head>
 <body><h1>This is a website</h1></body>
</html>
```
- Per XML specifications, tag name is case-insensitive. (`<!SEAL` or `<!seal` are acceptable.)
- Self-closing tag is optional. It can end with `/>` or `>`.

Although document declarations may appear anywhere in the document, they SHOULD appear before the root tag (`<html>`, `<svg>`, etc.).

## XMP
XMP is a common metadata structure found in many different file formats. XMP data uses an XML file format structure. SEAL supports two types of XMP records:
- `<seal .../>`
- `<\*:seal> ... </\*:seal>`, where '\*' denotes a namespace, such as `<seal:seal>` or `<xmp:seal>`.

In each case, the parameters for the tag includes the pre-defined fields from the specification. (E.g., `<seal:seal seal=1 b=F~S,s~f d=domain s=*signature* />` or `<seal:seal>seal=1 b=F~S,s~f d=domain s=*signature*</seal:seal>`)

The default namespace is `seal`. However, decoders should scan any `\*:seal` record.

Some XMP records can contain nested media. (These are usually base64-encoded files.) The nested media may contain its own SEAL signatures. Those signatures are limited to the scope of the nested media. Generic validators that do not know about the specifics of the XMP processing are not required to evaluate XMP's nested media.

## PNG
PNG stores data in 'chunks'. Each chunk includes:
- Four byte type. These are typically encoded characters:
  - The first letter uses capitalization to denote a critical chunk (required for rendering). Ancillary blocks use lowercase.
  - The second letter denotes whether the chunk is public/registered (uppercase) or private (lowercase).
  - The third position is reserved and is always a capital letter.
  - The fourth character denotes whether the chunk is unsafe to copy (uppercase) or safe to copy (lowercase).
- Four byte length. The maximum chunk size is 4 gigabytes. Each PNG chunk is self-contained; data cannot be split between subsequent chunks. (The exception are the IDAT and fDAT chunks that store the image stream.)
- The data.
- Four byte checksum. The checksum must be computed after the data and is used to validate the data.

Each chunk includes a checksum, so SEAL's `b=` byte range must exclude the chunk's checksum. A byte range for PNG might look like `b=F~S,S~s+4,s+8~f` to skip over PNG's 4-byte chunk checksum that comes after the signature.

The SEAL signature can be stored in a variety of chunks:
- A text chunk (teXt, teXT, tEXt, tEXT, etc.). These may contain actual text or complex data such as an XMP record. For processing, SEAL looks for any substring that could indicate a SEAL signature. It should match the regular expression: `@<seal seal=[0-9]+[^>]\* s=[^>]+/>@`.
- An internationalized text chunk (itXt, iTXt, etc.) that is not multi-byte or compressed.
- SEAL data cannot be stored in any compressed chunk (e.g., iTXt with optional compression enabled, zTXt, zTXT). This is because the compression will change the data covered by the SEAL signature.
- A SEAL-specific chunk (sEAl, sEAL, seAl, etc.).

The PNG chunk type may specify that the chunk's contents can be safely copied during a re-encoding. Re-encoding a PNG will likely invalidate the SEAL signature. However, this is supposed since an invalid signature explicitly denotes that the file has been altered (re-encoded) after signing.

## JPEG
JPEG stores data in blocks that begin with a two-byte tag (`*tag* & 0xffc0 = 0xffc0`). For example, a JPEG begins with 0xffd8 for the start of file, may include EXIF data in an 0xffe1 "APP1" block, etc. Although there are common conventions that recommend putting EXIF and XMP records in APP1 blocks, there is no reason for them to exist in other APP blocks (APP0 through APP14).
- Tags 0xffd8 (start of image) and 0xffd9 (end of image) do not have a length.
- All other tags have a two-byte length that includes its own bytes. (The minimum length is "2".)
- After each JPEG block should be another JPEG block. If the bytes after the end of the JPEG block do not begin with a valid tag, then the bytes are skipped until a valid tag is found.

By itself, JPEG does not have a dedicated comment field. (APP14 0xfffe is earmarked as a comment block but is typically treated as any other APP block. Some applications, including an "Adobe" metadata block, store binary data in APP14.) Instead, each application has their down data type and preferred APP block.

The maximum JPEG APP block data size is 65,533 bytes. Data that is larger than one block size may be split between adjacent APP blocks. (E.g., APP1 followed by another APP1.) However, the SEAL record MUST NOT be split between JPEG blocks. Otherwise, it is possible for an attacker to insert another APP block, potentially changing the contents without altering the signature.

For SEAL, we do not define a dedicated "SEAL" APP block. The SEAL record is typically found in APP8. However, if the previous APP was APP8, then it will use APP9 to avoid any appearance of concatenation with the previous APP block.

### JPEG: The non-standard standard
Some JPEG extensions do not follow the JPEG standard. Rather than using self-contained APP blocks, they may use pointers to absolute file positions located after the end of the file. These non-standard extensions include MPF and some MakerNotes. Adding a signature to the file will likely make the absolute pointer locations reference the wrong area. While it is desirable to fix these offsets if they are known, SEAL is *not* required to retain or correct non-standard JPEG extensions.

(The current [sealtool](https://github.com/hackerfactor/SEAL-C) implementation fixes MPF offsets during signing.)

## GIF
The GIF format only supports comments and are limited to 255 bytes per comment. GIF also supports application blocks. Application blocks use one byte to denote the length. Longer application blocks are combined by a sequence of lengths, ending when the length is zero.

For variable data fields (such as SEAL or XMP), there's a trick. The entire data gets placed in an application block. The GIF parser will read a text letter from the data as if it were a length, and it will continue parsing. At the end of the data is padding that ends with a null. For example:
```
00000300   55 44 44 44  22 22 22 11  11 11 00 00  00 21 FF 0B  UDDD"""......!..
00000310   53 45 41 4C  5F 47 49 46  31 2E 30 3C  73 65 61 6C  SEAL_GIF1.0<seal
00000320   20 73 65 61  6C 3D 22 31  22 20 6B 76  3D 22 31 22   seal="1" kv="1"
00000330   20 6B 61 3D  22 65 63 22  20 64 61 3D  22 73 68 61   ka="ec" da="sha
00000340   32 35 36 22  20 73 66 3D  22 62 61 73  65 36 34 22  256" sf="base64"
00000350   20 69 6E 66  6F 3D 22 53  61 6D 70 6C  65 20 43 6F   info="Sample Co
00000360   6D 6D 65 6E  74 22 20 63  6F 70 79 72  69 67 68 74  mment" copyright
00000370   3D 22 53 61  6D 70 6C 65  20 43 6F 70  79 72 69 67  ="Sample Copyrig
00000380   68 74 22 20  69 64 3D 22  39 34 36 32  37 30 31 22  ht" id="9462701"
00000390   20 62 3D 22  46 7E 53 2C  73 7E 73 2B  33 2C 73 2B   b="F~S,s~s+3,s+
000003A0   37 7E 66 22  20 64 3D 22  73 69 67 6E  6D 79 64 61  7~f" d="signmyda
000003B0   74 61 2E 63  6F 6D 22 20  73 3D 22 4D  45 55 43 49  ta.com" s="MEUCI
000003C0   46 38 4D 63  6A 38 6E 59  35 45 62 39  6E 66 6B 69  F8Mcj8nY5Eb9nfki
000003D0   68 55 48 4E  62 6D 46 73  46 4C 7A 51  74 6B 73 51  hUHNbmFsFLzQtksQ
000003E0   59 62 4D 77  51 63 44 4E  69 48 67 41  69 45 41 79  YbMwQcDNiHgAiEAy
000003F0   67 76 62 74  71 79 70 38  4E 59 59 36  46 66 56 58  gvbtqyp8NYY6FfVX
00000400   4B 69 6A 49  34 2B 78 6C  62 41 63 58  64 61 71 73  KijI4+xlbAcXdaqs
00000410   63 6E 6A 30  67 78 4D 72  74 4D 3D 22  2F 3E 20 20  cnj0gxMrtM="/>
00000420   20 20 20 20  20 20 20 20  20 20 20 20  20 20 20 20
00000430   20 20 20 20  20 20 20 20  20 20 20 20  20 20 20 20
00000440   20 20 20 20  20 20 20 20  20 00 2C 00  00 00 00 08           .,.....
```
- The application block begins at 0x30d (0x21 0xff). It is 11 bytes long (0x0b). The data starts with an application name.
- The next application block length is at 0x31b and is 0x3c bytes long (the '<' character in the text data).
- Then comes the block length at 0x358 (that's 0x31b + 0x3c + 1) with a length of 0x61 ('a').
- Then comes the block length at 0x3ba with the length 0x22 (double quote).
- Then comes the block length at 0x3dd with the length 0x6b ('k').
- The final offset is 0x449 with a length of zero. Since the actual data ended early, the extra space is padding.

If the padding is unknown when writing the field, then it can be filled with a slope: 0x7f 0x7e 0x7d ... 0x02 0x01 0x00. This way, wherever the previous character lands, it will be directed to the 0x00 length. (XMP uses this trick to store large XMP records in GIF images.)

The GIF file format does not permit appending.

## PPM and PGM
Portable pixel maps (PPM) and portable gray maps (PGM) contain a simple header and then the raster map of data.
- The first line defines the type of data.
- The second line defines the image dimensions.
- The third line identifies the number of colors.
- After the third line may be lines beginning with a "#" to denote a comment.
- Then comes the binary (or text) data stream.

The SEAL record can be stored in a single comment line. For example:
```
# <seal ... s=.../>
```

The PPM and PGM formats do not support appending data.

## PDF
The PDF format stores data in objects. Objects may contain page information, structural information, comments, and more. Objects can also be unlinked.
- All PDF files begin with two comments, denoted by an initial "%PDF". The first line identifies the PDF version and the second line is a binary sequence (an unused BOM).
- All PDF files end with a comment: "%%EOF".

PDFs are parse backwards, starting from the end of the file:
1. Parsers check if the "%%EOF" exists at the end of the file.
2. Before the "%%EOF" is either a `startxref` or `trailer` record that points backwards into the file using an absolute offset.
3. Within the PDF are one or more cross-reference tables (`xref`). These may be plain text or encoded. The `xref` tables identifies the absolute position of each object.

Inserting a SEAL record before any object in the file effectively means every `xref` table, `trailer`, and `startxref` may need to be updated. And when you add in compressed xref tables, then a single change could result in a different length and even more offset updating. (This becomes a nightmare.) For this purpose, inserting a SEAL record into any existing PDF must be done after the last object.

PDF permits comments located between objects. A comment consists of the "%" character and continues to the end of the line. Technically, the initial "%PDF" and final "%%EOF" are mandatory comments. All other comments are optional. Comments are ignored when parsing. A SEAL record can be written into any optional comment in the file. E.g.:
`\%\%<seal seal=1 da=sha1 ka=rsa d="signmydata.com" s="*signature*"/>`

The SEAL record MUST NOT be encrypted or compressed. (Otherwise it cannot be validated without the password, and that defeats the purpose of validating files.)

PDF files are a very complicated structure that requires care when inserting data:
- PDF files include indexes to objects and the objects themselves, and these indexes may be compressed or encrypted. Inserting a new object or comment will alter the indexes. The indexes should be computed before inserting the signature to ensure that the indexes will not change after signing.
- A PDF object may contain nested media, just as an included JPEG, PNG, video, or audio file. Any SEAL record inside the nested media is limited in scope to the nested media.
- Some PDF encoders separate nested media's EXIF and XMP data from the stored media file. In effect, the PDF contains one object with EXIF data, one object with XMP data, and another object with the image information referenced by the EXIF and XMP data. Because encoders can separate parts from the nested media components, the SEAL record MUST NOT be stored in any PDF EXIF or XMP object.

Most PDF editors rewrite the entire file when saving. This may remove any SEAL comment. (That's fine, since the file has been changed and the previous signature would be invalid.)

A few PDF editors properly append to the file. They replace the final "%%EOF" with the new data, and include a new pointer that references the previous pointer. In this case, the PDF can support appending SEAL records.

## ISO-14496 / ISO-BMFF (MP4, 3GP, HEIC/HEIF, etc.)
ISO-14496 defines a base media file format (ISO-BMFF). This file format is used by a variety of media types, including MP4, 3GP, HEIC/HEIF, and AVIF. The file's structure contains a series of atoms. Each atom contains:
- 4-byte data length
- 4-byte atom type (typically four text characters)
- data

(There's a special case where, if the length is "1", then the atom type is followed by a 64-bit length. This is in case there is a really large data chunk.)

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

ISO-BMFF does not have a native comment atom. Instead, SEAL records should be stored in one of these areas:
- A top-level `Exif` atom. EXIF data is typically stored in an `Exif` atom. For HEIC, this usually appears under the nested tree: `meta:iinf:infe:Exif`, which is ambiguous since it may be linked to a track or subimage; it does not necessarily represent the entire file.
- A top-level XMP atom. (`mime` is used by HEIC/AVIF for storing XMP data. "`xml `" -- four characers including the space -- is defined for the JPEG-XL format, and `XMP\_` is used for police videos.) For HEIC, this usually appears nested under `meta:iinf:infe:mime`, but again, are the scope is ambiguous due to the nesting.
- The custom atom `seal`. Unknown atoms are ignored by ISO-BMFF processors. This is the preferred storage method.

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

The SEAL record must appear in a top-level chunk. It can be stored in any of the following locations:
- `SEAL` chunk: The data is the SEAL record: `<seal ... />`
- `EXIF` chunk: This data contains an EXIF record. The SEAL record may be stored as an EXIF SEAL record (0xcea1).
- `XMP ` (with space) chunk: This data contains an XMP record that may contain a SEAL entry.

## Matroska
Matroska is the format used by webm, mka, mkv, and other audio and visual formats.

This file format does not natively support EXIF, XMP, or generic comments.

Matroska uses numeric tags to denote the type of data. Unknown tags are ignored. SEAL records use 0x05345414C (spells "SEAL").

Matroska typically stores metadata before streams. Although the SEAL record (0x05345414C) may appear anywhere in the set of top-level tags, it should be listed before any metadata or stream information.

## ZIP, RAR, and TAR
Archive formats, including ZIP, RAR, and TAR support a comment field that spans the entire archive. This may include the SEAL record (`<seal ... />`). This includes open document formats like docx, pptx, and xlsx.

The SEAL signature should span the entire archive. Individual files within the archive may have their own signatures that only span the scope of each individual file.

## XML, HTML, SVG
XML-based formats, including HTML and SVG, can include a SEAL tag. The tag must be self-closing (i.e., beginning with `<seal` and ending with `/>`).

NOTE: OpenDocument files use a zip archive with XML-based contents (files in the zip archive). A SEAL record inside any of the XML-based contents only covers that single file and not the entire zip archive.

## Email
SEAL does not support email because the headers and attachments may be re-ordered. Use DKIM instead.

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

The SEAL record must be stored as a top-level element (not nested):
- The group must be 0x7661 (private attribute using the letters `va`).
- The data type must be `ST` (short text, not more than 1024 characters) or `LT` (long text). 
- The data contains the SEAL record `<seal ... />`.

## Unknown file formats
Unknown text file formats may include a SEAL record. The record must match the SEAL regular expression: `@<seal seal=[0-9]+[^>]* s=[^>]+/>@`

