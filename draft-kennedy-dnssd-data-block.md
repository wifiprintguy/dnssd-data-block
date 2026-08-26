---
title: "DNS-SD Data Block Encoding for Non-DNS Transports"
abbrev: "DNS-SD Data Block"
category: std

docname: draft-kennedy-dnssd-data-block-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
keyword:
 - dns-sd
 - service discovery
 - bluetooth low energy
 - nfc
venue:
  mail: "dnssd@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/dnssd/"

author:
 -
    fullname: Smith Kennedy
    organization:
    email: smitty.standards@gmail.com

normative:
  RFC1035:
  RFC5891:
  RFC6335:
  RFC6763:
  RFC8126:
  RFC9562:

informative:
  RFC4122:
  RFC6762:
  RFC6838:
  RFC7558:
  RFC8259:
  RFC8949:
  BT-TDS:
    title: "Transport Discovery Service 1.1"
    author:
      -
        organization: Bluetooth SIG
    date: 2020
    target: https://www.bluetooth.com/specifications/specs/transport-discovery-service-1-1/
  NFC-VERB:
    title: "Verb RTD Technical Specification"
    author:
      -
        organization: NFC Forum
    date: 2015
    seriesinfo:
      Version: "1.0"
    target: https://nfc-forum.org/build/specifications/
  IPPEVE:
    title: "PWG 5100.14-2020: IPP Everywhere v1.1"
    author:
      -
        organization: ISTO Printer Working Group
    date: 2020
    seriesinfo:
      Version: "1.1"
    target: https://ftp.pwg.org/pub/pwg/candidates/cs-ippeve11-20200515-5100.14.pdf

...

--- abstract

The DNS-SD Data Block (DDB) is a compact TLV encoded container for conveying DNS-SD service information over non-IP transports used by short-range peer-to-peer or proximity-based advertisement and discovery technologies such as the Bluetooth Low Energy Transport Discovery Service or NFC Verb NDEF Records.

--- middle

# Introduction {#intro}

DNS-based Service Discovery {{RFC6763}} is widely deployed for service advertisement on IP networks. Printers, media servers, file-sharing, and many other types of services are advertised and discovered via DNS-SD.

There are circumstances where ancillary advertisement and discovery technologies can improve service advertisement and discovery coverage. Some network environments may have non-trivial network infrastructure topologies that complicate the use of mDNS {{RFC6762}}, but that are also not provisioned with infrastructure DNS-SD. There are also peer-to-peer wireless IP networking technologies used for transient communications and could support DNS-SD services, but that suffer from a poor user experience due to a lack of a standard way to provide the DNS-SD service information before a connection has been established (what is sometimes referred to as "pre-association service discovery"). Both of these could benefit from using ancillary short range peer-to-peer or proximity focused advertisement and discovery technologies to convey DNS-SD service information.

This problem is related to, but distinct from, the scaling problem addressed by {{RFC7558}}: solutions to that problem extend DNS-SD's reach within IP networks that already have IP connectivity established. DDB instead addresses the complementary case of conveying DNS-SD service information before IP connectivity exists at all, or where none is expected to exist. In deployments where physical proximity between devices can be assumed, such as the segmented-network scenario below, DDB carried over an ancillary technology can also serve as an alternative to deploying {{RFC7558}}-class scaling solutions, sidestepping the network-segmentation problem entirely rather than solving it via Scalable DNS-SD.

Examples include the following:

* An IPP printer in an office with a segmented network topology and limited DNS-SD infrastructure advertises its IPP print service using Bluetooth Low Energy Transport Discovery Service (TDS) {{BT-TDS}} to provide service information to physically proximate clients.

* A television with an NFC interface in a hotel room advertises its media streaming services and supported carrier types using NFC Verb NDEF Records {{NFC-VERB}}. A client tapped to the TV reviews the advertised connection carriers and services and offers its user a selected optimal pathway before engaging in the process of connecting to the TV.

For each of these scenarios and the ancillary discovery technologies used, there is a need to represent DNS-SD service information in a format that is not native to the technology's transport. The standards organizations responsible for these ancillary technologies are scoped to MAC/PHY-layer specification and do not consider DNS-SD service semantics to be within their area of expertise; defining such an encoding independently in each of those venues would risk incompatible, non-interoperable results. These organizations have accordingly deferred definition of this encoding to the DNS-SD community.

This document defines the DDB format and its associated encoding and decoding rules for interoperable use. The DDB is designed to:

* Fit within the small payload sizes typical of short-range advertisement and proximity discovery technologies.

* Be self-describing and forward-compatible (unknown fields are skipped by receivers that do not understand them).

* Round-trip losslessly to and from DNS-SD SRV + TXT records for the fields it encodes.

Use of DDB in specific external registries or protocol elements may still require assignment or approval by the relevant standards body (e.g., Bluetooth SIG, NFC Forum). In defining DDB, this document supplies the DNS-SD encoding that these standards bodies have identified as needed but outside their own scope to define, so that each can reference a single interoperable IETF-defined convention rather than specifying its own.

# Conventions and Terminology

{::boilerplate bcp14-tagged}

The following terms are used:

DDB (DNS-SD Data Block):
: The compact binary encoding defined in this specification.

Service Name:
: The DNS-SD service name label pair, consisting of an Application Protocol label and a Transport Protocol label, for example "_ipp._tcp" or "_http._tcp", as defined in {{RFC6763}}, Section 7.

Service Instance Name:
: The full DNS name of a DNS-SD service instance, as defined in {{RFC6763}}, Section 4.1.

Instance Name:
: The \<Instance\> component of a Service Instance Name, as defined in {{RFC6763}}, Section 4.1.1.

TXT Data:
: The DNS-SD TXT record payload, encoded as a sequence of length-prefixed strings, each string being a UTF-8 key=value pair or a bare key, as specified in {{RFC6763}}, Section 6.

UUID:
: A Universally Unique Identifier as defined in {{RFC9562}} (formerly {{RFC4122}}), encoded as 16 octets in network byte order following the binary representation defined therein.

TLV:
: Type-Length-Value - a binary encoding scheme consisting of a type code field indicating the type, a length field indicating the length of the value field, and a value field containing the actual payload. The size of the type and length fields are typically fixed.

# DNS-SD Data Block (DDB) Format

## Applicability and Directionality

A DDB describes a service being offered by the sender; it is not a request or query for a service. Any seek/query semantics (e.g., a seek/query flag defined by the surrounding transport container's own framing) are properties of that container, not of the DDB payload itself. In particular, a DDB with an absent or empty Instance Name field (see {{instance-name}}) indicates only that no specific instance is being named, not that the sender is seeking rather than providing the service.

> OPEN ISSUE: This directionality constraint has not yet been discussed with the working group. If a future revision wants to support DDB content in a query/request role (e.g., a client advertising interest in a service type before association), this section will need to define how that role is distinguished from a service offer.

## Block Header

A DDB begins with a single-octet Version field:

~~~ ascii-art
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    Version    |               TLV Fields ...                  |
+-+-+-+-+-+-+-+-+                                               +
|                             ...                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
~~~
{: title="DDB Block Header"}

Version (1 octet):
: The version of this DDB encoding. This specification defines version 0x01. A decoder that encounters an unknown version value SHOULD treat the entire block as uninterpretable and MUST NOT attempt to parse the TLV fields.

: Additive, backward-compatible extensions SHOULD be introduced by defining new TLV Type values or related registry entries without changing the Version value. The Version value is intended for wire-format or processing changes that are not backward compatible with earlier versions.

The remainder of the DDB is a sequence of zero or more TLV fields as defined in {{tlv-field-structure}}.

## TLV Field Structure {#tlv-field-structure}

Each TLV field in a DDB has the following structure:

~~~ ascii-art
 0                   1
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+----------//----------+
|     Type      |    Length     |         Value        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+----------//----------+
~~~
{: title="TLV Field Structure"}

Type (1 octet):
: Identifies the type of the field. Values are defined in {{field-type-registry}}. Value 0xFF is reserved. Values 0x09-0xEF are reserved for future assignment. Values 0xF0-0xFE are available for private/experimental use and MUST NOT be used in interoperability contexts.

: The special value 0x00 is defined as a padding (NOP) octet. A 0x00 byte in the TLV stream is consumed as a single padding byte with no associated Length or Value fields. Encoders MUST NOT emit padding bytes except when byte-alignment is required by a specific transport framing. Decoders MUST skip 0x00 bytes and continue parsing the next TLV field.

Length (1 octet):
: The length of the Value field in octets. A Length of 0x00 indicates an empty value (valid for some field types; see individual field definitions).

: When a length of 255 octets is insufficient for a given field (notably TXT Data for rich service descriptions), the following extended-length encoding is used: if the Length octet is 0xFF, it is followed by two additional octets that carry the actual length as a 16-bit unsigned integer in network byte order, and the Value starts after those two octets. This extended form MUST NOT be used when the actual length is <= 254 octets.

Value (Length octets):
: The field value. Encoding is field-type-specific; see {{field-type-registry}}.

TLV fields MUST be processed in the order they appear. Encoders MUST NOT include more than one TLV field with the same Type value. Decoders that encounter duplicate Type values MUST use the last instance and discard earlier ones, in order to remain robust against malformed input.

An implementation MUST ignore (skip past) any TLV field whose Type it does not recognize.

## Field Type Registry {#field-type-registry}

The following Type values are defined by this specification.

| Type | Name | Required/Optional |
|---|---|---|
| 0x00 | Padding (NOP) | N/A |
| 0x01 | Service Name | Required |
| 0x02 | Instance Name | Optional |
| 0x03 | TXT Data | Optional |
| 0x04 | UUID | Optional |
| 0x05 | Domain | Optional |
| 0x06 | Port | Optional |
| 0x07 | Subtype List | Optional |
| 0x08 | Hostname | Optional |
| 0x09-0xEF | Unassigned | N/A |
| 0xF0-0xFE | Private Use | N/A |
| 0xFF | Reserved | N/A |
{: title="DDB Field Types"}

A DDB MUST include exactly one Service Name field (Type 0x01); all other field types defined in this registry are optional.

### Service Name (Type 0x01) {#service-name}

Value:
: A UTF-8 string containing the Service Name (the Application Protocol label and Transport Protocol label, joined by a period), as defined in {{RFC6763}}, Section 7. For example: "_ipp._tcp" or "_snmp._udp" or "_https._tcp". The trailing ".\<domain\>" portion (e.g., ".local") is NOT included; this is encoded separately using the Domain type (Type 0x05); see {{domain}}.

Constraints:
: Length and character constraints follow {{RFC6763}}, Section 7 and {{RFC6335}}. The string MUST NOT be null-terminated.

Example:
: The Service Name "_ipp._tcp" (9 octets) encodes as:

~~~
01 09                   ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                      ; "_ipp._tcp"
~~~

### Instance Name (Type 0x02) {#instance-name}

Value:
: A UTF-8 string containing the Instance Name, as defined in {{RFC6763}}, Section 4.1.1 (e.g., "My Color Printer"). It MUST NOT include the Service Name or Domain components.

Constraints:
: Length constraints follow {{RFC6763}}, Section 4.1.1. A Length of 0 indicates that no specific Instance Name is being advertised (e.g., for general service-name discovery without an instance identifier). The string MUST NOT be null-terminated.

: When the underlying transport already conveys an equivalent human-readable name of its own, senders MAY omit the Instance Name field and rely on that transport-native name instead, to avoid redundant encoding of the same information.

Example:
: The Instance Name "My Color Printer" (16 octets) encodes as:

~~~
02 10                   ; Type=Instance Name, Length=16
4D 79 20 43 6F 6C 6F 72 ;
20 50 72 69 6E 74 65 72 ; "My Color Printer"
~~~

### TXT Data (Type 0x03)

Value:
: The DNS-SD TXT record RDATA, verbatim, as defined in {{RFC6763}}, Section 6. Because the field's own length-prefixed string encoding is self-terminating, no separator or terminator is added; the end of the field is indicated by the TLV Length.

: Receivers that already implement DNS-SD TXT record parsing can reuse that code to parse this field directly.

: TLV extended-length encoding MUST be used if the TXT data exceeds 254 octets; see {{tlv-field-structure}}.

Constraints:
: The TXT Data field MAY represent an empty TXT record, encoded as a single string-length octet of 0x00 with a TLV Length of 0x01. This is equivalent to the DNS TXT RDATA for an empty record and is a valid encoding. When TXT metadata is present, the field contains one or more length-prefixed strings as described above. If the TXT Data field is omitted entirely, receivers MUST NOT infer any default TXT record content.

Example:
: TXT strings "txtvers=1" (9 octets), "pdl=image/pwg-raster" (20 octets), and "rp=ipp/print" (12 octets), encoded as:

~~~
03 2C                   ; Type=TXT Data, Length=44
09                      ; string length 9
74 78 74 76 65 72 73 3D ;
31                      ; "txtvers=1"
14                      ; string length 20
70 64 6C 3D 69 6D 61 67 ;
65 2F 70 77 67 2D 72 61 ;
73 74 65 72             ; "pdl=image/pwg-raster"
0C                      ; string length 12
72 70 3D 69 70 70 2F 70 ;
72 69 6E 74             ; "rp=ipp/print"
~~~

: Total: 3 + 9 + 20 + 12 = 44 octets.

### UUID (Type 0x04)

Value:
: A 128-bit (16-octet) UUID in the binary representation defined in {{RFC9562}}, stored in network byte order. The UUID SHOULD be a UUID that uniquely identifies the specific service instance or the device hosting it. As an example, for an IPP print service, the value would match the value of the "UUID" key in the DNS-SD TXT record (where it is encoded as a hyphenated ASCII UUID string).

Constraints:
: Length MUST be exactly 16 (0x10) octets. If a UUID is not available (nil UUID), omit the field rather than encoding all-zeros. (Encoding a nil UUID is valid if the sender intends to signal "UUID explicitly unknown/nil".)

Example:
: The UUID "12345678-1234-5678-1234-567812345678" encodes as:

~~~
04 10                   ; Type=UUID, Length=16
12 34 56 78 12 34 56 78 ;
12 34 56 78 12 34 56 78 ; UUID bytes
~~~

### Domain (Type 0x05) {#domain}

Value:
: A UTF-8 string containing the DNS domain in which this service is registered, without a trailing dot. For example: "local" (for mDNS) or "example.com" (for unicast DNS-SD).

Constraints:
: Optional. If absent, receivers MUST assume the domain is "local" (i.e., the service is on the local link and discoverable via mDNS). Length 1 through 253 octets.

Note:
: In the vast majority of short-range proximity scenarios, the domain is "local" and this field can be omitted to save space.

### Port (Type 0x06)

Value:
: A 2-octet unsigned integer in network byte order containing the TCP or UDP port on which the service listens. This is the same value that would appear in the SRV record for this service instance.

Constraints:
: Optional. Length MUST be exactly 2 (0x02) octets if present. For services where the port is deterministic from the Service Name (e.g., port 80 for "_http._tcp") this field may be omitted; its primary value is when the device is using a non-standard port.

### Subtype List (Type 0x07)

Value:
: A sequence of length-prefixed UTF-8 strings, one per DNS-SD subtype that the service instance supports. Each subtype string is the subtype label only (without the "_sub.\<service\>.\<domain\>" suffix), preceded by its 1-octet length. Example: the subtype "_print" (defined by IPP Everywhere {{IPPEVE}}) would be encoded as 0x0A followed by "_print" (6 octets).

Constraints:
: Optional. Included only when the service advertises one or more DNS-SD subtypes. Each individual subtype label MUST NOT exceed 63 octets.

### Hostname (Type 0x08) {#hostname}

Value:
: An ASCII string containing the fully qualified DNS hostname of the host providing the service, as it would appear in the RDATA of a DNS SRV record (target field). The hostname is the DNS name to which A or AAAA records are registered, and is the name used for TLS Server Name Indication (SNI) when connecting to the service. For example: "device-abc.example.com".

: The string is encoded in ASCII (not UTF-8) and MUST consist only of DNS label characters (letters, digits, hyphens) and period separators, per the preferred name syntax of {{RFC1035}}, Section 2.3.1. Internationalized hostnames (IDN) MUST be encoded in their ACE (ASCII-Compatible Encoding) form per {{RFC5891}}. The string MUST NOT include a trailing dot and MUST NOT be null-terminated.

Constraints:
: Optional. Length MUST be between 1 and 253 octets, consistent with the maximum length of a fully qualified domain name. If absent, the client MUST obtain the SRV target hostname via DNS-SD once an IP connection is established. Including this field is RECOMMENDED when the hostname is needed for TLS SNI certificate validation prior to IP-level name resolution.

Note:
: This field carries the SRV record target hostname only. IP address resolution still requires DNS-SD or mDNS once an IP association is available. This field does not replace the SRV record; it carries its target hostname for contexts where TLS validation metadata is beneficial pre-connection.

## Encoding Rules

1. Begin the DDB with the Version octet (0x01 for this version).

2. Encode the Service Name field (Type 0x01) first. This is the primary identifier of what kind of service is being described.

3. Encode remaining fields in no required order, though the ordering Service Name -> Instance Name -> TXT -> UUID -> others is RECOMMENDED as it places the most informative fields first, which is useful when receivers truncate parsing on constrained implementations.

4. Omit any optional field that has no value to convey, to minimize encoded size.

5. All string values are UTF-8 encoded and MUST NOT be null-terminated, except the Hostname field ({{hostname}}), which is restricted to ASCII as specified in its own field definition. String lengths in TLV Length fields count octets, not characters.

6. A single TLV field using extended-length encoding may carry a value of at most 65,535 octets, occupying 1 (Type) + 3 (0xFF escape + 2-octet extended length) + 65,535 (Value) = 65,539 octets. No absolute maximum is imposed on the total DDB length; practical transports impose far tighter limits, and implementations SHOULD reject DDBs that exceed the limit imposed by the transport in use.

## Decoding Rules and Forward Compatibility

1. Read the Version octet. If not 0x01, treat the block as uninterpretable (do not attempt TLV parsing).

2. Process TLV fields in order. For each field:

    a. Read the Type octet. If Type is 0x00, this is a padding byte; consume it and continue to the next field.

    b. Read the Length octet. If Length is 0xFF, read the next two octets as a 16-bit big-endian extended length.

    c. Read Value octets (count given by the resolved length).

    d. If the Type is known, process according to {{field-type-registry}}.

    e. If the Type is unknown, skip the Value bytes.

3. Continue until all octets of the DDB have been consumed.

4. A DDB parses successfully as long as its octets form well-formed TLV fields (including a DDB consisting of nothing but padding octets after the Version octet). However, a decoded DDB that contains no Service Name field (Type 0x01) is not a conformant DDB per {{field-type-registry}} and MUST be discarded by the receiver. Implementations MUST NOT generate a DDB lacking a Service Name field.

5. A DDB that is truncated (insufficient octets to complete the current TLV) MUST be treated as malformed; already-decoded fields MAY be used at the discretion of the application.

## DDB Payload Identity and Media Types {#ddb-payload-identity}

The canonical DDB payload is the exact octet sequence defined by {{ddb-format}}: one Version octet followed by zero or more TLV fields. A container that carries a DDB carries this payload without altering its internal format.

When a content-type identifier is needed, a DDB payload is identified by the MIME media type "application/vnd.dnssd.ddb".
{: #ddb-format}

# Relationship to DNS-SD

## Deriving DNS-SD Records from a DDB

Given a DDB and an IP address for the device, a client can synthesize the corresponding PTR, SRV, and TXT records using the owner-name conventions of {{RFC6763}}, Section 4.1, with the domain defaulting to "local" if the Domain field is absent:

PTR record:
: RDATA is the Service Instance Name, built from the Instance Name, Service Name, and domain.

SRV record:
: RDATA is \<priority\> \<weight\> \<port\> \<hostname\>, using the Port field and, if present, the Hostname field (Type 0x08) as the target. If Hostname is absent, the SRV target is not known until DNS-SD is queried after IP association.

TXT record:
: RDATA is the TXT Data field verbatim.

If the UUID field is present but the TXT Data field does not already contain a "UUID=..." key=value pair, a client SHOULD synthesize the UUID TXT record key from the binary UUID (formatted as a lowercase hyphen-separated hex string) and add it to the reconstructed TXT record.

## Constructing a DDB from DNS-SD Records

To serialize DNS-SD records into a DDB: set Version = 0x01; extract the Service Name and Instance Name from the PTR and Service Instance Name; copy the TXT record RDATA verbatim into TXT Data (extracting a "UUID" key into the UUID field, if present); copy Port from the SRV record; copy the SRV target hostname into Hostname (Type 0x08) if pre-connection hostname knowledge is needed; and omit Domain if it is "local".

## Domain Handling

The Domain field SHOULD be omitted when the domain is "local", and MUST be included otherwise (e.g., for Wide-Area DNS-SD per {{RFC6763}}, Section 11). A DDB decoder that finds no Domain field MUST assume "local".

# Examples

## Minimal Printer Service DDB

This DDB conveys only the Service Name, sufficient for a "this device provides IPP printing" beacon:

~~~
01                       ; Version = 1
01 09                    ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                       ; "_ipp._tcp"
~~~

Total: 12 octets.

## Full Printer Service DDB with TXT and UUID

A more complete DDB for an IPP printer named "Conference Room Printer" (23 UTF-8 octets):

~~~
01                       ; Version = 1

01 09                    ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                       ; "_ipp._tcp"

02 17                    ; Type=Instance Name, Length=23
43 6F 6E 66 65 72 65 6E ;
63 65 20 52 6F 6F 6D 20 ;
50 72 69 6E 74 65 72     ; "Conference Room Printer"

03 2C                    ; Type=TXT Data, Length=44
09                       ; string length 9
74 78 74 76 65 72 73 3D ;
31                       ; "txtvers=1"
14                       ; string length 20
70 64 6C 3D 69 6D 61 67 ;
65 2F 70 77 67 2D 72 61 ;
73 74 65 72              ; "pdl=image/pwg-raster"
0C                       ; string length 12
72 70 3D 69 70 70 2F 70 ;
72 69 6E 74              ; "rp=ipp/print"

04 10                    ; Type=UUID, Length=16
A1 B2 C3 D4 E5 F6 07 08 ;
89 9A AB BC CD DE EF F0  ; UUID bytes

06 02                    ; Type=Port, Length=2
02 7F                    ; port 631 (0x027F)
~~~

Total: 1 + (2+9) + (2+23) + (2+44) + (2+16) + (2+2) = 105 octets.

# Design Notes and Alternatives Considered

## Why TLV and Not CBOR or JSON

CBOR {{RFC8949}} and JSON {{RFC8259}} are both viable encoding options with good tooling. TLV was chosen for the following reasons:

* Minimal overhead per field: a simple string field costs 2 octets of overhead (Type + Length) versus CBOR's 1+ octets for a key plus 1+ octets for the string header -- comparable at small scale, but TLV's fixed 2-octet overhead per field is more predictable.

* Implementation simplicity: TLV parsing requires only arithmetic on byte arrays; no recursive descent or schema lookup is needed. This supports implementation on very constrained devices (e.g., embedded firmware).

* DNS-SD TXT data is already in a length-prefixed string encoding; embedding it verbatim in a TLV field avoids any re-encoding.

* CBOR is a strong alternative and SHOULD be explored in a future revision, particularly if the broader IETF context moves toward CBOR-based service advertisement encodings.

## Why DNS-SD String Encoding and Not Numeric Types

An alternative design would replace the human-readable Service Name string with a compact numeric identifier (similar to how Bluetooth has 16-bit Service Class UUIDs). This was considered and rejected for the following reasons:

* DNS-SD's value proposition is that service names are declared using DNS labels, which are human-readable and do not require a centralized numeric registry for new service names.

* Introducing numeric type codes would require an IANA registry cross-referencing DNS-SD service names, tying the DDB format to an ongoing registration process.

* The string representation is compact enough for the vast majority of service names (e.g., "_ipp._tcp" is 9 octets).

The UUID field (Type 0x04) uses a binary encoding (16 octets) rather than the hyphenated ASCII form (36 octets) because the numeric form saves 20 octets and is unambiguously reversible.

## Why TLV Type Values Are Not DNS RR TYPE Values

An alternative design would assign TLV Type values from the DNS RR TYPE registry itself (e.g., using 16 for a TXT Data field, mirroring the wire-format TYPE value assigned to TXT records), rather than defining a separate registry in {{field-type-registry}}. This was considered and rejected for the following reasons:

* Most DDB fields do not correspond to a whole DNS resource record. Instance Name, UUID, Port, and Domain are individual components extracted from SRV, TXT, and PTR RDATA, not complete records, so they have no DNS RR TYPE value to borrow. Only TXT Data has a clean one-to-one correspondence.

* The DNS RR TYPE namespace is a 16-bit space administered by IANA for an unrelated purpose (identifying resource record types generally), and is not guaranteed to stay within 1 octet: for example, CAA is assigned TYPE 257. Tying the DDB Type field to that registry would risk outgrowing the field's 1-octet width for reasons entirely outside this document's control.

* A DDB-specific registry ({{iana}}) keeps the Type namespace small, dense, and scoped to exactly the fields this format defines, which is more appropriate for a constrained, self-contained encoding.

## TXT Record Encoding

Reusing the DNS TXT RDATA wire format for the TXT Data field means that existing DNS-SD TXT record parsers can process this field without modification. An alternative was to encode each key=value pair as a separate TLV sub-field; this was rejected as it would add complexity and would not reduce size for typical TXT records.

# IANA Considerations {#iana}

This specification, if published, requests the following IANA actions:

## DNS-SD Data Block TLV Type Registry

IANA is requested to create a new registry "DNS-SD Data Block TLV Types" under a new "DNS-SD Data Block" registry group. The registry uses the following columns:

Value:
: 1-octet TLV Type value.

Name:
: Short descriptive name of the field.

Reference:
: RFC or other document defining the field.

Notes:
: Additional information.

Registration Policy: Values 0x01-0xEF use "Specification Required" {{RFC8126}}. Values 0xF0-0xFE are "Private Use". Value 0xFF is "Reserved". Value 0x00 is defined as a Padding (NOP) octet ({{tlv-field-structure}}) and does not participate in the assignment pool.

Initial entries (defined by this specification):

| Value | Name | Reference |
|---|---|---|
| 0x00 | Padding (NOP) | This document |
| 0x01 | Service Name | This document |
| 0x02 | Service Instance Name | This document |
| 0x03 | TXT Data | This document |
| 0x04 | UUID | This document |
| 0x05 | Domain | This document |
| 0x06 | Port | This document |
| 0x07 | Subtype List | This document |
| 0x08 | Hostname | This document |
| 0x09-0xEF | Unassigned | This document |
| 0xF0-0xFE | Private Use | This document |
| 0xFF | Reserved | This document |
{: title="DNS-SD Data Block TLV Types"}

## MIME Type Registration

A request to register the MIME media type "application/vnd.dnssd.ddb", identifying the DDB payload defined in {{ddb-payload-identity}}, should be submitted to IANA per {{RFC6838}}. This specification does not formally request that registration at this draft stage.

# Security Considerations {#security}

DDBs are typically carried in unauthenticated, short-range broadcast or proximity transports. The following security considerations apply:

## Spoofing and Impersonation

Any device within range of the carrying transport can transmit a DDB claiming any Service Name, Instance Name, or UUID. Receivers MUST NOT rely on DDB content alone to establish trust. A DDB is a discovery aid; any security-relevant properties (authentication, authorization) MUST be established over the application protocol after connectivity is established (e.g., TLS over IPP, 802.1X, device attestation).

## Privacy: Persistent Identifiers

The UUID field, if reused across proximity events, constitutes a stable identifier that can be used to track a device's location or owner. Devices SHOULD use randomized UUIDs for DDBs carried in broadcast advertising if the service UUID is not already stable (e.g., print services that expose a stable mDNS UUID publicly may choose to accept this). This mirrors similar address- and identifier-randomization considerations found in other short-range broadcast technologies: a persistent service identifier in an advertisement creates the same tracking surface as a persistent link-layer address.

The Instance Name often contains human-readable device names (e.g., "Jane's MacBook Printer") which are personally identifying. Devices SHOULD allow users to customize or omit Instance Names in proximity advertisements.

## Denial of Service

A malicious sender can flood receivers with large numbers of DDB-carrying advertisements or messages. Receivers SHOULD implement rate limiting and deduplication.

## Data Integrity

DDB transport containers typically do not provide cryptographic integrity protection. An on-path attacker in close physical proximity could modify advertisement contents. Applications that require integrity SHOULD sign DDB content using an application-layer digital signature (e.g., a device certificate or vendor-defined signing mechanism) conveyed out-of-band or in a companion record, if the transport and deployment context support it.

## Sensitive Data in TXT Records

The TXT Data field can carry arbitrary key=value pairs. Senders MUST NOT include long-lived secrets (Wi-Fi PSKs, passwords, private keys) in the TXT Data field of a DDB, as this data is transmitted in cleartext over short-range radio.

--- back

# Acknowledgments
{:numbered="false"}

TBD -- to be populated during the IETF process.
