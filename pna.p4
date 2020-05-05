/*
 * Copyright 2020-present MNK Labs & Consulting
 * https://mnkcg.com
 *

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#ifndef __PNA_P4__
#define __PNA_P4__


#ifndef _PORTABLE_NIC_ARCHITECTURE_P4_
#define _PORTABLE_NIC_ARCHITECTURE_P4_

typedef bit<32> DMAHeaderUint_t; // change to 64 bits, if needed and change
                                 // ProcessDMA extern API as well.
typedef bit<32> DMADataUint_t;

// BEGIN:Metadata_types
enum PNA_PacketPath_t {
    NORMAL,     /// Packet received by ingress that is none of the cases below.
    NORMAL_UNICAST,   /// Normal packet received by egress which is unicast
    NORMAL_MULTICAST, /// Normal packet received by egress which is multicast
    NORMAL_DMA_RX, /// Normal packet received by DMA.
    NORMAL_DMA_TX, /// Normal packet sent by DMA.
    CLONE_I2E,  /// Packet created via a clone operation in ingress,
                /// destined for egress
    CLONE_E2E,  /// Packet created via a clone operation in egress,
                /// destined for egress
    RESUBMIT,   /// Packet arrival is the result of a resubmit operation
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

struct pna_ingress_input_metadata_t {
  // All of these values are initialized by the architecture before
  // the Ingress control block begins executing.
  PortId_t                 ingress_port;
  PNA_PacketPath_t         packet_path;
  Timestamp_t              ingress_timestamp;
  ParserError_t            parser_error;
}
// BEGIN:Metadata_ingress_output
struct pna_ingress_output_metadata_t {
  // The comment after each field specifies its initial value when the
  // Ingress control block begins executing.
  ClassOfService_t         class_of_service; // 0
  bool                     clone;            // false
  CloneSessionId_t         clone_session_id; // initial value is undefined
  bool                     drop;             // true
  bool                     resubmit;         // false
  MulticastGroup_t         multicast_group;  // 0
  PortId_t                 egress_port;      // initial value is undefined
}
// END:Metadata_ingress_output

#define PERIODIC 1w0
#define ONE_SHOT 1w1

// BEGIN:Timer_extern
// P is PortId_t.  Assign special value of PortId_t for time ops.
extern Timer<P> {
  /// Constructor
  Timer(P port_id);

  // returns timer id (tid) or 0 for failure.
  @pure
  bit<32> create(in bit<1> one_shot_or_periodic, in bit<32> msec);
  @pure
  bit<32> delete(in bit<32> tid); // returns 0 or error code
}
// END:Timer_extern

// BEGIN:Doorbell_extern
// Assign special value of PortId_t for DMA RX and DMA TX.
extern Doorbell<P> {
  /// Constructor
  Doorbell();

  @pure
  void ring(in P port_id);
}
// END:Doorbell_extern

// BEGIN:ProcessDMA_extern
extern ProcessDMA {
  /// Constructor
  ProcessDMA();

  @pure
  void copy(in bit<32> from, in bit<32> from_sz, inout bit<32> to, inout bit<32> to_sz);
}
// END:ProcessDMA_extern

// Doorbell calls this control to process Rx data
control ProcessRxRing<D, H, M>(
    in D data, inout H hdr, inout M user_meta,
    in    pna_ingress_input_metadata_t  istd,
    inout pna_ingress_output_metadata_t ostd);

// Doorbell calls this control to process Tx data
control ProcessTxRing<D, H, M>(
    in D data, inout H hdr, inout M user_meta,
    in    pna_ingress_input_metadata_t  istd,
    inout pna_ingress_output_metadata_t ostd);

package PNA_PCI_DRIVER_RX<D, H, M, IH, IM, CI2EM, NM, RESUBM, RECIRCM>(
    ProcessRxRing<D, H, M> prr,
    IngressParser<IH, IM, RESUBM, RECIRCM> ip,
    Ingress<IH, IM> ig,
    IngressDeparser<IH, IM, CI2EM, RESUBM, NM> id);

package PNA_PCI_DRIVER_TX<D, H, M, EH, EM, NM, CI2EM, CE2EM, RECIRCM>(
    ProcessTxRing<D, H, M> prr,
    EgressParser<EH, EM, NM, CI2EM, CE2EM> ep,
    Egress<EH, EM> eg,
    EgressDeparser<EH, EM, CE2EM, RECIRCM> ed);

// END:Programmable_blocks

#endif  /* _PORTABLE_NIC_ARCHITECTURE_P4_ */

#endif   // __PNA_P4__
