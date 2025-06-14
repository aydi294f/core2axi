// core2axi_lite_struct_bridge.sv
// A wrapper that instantiates PULP's core2axi bridge (in Lite-mode) and exposes
// a bundled AXI4-Lite request/response interface (axi_lite_req_t / axi_lite_resp_t).

import axi_pkg::*;

`include "axi/typedef.svh"

// Host-visible AXI-Lite address/data types
typedef logic [31:0] axi_lite_addr_t;
typedef logic [31:0] axi_lite_data_t;
typedef logic [3:0]  axi_lite_strb_t;

// Generate the structs:
//  • axi_req_t   with fields aw, aw_valid, w, w_valid, b_ready, ar, ar_valid, r_ready
//  • axi_resp_t  with fields aw_ready, w_ready, b, b_valid, ar_ready, r, r_valid
`AXI_LITE_TYPEDEF_ALL_CT(
  axi,            // prefix for channel structs: axi_aw_chan_t, etc.
  axi_req_t,      // request struct name
  axi_resp_t,     // response struct name
  axi_lite_addr_t,
  axi_lite_data_t,
  axi_lite_strb_t
)

module core2axi_lite_struct_bridge #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  // clock & reset
  input  logic              clk_i,
  input  logic              rst_ni,

  // CVE2 core side (custom lightweight protocol)
  input  logic              data_req_i,
  output logic              data_gnt_o,
  output logic              data_rvalid_o,
  input  logic [ADDR_WIDTH-1:0] data_addr_i,
  input  logic              data_we_i,
  input  logic [DATA_WIDTH/8-1:0] data_be_i,
  output logic [DATA_WIDTH-1:0] data_rdata_o,
  input  logic [DATA_WIDTH-1:0] data_wdata_i,

  // Bundled AXI4-Lite side
  output axi_req_t     axi_req_o,   // { aw, aw_valid, w, w_valid, b_ready, ar, ar_valid, r_ready }
  input  axi_resp_t    axi_resp_i   // { aw_ready, w_ready, b, b_valid, ar_ready, r, r_valid }
);

  //-------------------------------------------------------------------------
  // Unpacked AXI-Lite signals for the inner PULP bridge
  //-------------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0] aw_addr;
  logic [2:0]            aw_prot;
  logic                  aw_valid;
  logic                  aw_ready;

  logic [DATA_WIDTH-1:0] w_data;
  logic [DATA_WIDTH/8-1:0] w_strb;
  logic                  w_valid;
  logic                  w_ready;

  logic [1:0]            b_resp;
  logic                  b_valid;
  logic                  b_ready;

  logic [ADDR_WIDTH-1:0] ar_addr;
  logic [2:0]            ar_prot;
  logic                  ar_valid;
  logic                  ar_ready;

  logic [DATA_WIDTH-1:0] r_data;
  logic [1:0]            r_resp;
  logic                  r_valid;
  logic                  r_ready;
  // Dummy wires for unused output ports
logic  aw_id_dummy;
logic [7:0] aw_len_dummy;
logic [2:0] aw_size_dummy;
logic [1:0] aw_burst_dummy;
logic       aw_lock_dummy;
logic [3:0] aw_cache_dummy;
logic [3:0] aw_region_dummy;
logic  aw_user_dummy;
logic [3:0] aw_qos_dummy;

logic       w_last_dummy;
logic  w_user_dummy;

logic  b_id_dummy;
logic  b_user_dummy;

logic  ar_id_dummy;
logic [7:0] ar_len_dummy;
logic [2:0] ar_size_dummy;
logic [1:0] ar_burst_dummy;
logic       ar_lock_dummy;
logic [3:0] ar_cache_dummy;
logic [3:0] ar_region_dummy;
logic  ar_user_dummy;
logic [3:0] ar_qos_dummy;

logic  r_id_dummy;
logic       r_last_dummy;
logic  r_user_dummy;



  //-------------------------------------------------------------------------
  // Map bundled AXI-Lite ↔ unpacked signals
  //-------------------------------------------------------------------------

  // -- Write address channel --
  assign axi_req_o.aw.addr     = aw_addr;
  assign axi_req_o.aw.prot     = aw_prot;
  assign axi_req_o.aw_valid    = aw_valid;
  assign aw_ready              = axi_resp_i.aw_ready;

  // -- Write data channel --
  assign axi_req_o.w.data      = w_data;
  assign axi_req_o.w.strb      = w_strb;
  assign axi_req_o.w_valid     = w_valid;
  assign w_ready               = axi_resp_i.w_ready;

  // -- Read address channel --
  assign axi_req_o.ar.addr     = ar_addr;
  assign axi_req_o.ar.prot     = ar_prot;
  assign axi_req_o.ar_valid    = ar_valid;
  assign ar_ready              = axi_resp_i.ar_ready;

  // -- Write response (B) channel --
  assign axi_req_o.b_ready     = b_ready;
  assign b_valid               = axi_resp_i.b_valid;
  assign b_resp                = axi_resp_i.b.resp;

  // -- Read data (R) channel --
  assign axi_req_o.r_ready     = r_ready;
  assign r_valid               = axi_resp_i.r_valid;
  assign r_resp                = axi_resp_i.r.resp;
  assign r_data                = axi_resp_i.r.data;

  //-------------------------------------------------------------------------
  // Instantiate the PULP core2axi bridge in Lite-mode
  //-------------------------------------------------------------------------
  core2axi #(
    .AXI4_ADDRESS_WIDTH(ADDR_WIDTH),
    .AXI4_RDATA_WIDTH  (DATA_WIDTH),
    .AXI4_WDATA_WIDTH  (DATA_WIDTH),
    .AXI4_ID_WIDTH     (1),   // IDs tied to zero
    .AXI4_USER_WIDTH   (1),   // USER tied to zero
    .REGISTERED_GRANT  ("FALSE")
  ) u_core2axi (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),

    // CVE2 core protocol side
    .data_req_i    (data_req_i),
    .data_gnt_o    (data_gnt_o),
    .data_rvalid_o (data_rvalid_o),
    .data_addr_i   (data_addr_i),
    .data_we_i     (data_we_i),
    .data_be_i     (data_be_i),
    .data_rdata_o  (data_rdata_o),
    .data_wdata_i  (data_wdata_i),

    // AW channel
    .aw_addr_o     (aw_addr),
    .aw_prot_o     (aw_prot),
    .aw_valid_o    (aw_valid),
    .aw_ready_i    (aw_ready),
    .aw_id_o       (aw_id_dummy),
    .aw_len_o      (aw_len_dummy),
    .aw_size_o     (aw_size_dummy),
    .aw_burst_o    (aw_burst_dummy),
    .aw_lock_o     (aw_lock_dummy),
    .aw_cache_o    (aw_cache_dummy),
    .aw_region_o   (aw_region_dummy),
    .aw_user_o     (aw_user_dummy),
    .aw_qos_o      (aw_qos_dummy),

    // W channel
    .w_data_o      (w_data),
    .w_strb_o      (w_strb),
    .w_valid_o     (w_valid),
    .w_ready_i     (w_ready),
    .w_last_o      (w_last_dummy),
    .w_user_o      (w_user_dummy),

    // B channel
    .b_resp_i      (b_resp),
    .b_valid_i     (b_valid),
    .b_ready_o     (b_ready),
    .b_id_i        (b_id_dummy),
    .b_user_i      (b_user_dummy),

    // AR channel
    .ar_addr_o     (ar_addr),
    .ar_prot_o     (ar_prot),
    .ar_valid_o    (ar_valid),
    .ar_ready_i    (ar_ready),
    .ar_id_o       (ar_id_dummy),
    .ar_len_o      (ar_len_dummy),
    .ar_size_o     (ar_size_dummy),
    .ar_burst_o    (ar_burst_dummy),
    .ar_lock_o     (ar_lock_dummy),
    .ar_cache_o    (ar_cache_dummy),
    .ar_region_o   (ar_region_dummy),
    .ar_user_o     (ar_user_dummy),
    .ar_qos_o      (ar_qos_dummy),

    // R channel
    .r_data_i      (r_data),
    .r_resp_i      (r_resp),
    .r_valid_i     (r_valid),
    .r_ready_o     (r_ready),
    .r_id_i        (r_id_dummy),
    .r_last_i      (r_last_dummy),
    .r_user_i      (r_user_dummy)
  );

endmodule
