---
title: "DNS-SD Data Block: An Encoding for Non-IP Transports"
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
    organization: Independent
    email: smitty.standards@gmail.com

normative:
  RFC3629:
  RFC5891:
  RFC6335:
  RFC6762:
  IANA.service-names-port-numbers:
  RFC6763:
  RFC8126:
  RFC9562:

informative:
  RFC2782:
  RFC4122:
  RFC6066:
  RFC6838:
  RFC7558:
  RFC8259:
  RFC8882:
  RFC8949:
  IEEE802.1AR:
    title: "IEEE Standard for Local and metropolitan area networks - Secure Device Identity"
    author:
      -
        organization: IEEE
    seriesinfo:
      IEEE: "802.1AR"
    target: https://1.ieee802.org/security/802-1ar
  BT-TDS:
    title: "Transport Discovery Service 1.1"
    author:
      -
        organization: Bluetooth SIG
    date: 2020
    target: https://www.bluetooth.com/specifications/specs/transport-discovery-service-1-1/
  NFC-VERB:
    title: "Verb Record Type Definition Technical Specification"
    author:
      -
        organization: NFC Forum
    date: 2015-12-08
    seriesinfo:
      NFC Forum: "RTD-Verb"
      Version: "1.0"
    target: https://nfc-forum.org/build/specifications/
  NFC-CH:
    title: "Connection Handover Technical Specification"
    author:
      -
        organization: NFC Forum
    seriesinfo:
      NFC Forum: "CH"
      Version: "1.5"
    target: https://nfc-forum.org/build/specifications/connection-handover-technical-specification/
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

The DNS-SD Data Block (DDB) is a compact, Type-Length-Value (TLV) encoded container for conveying DNS-Based Service Discovery (DNS-SD) service information over non-IP transports used by short-range peer-to-peer or proximity-based advertisement and discovery technologies, such as the Bluetooth Low Energy Transport Discovery Service or Near Field Communication (NFC) Verb NFC Data Exchange Format (NDEF) records.

--- middle

# Introduction {#intro}

DNS-based Service Discovery {{RFC6763}} is widely deployed for service advertisement on IP networks. Printers, media servers, file-sharing, and many other types of services are advertised and discovered via DNS-SD.

There are circumstances where ancillary advertisement and discovery technologies can improve service advertisement and discovery coverage. Some network environments may have non-trivial network infrastructure topologies that complicate the use of mDNS {{RFC6762}}, but that are also not provisioned with infrastructure DNS-SD. There are also peer-to-peer wireless IP networking technologies that are used for transient communications and could support DNS-SD services, but that suffer from a poor user experience due to a lack of a standard way to provide the DNS-SD service information before a connection has been established (what is sometimes referred to as "pre-association service discovery"). Both of these could benefit from using ancillary short-range peer-to-peer or proximity-focused advertisement and discovery technologies to convey DNS-SD service information.

This problem is related to the one described in {{RFC7558}}, whose solutions extend DNS-SD beyond a single link within an IP network. DDB addresses a different case: conveying DNS-SD service information over a non-IP channel, either before IP connectivity exists or where the client and the service do not share a network over which DNS-SD operates. DDB is not a replacement for those solutions; where they are deployed, DNS-SD over IP remains the preferred mechanism ({{applicability}}).

Examples include the following:

* An IPP printer in an office with a segmented network topology and limited DNS-SD infrastructure advertises its IPP print service using Bluetooth Low Energy Transport Discovery Service (TDS) {{BT-TDS}} to provide service information to physically proximate clients.

* A television with an NFC interface in a hotel room advertises its media streaming services and supported carrier types using NFC Verb NDEF Records {{NFC-VERB}}. A client tapped to the TV reviews the advertised connection carriers and services and offers its user a selected optimal pathway before engaging in the process of connecting to the TV.

Each of these ancillary discovery technologies was designed in part to carry application-layer service descriptions. Both include a field keyed by an organization identifier, whose contents are defined by the identified organization. This document defines that content for DNS-SD: a single encoding that each technology can reference, and that future ancillary discovery protocols can adopt.

This document defines the DDB format and its associated encoding and decoding rules for interoperable use. The DDB is designed to:

* Fit within the small payload sizes typical of short-range advertisement and proximity discovery technologies.

* Be self-describing and forward-compatible (unknown fields are skipped by receivers that do not understand them).

* Round-trip losslessly to and from DNS-SD PTR, SRV, and TXT records for the fields it encodes, in the common case of a service instance described by a single SRV record with zero priority and weight (see {{ddb-to-dnssd}}).

Use of DDB in specific external registries or protocol elements may still require assignment or approval by the relevant standards body (e.g., Bluetooth SIG, NFC Forum).

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

Inherited Instance Name:
: An Instance Name encoded with a Length of 0, whose value is a name conveyed by the carrying technology ({{instance-name}}).

TXT Data:
: The DNS-SD TXT record payload, encoded as a sequence of length-prefixed strings, each string being a UTF-8 key=value pair or a bare key, as specified in {{RFC6763}}, Section 6.

UUID:
: A Universally Unique Identifier as defined in {{RFC9562}} (formerly {{RFC4122}}), encoded as 16 octets in network byte order following the binary representation defined therein.

TLV:
: Type-Length-Value - a binary encoding scheme consisting of a type code field indicating the type, a length field indicating the length of the value field, and a value field containing the actual payload. The type and length fields are typically of fixed size.

# DNS-SD Data Block (DDB) Format {#ddb-format}

## Applicability and Directionality {#applicability}

DDB is intended for transports over which DNS-SD itself cannot operate, such as short-range proximity and pre-association technologies. Where IP connectivity is available and DNS-SD is usable, implementations SHOULD use DNS-SD directly rather than conveying DDBs over IP. Relaying a DDB over an IP-based protocol (e.g., from a gateway or for diagnostics) is outside the scope of this specification and does not change its status as an unauthenticated discovery aid (see {{security}}).

A DDB describes a service being offered by the sender; it is not a request or query for a service. Any seek/query semantics (e.g., a seek/query flag defined by the surrounding transport container's own framing) are properties of that container, not of the DDB payload itself.

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
: The version of this DDB encoding. This specification defines version 0x01. A decoder that encounters an unknown version value MUST treat the entire block as uninterpretable and MUST NOT attempt to parse the TLV fields.

: Additive, backward-compatible extensions are introduced by defining new TLV Type values or related registry entries without changing the Version value. The Version value is intended for wire-format or processing changes that are not backward compatible with earlier versions.

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
: Identifies the type of the field. Values are defined in {{field-type-registry}}. Value 0xFF is reserved for future extension. Values 0x09-0xEF are unassigned and available for assignment ({{iana}}). Values 0xF0-0xFE are reserved for Private Use ({{RFC8126}}) and MUST NOT be used in interoperability contexts.

: The special value 0x00 is defined as a padding (NOP) octet. A 0x00 byte in the TLV stream is consumed as a single padding byte with no associated Length or Value fields. Encoders MUST NOT emit padding bytes except when required by a specific transport's framing (e.g., to pad to a fixed size). Decoders MUST skip 0x00 bytes and continue parsing the next TLV field.

Length (1 octet):
: The length of the Value field in octets. A Length of 0x00 indicates an empty value, which is valid only for field types whose definition explicitly permits it.

: When a length of 255 octets is insufficient for a given field (notably TXT Data for rich service descriptions), the following extended-length encoding is used: if the Length octet is 0xFF, it is followed by two additional octets that carry the actual length as a 16-bit unsigned integer in network byte order, and the Value starts after those two octets. This extended form MUST NOT be used when the actual length is <= 254 octets.

Value (Length octets):
: The field value. Encoding is field-type-specific; see {{field-type-registry}}.

TLV fields MUST be processed in the order they appear. Encoders MUST NOT include more than one TLV field with the same Type value. A decoder that encounters a TLV field whose Type value has already appeared in the same DDB MUST treat the entire DDB as malformed and discard it; see {{parser-differentials}}. This applies to all Type values, including unrecognized and Private Use values. Padding octets (Type 0x00) are not TLV fields and are not subject to this rule.

An implementation MUST ignore (skip past) any TLV field whose Type it does not recognize.

## Field Type Registry {#field-type-registry}

The following Type values are defined by this specification.

| Type | Name | Required/Optional |
|---|---|---|
| 0x00 | Padding (NOP) | N/A |
| 0x01 | Service Name | Required |
| 0x02 | Instance Name | Required |
| 0x03 | TXT Data | Optional |
| 0x04 | UUID | Optional |
| 0x05 | Domain | Optional |
| 0x06 | Port | Optional |
| 0x07 | Subtype List | Optional |
| 0x08 | Hostname | Recommended |
| 0x09-0xEF | Unassigned | N/A |
| 0xF0-0xFE | Private Use | N/A |
| 0xFF | Reserved | N/A |
{: title="DDB Field Types"}

A DDB MUST include exactly one Service Name field (Type 0x01) and exactly one Instance Name field (Type 0x02), and SHOULD include a Hostname field (Type 0x08); all other field types defined in this registry are optional. {{deployment-contexts}} describes when the recommended and optional fields are needed for a DDB to be useful.

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
: Required. Length constraints follow {{RFC6763}}, Section 4.1.1. The string MUST NOT be null-terminated. The Length MUST be at least 1, except as follows. A Length of 0 encodes an Inherited Instance Name: it indicates that the Instance Name is identical to a name conveyed by the carrying technology, as identified by that technology's specification for use with DDB (for example, a device name carried in the same advertisement). An encoder MUST NOT use a Length of 0 unless the carrying technology identifies such a name and that name is octet-for-octet identical to the Instance Name. A receiver that does not have the referenced name (for example, because the carrying technology identifies none, or it was not received) MUST treat the DDB as lacking an Instance Name ({{decoding-rules}}).

Example:
: The Instance Name "My Color Printer" (16 octets) encodes as:

~~~
02 10                   ; Type=Instance Name, Length=16
4D 79 20 43 6F 6C 6F 72 ;
20 50 72 69 6E 74 65 72 ; "My Color Printer"
~~~

Example:
: If the carrying technology conveys the device name "My Color Printer" and identifies it for use with DDB, the Instance Name can instead be encoded as an Inherited Instance Name:

~~~
02 00                   ; Type=Instance Name, Length=0
                        ; (name conveyed by the carrying technology)
~~~

### TXT Data (Type 0x03)

Value:
: The DNS-SD TXT record RDATA, verbatim, as defined in {{RFC6763}}, Section 6. Because the field's own length-prefixed string encoding is self-terminating, no separator or terminator is added; the end of the field is indicated by the TLV Length.

: Receivers that already implement DNS-SD TXT record parsing can reuse that code to parse this field directly.

: TLV extended-length encoding MUST be used if the TXT data exceeds 254 octets; see {{tlv-field-structure}}.

Constraints:
: The TXT Data field MAY represent an empty TXT record, encoded as a single string-length octet of 0x00 with a TLV Length of 0x01. This is equivalent to the DNS TXT RDATA for an empty record and is a valid encoding. When TXT metadata is present, the field contains one or more length-prefixed strings as described above. The length-prefixed strings MUST exactly fill the Value. If the TXT Data field is omitted entirely, receivers MUST NOT infer any default TXT record content, other than a UUID string reconstructed from the UUID field ({{ddb-to-dnssd}}).

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

### UUID (Type 0x04) {#uuid}

Value:
: A 128-bit UUID in the binary representation defined in {{RFC9562}}, in network byte order. This field is a compact encoding of a "UUID" key/value pair in the service's TXT record, for service types whose TXT record conventions define such a key (e.g., IPP Everywhere {{IPPEVE}}). The meaning of the UUID value, and its relationship to other protocols, are defined by the service type and are outside the scope of this specification.

Constraints:
: Length MUST be exactly 16 (0x10) octets. An encoder MAY use this field in place of a TXT string only if that string's key is "UUID" (compared case-insensitively, per {{RFC6763}}, Section 6.4), the value is the 36-character hyphenated form defined in {{RFC9562}} using lowercase hexadecimal digits, and the TXT record contains no other "UUID" key. When this field is used, that string MUST be removed from the TXT Data field. A DDB that contains both this field and a TXT string whose key is "UUID" (compared case-insensitively) is invalid ({{decoding-rules}}).

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
: Optional. If absent, receivers MUST assume the domain is "local" (i.e., the service is on the local link and discoverable via mDNS). Encoders SHOULD omit this field when the domain is "local", and MUST include it otherwise (e.g., for Wide-Area DNS-SD per {{RFC6763}}, Section 11). Length 1 through 253 octets.

Example:
: The Domain "example.com" (11 octets) encodes as:

~~~
05 0B                   ; Type=Domain, Length=11
65 78 61 6D 70 6C 65 2E ;
63 6F 6D                ; "example.com"
~~~

Note:
: In the vast majority of short-range proximity scenarios, the domain is "local" and this field can be omitted to save space.

Note:
: Both the Domain and Hostname ({{hostname}}) fields MUST be encoded exactly as they appear in the corresponding DNS-SD records; see {{RFC6763}}, Section 4.1.3 and {{RFC6762}}, Section 16. A receiver that needs A-label forms (e.g., for a unicast DNS query or TLS SNI) derives them per {{RFC5891}}.

### Port (Type 0x06) {#port}

Value:
: A 2-octet unsigned integer in network byte order containing the TCP or UDP port on which the service listens. This is the same value that would appear in the SRV record for this service instance.

Constraints:
: Optional. Length MUST be exactly 2 (0x02) octets if present. If absent, the port is the one assigned to the Service Name in the IANA "Service Name and Transport Protocol Port Number Registry" {{IANA.service-names-port-numbers}}, established by {{RFC6335}} (e.g., port 631 for "_ipp._tcp"). Encoders MUST include this field if the service listens on any other port, or if the registry assigns no port number to the Service Name. Encoders MAY include this field when it carries the assigned port; doing so is redundant but valid. A receiver that knows of no assigned port for the Service Name MUST treat the port as unknown until DNS-SD can be queried after IP association.

Example:
: Port 443 (0x01BB) encodes as follows. Because 443 is the port assigned to "_https._tcp", an encoder can omit this field for that Service Name.

~~~
06 02                   ; Type=Port, Length=2
01 BB                   ; port 443 (0x01BB)
~~~

### Subtype List (Type 0x07)

Value:
: A sequence of length-prefixed UTF-8 strings, one per DNS-SD subtype that the service instance supports. Each subtype string is the subtype label only (without the "_sub.\<service\>.\<domain\>" suffix), preceded by its 1-octet length. Example: the subtype "_print" (defined by IPP Everywhere {{IPPEVE}}) would be encoded as 0x06 followed by "_print" (6 octets).

Constraints:
: Optional. Included only when the service advertises one or more DNS-SD subtypes. Each individual subtype label MUST NOT exceed 63 octets. The length-prefixed strings MUST exactly fill the Value.

Example:
: The subtypes "_sub1" and "_sub2" (5 octets each) encode as a single Subtype List field, each label preceded by its own 1-octet length:

~~~
07 0C                   ; Type=Subtype List, Length=12
05                      ; string length 5
5F 73 75 62 31          ; "_sub1"
05                      ; string length 5
5F 73 75 62 32          ; "_sub2"
~~~

: Total Value: (1+5) + (1+5) = 12 octets.

### Hostname (Type 0x08) {#hostname}

Value:
: A UTF-8 string containing the fully qualified DNS hostname of the host providing the service, as it would appear in the RDATA of a DNS SRV record (target field). The hostname is the DNS name to which A or AAAA records are registered, and is the name used for TLS Server Name Indication (SNI) when connecting to the service. For example: "device-abc.example.com".

: The string is encoded exactly as it appears in the SRV target: precomposed UTF-8 for Multicast DNS ({{RFC6762}}, Section 16), or as registered in Unicast DNS. It MUST NOT include a trailing dot and MUST NOT be null-terminated. A client that uses the hostname for TLS Server Name Indication converts any non-ASCII labels to A-labels ({{RFC5891}}), as {{RFC6066}}, Section 3 requires.

Constraints:
: Recommended; encoders SHOULD include this field. It is needed to reach the service where the client cannot perform DNS-SD resolution after receiving the DDB ({{deployment-contexts}}), and for TLS SNI certificate validation prior to IP-level name resolution. Length MUST be between 1 and 253 octets, consistent with the maximum length of a fully qualified domain name. If absent, the client MUST obtain the SRV target hostname via DNS-SD once an IP connection is established.

Example:
: The Hostname "device-abc.example.com" (22 octets) encodes as:

~~~
08 16                   ; Type=Hostname, Length=22
64 65 76 69 63 65 2D 61 ;
62 63 2E 65 78 61 6D 70 ;
6C 65 2E 63 6F 6D       ; "device-abc.example.com"
~~~

Note:
: This field carries the SRV record target hostname only. IP address resolution still requires DNS-SD or mDNS once an IP association is available. This field does not replace the SRV record; it carries its target hostname for contexts where TLS validation metadata is beneficial pre-connection.

## Encoding Rules

1. Begin the DDB with the Version octet (0x01 for this version).

2. Encode the Service Name field (Type 0x01) first. This is the primary identifier of what kind of service is being described.

3. Encode remaining fields in no required order, though the ordering Service Name -> Instance Name -> TXT -> UUID -> others is RECOMMENDED as it places the most informative fields first, which is useful when a transport delivers a truncated DDB (see Decoding Rule 5).

4. Omit any optional field that has no value to convey, to minimize encoded size.

5. All string values are UTF-8 encoded ({{RFC3629}}) and MUST NOT be null-terminated. String lengths in TLV Length fields count octets, not characters.

6. A single TLV field using extended-length encoding may carry a value of at most 65,535 octets, occupying 1 (Type) + 3 (0xFF escape + 2-octet extended length) + 65,535 (Value) = 65,539 octets. No absolute maximum is imposed on the total DDB length; practical transports impose far tighter limits, and implementations SHOULD reject DDBs that exceed the limit imposed by the transport in use.

## Decoding Rules and Forward Compatibility {#decoding-rules}

1. Read the Version octet. If not 0x01, treat the block as uninterpretable (do not attempt TLV parsing).

2. Process TLV fields in order. For each field:

    a. Read the Type octet. If Type is 0x00, this is a padding byte; consume it and continue to the next field.

    b. If the Type has already been seen in this DDB, stop and discard the DDB as malformed.

    c. Read the Length octet. If Length is 0xFF, read the next two octets as a 16-bit big-endian extended length; if that extended length is less than 255, stop and discard the DDB.

    d. Read Value octets (count given by the resolved length).

    e. If the Type is known, check the Value against the constraints in that field's definition ({{field-type-registry}}). If it violates them (for example, a UUID field whose Length is not 16, a Port field whose Length is not 2, a Hostname longer than 253 octets, or a string field that is not valid UTF-8), stop and discard the DDB. Otherwise, process the field.

    f. If the Type is unknown, skip the Value bytes.

3. Continue until all octets of the DDB have been consumed.

4. A DDB parses successfully as long as its octets form well-formed TLV fields (including a DDB consisting of nothing but padding octets after the Version octet). However, a decoded DDB that lacks a Service Name field (Type 0x01) or an Instance Name field (Type 0x02), counting an Inherited Instance Name whose referenced name is unavailable as lacking ({{instance-name}}), is not a conformant DDB per {{field-type-registry}} and MUST be discarded by the receiver. Implementations MUST NOT generate a DDB lacking either field.

5. A DDB that is truncated (insufficient octets to complete the current TLV) MUST be treated as malformed; already-decoded fields MAY be used at the discretion of the application.

## DDB Payload Identity and Media Types {#ddb-payload-identity}

The canonical DDB payload is the exact octet sequence defined by {{ddb-format}}: one Version octet followed by zero or more TLV fields. A container that carries a DDB carries this payload without altering its internal format.

When a content-type identifier is needed, a DDB payload is identified by the media type "application/dnssd-ddb".

# Relationship to DNS-SD

## Interpreting a DDB as DNS-SD Information {#ddb-to-dnssd}

The Service Instance Name, formed from the Instance Name (or, for an Inherited Instance Name, the name it references; see {{instance-name}}), Service Name, and Domain fields per {{RFC6763}}, Section 4.1 (with the domain defaulting to "local" if the Domain field is absent), is the identity anchor of a DDB: it is the RDATA of the PTR record that DNS-SD browsing would return for this service instance. A client can use it to perform Service Instance Resolution ({{RFC6763}}, Section 5), obtaining SRV, TXT, and address records over any network interface on which DNS-SD is reachable.

A DDB can also convey SRV and TXT information directly, so that the client can use it without performing resolution:

SRV information:
: The Port field (or, if absent, the registry-assigned port; see {{port}}) and the Hostname field correspond to the SRV port and target. If Hostname is absent, the SRV target is not known until DNS-SD is queried after IP association. Priority and weight ({{RFC2782}}) are not conveyed and are treated as 0, as {{RFC6763}}, Section 5 specifies for the common case of a service instance described by a single SRV record.

TXT information:
: The TXT Data field is the TXT RDATA verbatim. If the UUID field is present, the client MUST reconstruct the TXT string "UUID=" followed by the 36-character lowercase hyphenated form of the UUID, and append it to the end of the TXT record. If the TXT Data field is absent, the reconstructed TXT record consists of that single string.

Subtypes:
: Each label in the Subtype List field corresponds to a subtype PTR record, owned by \<subtype\>._sub.\<Service Name\>.\<domain\>, that references the Service Instance Name ({{RFC6763}}, Section 7.1).

## Constructing a DDB from DNS-SD Records

To serialize DNS-SD records into a DDB: set Version = 0x01; extract the Service Name and Instance Name from the PTR and Service Instance Name; copy the TXT record RDATA into TXT Data, optionally moving a "UUID" key/value pair into the UUID field as specified in {{uuid}}; copy Port from the SRV record (it MAY be omitted if it equals the port assigned to the Service Name; see {{port}}); copy the SRV target hostname into Hostname (Type 0x08) if pre-connection hostname knowledge is needed; copy into the Subtype List field the labels of the subtypes under which the service instance is registered (an encoder that is not the service's own advertiser can include only subtypes it has observed, since DNS-SD provides no query that enumerates an instance's subtypes); and omit Domain if it is "local".

A DDB represents a single SRV record. Because SRV priority and weight affect client behavior only when multiple SRV records exist for the same Service Instance Name, they are not encoded.

# Examples

## Minimal Printer Service DDB

This DDB conveys only the required fields, the Service Name and the Instance Name:

~~~
01                      ; Version = 1
01 09                   ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                      ; "_ipp._tcp"
02 10                   ; Type=Instance Name, Length=16
4D 79 20 43 6F 6C 6F 72 ;
20 50 72 69 6E 74 65 72 ; "My Color Printer"
~~~

Total: 1 + (2+9) + (2+16) = 30 octets.

## Minimal Printer Service DDB with Inherited Instance Name

The same printer as in the previous example, where the carrying technology conveys the device name "My Color Printer" and identifies it for use with DDB, so the Instance Name is encoded as an Inherited Instance Name ({{instance-name}}):

~~~
01                      ; Version = 1
01 09                   ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                      ; "_ipp._tcp"
02 00                   ; Type=Instance Name, Length=0
                        ; (name conveyed by the carrying technology)
~~~

Total: 1 + (2+9) + (2+0) = 14 octets.

## Full Printer Service DDB with TXT and UUID

A more complete DDB for an IPP printer named "Conference Room Printer" (23 UTF-8 octets):

~~~
01                      ; Version = 1

01 09                   ; Type=Service Name, Length=9
5F 69 70 70 2E 5F 74 63 ;
70                      ; "_ipp._tcp"

02 17                   ; Type=Instance Name, Length=23
43 6F 6E 66 65 72 65 6E ;
63 65 20 52 6F 6F 6D 20 ;
50 72 69 6E 74 65 72    ; "Conference Room Printer"

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

04 10                   ; Type=UUID, Length=16
A1 B2 C3 D4 E5 F6 07 08 ;
89 9A AB BC CD DE EF F0 ; UUID bytes

06 02                   ; Type=Port, Length=2
21 B7                   ; port 8631 (0x21B7)

07 07                   ; Type=Subtype List, Length=7
06                      ; string length 6
5F 70 72 69 6E 74       ; "_print"

08 18                   ; Type=Hostname, Length=24
70 72 69 6E 74 65 72 2E ;
63 6F 72 70 2E 65 78 61 ;
6D 70 6C 65 2E 63 6F 6D ; "printer.corp.example.com"
~~~

Total: 1 + (2+9) + (2+23) + (2+44) + (2+16) + (2+2) + (2+7) + (2+24) = 140 octets.

The Port field is included because this printer listens on 8631 rather than port 631, which is assigned to "_ipp._tcp"; see {{port}}.

# Design Notes and Alternatives Considered

## Why TLV and Not CBOR or JSON

CBOR {{RFC8949}} and JSON {{RFC8259}} are both viable encoding options with good tooling. TLV was chosen for the following reasons:

* Minimal overhead per field: a simple string field costs 2 octets of overhead (Type + Length) versus CBOR's 1+ octets for a key plus 1+ octets for the string header, which is comparable at small scale, but TLV's 2-octet overhead per field (4 octets for values longer than 254 octets) is more predictable.

* Implementation simplicity: TLV parsing requires only arithmetic on byte arrays; no recursive descent or schema lookup is needed. This supports implementation on very constrained devices (e.g., embedded firmware).

* DNS-SD TXT data is already in a length-prefixed string encoding; embedding it verbatim in a TLV field avoids any re-encoding.

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

Designated experts reviewing a request should verify that the proposed field: conveys DNS-SD service information, or information directly supporting its use, that no existing field can represent; has a fully specified Value encoding, including length and character constraints, sufficient for the validation required by {{decoding-rules}}; and is optional, since decoders implementing earlier specifications will skip it ({{tlv-field-structure}}). A field that receivers must understand requires a new Version value instead. Because the code point space is small, experts should be conservative in making assignments.

Initial entries (defined by this specification):

| Value | Name | Reference | Notes |
|---|---|---|---|
| 0x00 | Padding (NOP) | This document | Single octet; no Length or Value |
| 0x01 | Service Name | This document | |
| 0x02 | Instance Name | This document | |
| 0x03 | TXT Data | This document | |
| 0x04 | UUID | This document | |
| 0x05 | Domain | This document | |
| 0x06 | Port | This document | |
| 0x07 | Subtype List | This document | |
| 0x08 | Hostname | This document | |
| 0x09-0xEF | Unassigned | This document | |
| 0xF0-0xFE | Private Use | This document | |
| 0xFF | Reserved | This document | Reserved for future extension (e.g., an extended Type encoding) |
{: title="DNS-SD Data Block TLV Types"}

## Media Type Registration

The media type "application/dnssd-ddb", identifying the DDB payload defined in {{ddb-payload-identity}}, is intended for registration in the standards tree per {{RFC6838}}. This specification does not formally request that registration at this draft stage.

# Security Considerations {#security}

DDBs are typically carried in unauthenticated, short-range broadcast or proximity transports. The following security considerations apply.

## Spoofing and Impersonation

Any device within range of the carrying transport can transmit a DDB claiming any Service Name, Instance Name, or UUID. Receivers MUST NOT rely on DDB content alone to establish trust. A DDB is a discovery aid; any security-relevant properties (authentication, authorization) MUST be established over the application protocol after connectivity is established (e.g., IPP over TLS, or device attestation).

## Hostname and TLS Validation

The Hostname field allows a client to validate a TLS server certificate before IP-level name resolution. Validation against a Hostname taken from a DDB proves only that the server holds a certificate for that name, not that it is the device that sent the DDB: an attacker can advertise a DDB naming a host it controls and for which it holds a valid certificate. Clients MUST NOT treat successful TLS validation against a DDB-supplied Hostname as evidence that the server is the proximate device, and SHOULD present the validated name to the user, or check it against names the client already trusts, before relying on it. Device identity credentials such as IEEE 802.1AR Secure Device Identifiers {{IEEE802.1AR}} can bind a certificate to a specific device; no mechanism currently associates such a credential with a DNS-SD service advertisement, whether conveyed by a DDB or otherwise, and defining one is outside the scope of this document.

## Relay and Replay

Receipt of a DDB over a short-range transport does not prove that the sender is physically nearby. An attacker can relay a DDB from a distant device, or replay a previously captured one, using equipment that extends the transport's effective range. Applications MUST NOT treat receipt of a DDB as proof of proximity; where proximity matters, it needs to be established by other means.

## Privacy

DDB conveys the same categories of information that DNS-SD publishes, so the privacy analysis of {{RFC8882}} applies. Broadcast transports can, however, expose that information to any receiver within radio range, including parties with no access to the IP network on which the service is offered, an audience that mDNS would not reach. Senders SHOULD apply to broadcast DDBs at least the information minimization they would apply on an untrusted network. Conversely, because a DDB is received passively and carries no query ({{applicability}}), receiving one discloses nothing about the client's interest in particular services, unlike DNS-SD browsing.

The UUID field carries the same value as the TXT "UUID" key it encodes, which for many service types is a stable identifier. When carried in broadcast advertising, it can be used to track a device or its owner across locations and over time. Senders concerned about tracking SHOULD omit both the UUID field and the TXT "UUID" key from broadcast DDBs, or use a value that the service type permits to be rotated.

The Instance Name often contains human-readable device names (e.g., "Jane's MacBook Printer") which are personally identifying. Devices SHOULD allow users to customize the Instance Name used in proximity advertisements.

Other fields can also identify a device or its owner. Hostnames often embed a device or owner name, and TXT Data can carry serial numbers, location descriptions, or administrative URLs. Senders SHOULD include in broadcast DDBs only the TXT keys a client needs to select the service.

DDB provides no confidentiality of its own. Discovery schemes that protect private services by obfuscating advertised values, such as rotating Instance Names recognizable only by previously paired peers, can be carried in a DDB unchanged, provided the scheme also addresses the other fields (UUID, Hostname, TXT Data) and the identifiers of the carrying transport.

## Denial of Service

A malicious sender can flood receivers with large numbers of DDB-carrying advertisements or messages. Receivers SHOULD implement rate limiting and deduplication.

## Data Integrity

DDB transport containers typically do not provide cryptographic integrity protection. An on-path attacker in close physical proximity could modify advertisement contents. Applications that require integrity can sign DDB content using an application-layer digital signature (e.g., a device certificate or vendor-defined signing mechanism) conveyed out-of-band or in a companion record, if the transport and deployment context support it.

## Parser Differentials {#parser-differentials}

If decoders resolved duplicate TLV fields differently (for example, one keeping the first instance and another the last), an attacker could craft a DDB that a filtering or validating component interprets one way and an end consumer interprets another, such as a Service Name or Hostname that passes inspection but is acted upon differently. Requiring decoders to discard any DDB containing duplicate Type values eliminates this ambiguity. Since conformant encoders never emit duplicates, rejection does not affect interoperability between conformant implementations.

## Sensitive Data in TXT Records

The TXT Data field can carry arbitrary key=value pairs. Senders MUST NOT include long-lived secrets (Wi-Fi PSKs, passwords, private keys) in the TXT Data field of a DDB, as this data is transmitted in cleartext over short-range radio.

--- back

# Deployment Contexts {#deployment-contexts}

This appendix is informative. It describes the two contexts in which DDBs are typically used, and what a DDB needs to contain to be useful in each.

## Peer-to-Peer Connection Opportunities

In this context, a DDB advertises a service that a client can reach after establishing a direct link with the advertising device, such as a peer-to-peer Wi-Fi connection set up following an NFC tap or a Bluetooth Low Energy advertisement. Once that link exists, the client and the service share a network on which DNS-SD operates, typically via mDNS. The DDB lets the client decide, before connecting, whether the device offers a service it wants.

Because the client can perform Service Instance Resolution once the link is established, the required fields (Service Name and Instance Name) are sufficient to reach the service, and TXT Data is useful for selection before connecting. The Hostname field is not needed to reach the service in this context, although it remains useful for TLS validation (see {{hostname}}). Where the carrying technology already conveys the device's name and that name is identical to the Instance Name, the sender can encode it as an Inherited Instance Name to avoid repeating it ({{instance-name}}). How the direct link itself is established is defined by the carrying technology (e.g., connection handover information accompanying the DDB), not by this document.

## LAN Connection Opportunities

In this context, the client and the service are attached to an IP network that routes traffic between them, but DNS-SD does not reach from one to the other: for example, the network is segmented so that mDNS does not span both, and no Wide-Area DNS-SD or other multi-link solution ({{RFC7558}}) is deployed for it. The DDB, received over an ancillary technology from a physically proximate device, is then the client's only source of DNS-SD information, and the client cannot perform Service Instance Resolution afterwards.

For a DDB to be useful in this context, fields that are recommended or optional in general need to be present, and their values need to be usable without mDNS:

* Hostname: present, and resolvable by the client without mDNS, typically via unicast DNS. A hostname in the "local" domain is not resolvable across segments.

* Port: present, unless the registry-assigned port applies ({{port}}).

* TXT Data: present with the keys the client needs to select and use the service, since the client cannot retrieve the TXT record later.

* Domain: if the service is also registered in a unicast DNS-SD domain, including the Domain field lets the client perform Service Instance Resolution through that domain ({{RFC6763}}, Section 11), even if it has no browsing domain configured.

A sender typically cannot tell which context a given receiver is in. A device attached to a managed network can serve both by including these fields whenever it has a hostname resolvable via unicast DNS.

Where reaching the service requires information beyond DNS-SD, such as the network to join, that information is conveyed by the carrying technology alongside the DDB (e.g., NFC Connection Handover {{NFC-CH}} or the Bluetooth LE Transport Discovery Service {{BT-TDS}}), not in the DDB itself. A carrying technology that offers a service over more than one carrier or transport can associate a separate DDB with each.

# Acknowledgments
{:numbered="false"}

TBD -- to be populated during the IETF process.
