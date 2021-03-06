/*
 * Copyright (c) 2017, Toothless Consulting UG (haftungsbeschraenkt)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * + Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * + Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * + Neither the name arty-glitcher nor the names of its contributors may be
 *   used to endorse or promote products derived from this software without
 *   specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE arty-glitcher PROJECT BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 *
 * Author: Dmitry Nedospasov <dmitry@toothless.co>
 *
 */
`default_nettype none

module top
(
    input wire          ext_clk,
    input wire          ftdi_rx,
    output wire         ftdi_tx,
    input wire          o_board_rx,
    output wire         o_board_tx,
    output wire         o_board_rst,
    output wire         LEDR_N,
    output wire         LEDG_N,
    output wire [6:0]   seg0,
    output wire         ca0,
    output wire [6:0]   seg1,
    output wire         ca1,
    output wire         vout
);

// Combinatorial logic
// -- Pass through everything from the target to the host
assign ftdi_tx = o_board_rx;

// High nibble
nibble_to_seven_seg segi0_1 (
    .nibblein(pulse_width[7:4]),
    .segout(nib0_1)
);

// Low nibble
nibble_to_seven_seg segi0_0 (
    .nibblein(pulse_width[3:0]),
    .segout(nib0_0)
);

wire [6:0] nib0_0, nib0_1;

seven_seg_mux dmuxi0 (
    .clk(ext_clk),
    .disp0(nib0_0),
    .disp1(nib0_1),
    .segout(seg0),
    .disp_sel(ca0)
);

// High nibble
nibble_to_seven_seg segi1_1 (
    .nibblein(delay[7:4]),
    .segout(nib1_1)
);

// Low nibble
nibble_to_seven_seg segi1_0 (
    .nibblein(delay[3:0]),
    .segout(nib1_0)
);

wire [6:0] nib1_0, nib1_1;

seven_seg_mux dmuxi1 (
    .clk(ext_clk),
    .disp0(nib1_0),
    .disp1(nib1_1),
    .segout(seg1),
    .disp_sel(ca1)
);

assign LEDG_N = o_board_tx;
assign LEDR_N = o_board_rx;

wire        rst;
wire        glitch_en;
wire [7:0]  pulse_width, pulse_cnt;
wire [7:0]  pwm;
wire [63:0] delay;
wire board_rst;
wire passthrough;
wire dout;

assign o_board_tx = passthrough ? ftdi_rx : dout;

// Receives commands from host uart and parses out commands intended for the
// glitcher, passing through everything else
cmd cmdi (
    .clk(ext_clk),
    .din(ftdi_rx),
    .dout(dout),
    .board_rst(board_rst),
    .rst(rst),
    .pulse_width(pulse_width),
    .pulse_cnt(pulse_cnt),
    .delay(delay),
    .pwm(pwm),
    .glitch_en(glitch_en),
    .passthrough(passthrough)
);

wire pwm_out;

pattern pwmi (
    .clk(ext_clk),
    .rst(rst),
    .en(1'b1),
    .pattern(pwm),
    .pattern_cnt(8'd0),
    .dout(pwm_out)
);

wire delay_rdy;

delay delayi (
    .clk(ext_clk),
    .rst(rst),
    .en(glitch_en),
    .delay(delay),
    .rdy(delay_rdy)
);

wire trigger_valid;

trigger triggeri (
    .clk(ext_clk),
    .rst(rst),
    .en(glitch_en),
    .trigger(delay_rdy),
    .valid(trigger_valid)
);

wire pulse_o;
wire pulse_rdy;

pulse pulsei (
    .clk(ext_clk),
    .rst(rst),
    .en(trigger_valid),
    .width_in(pulse_width),
    .cnt_in(pulse_cnt),
    .pulse_o(pulse_o),
    .pulse_rdy(pulse_rdy)
);

resetter #(
    .cycles(60)
    ) rsti(
    .clk(ext_clk),
    .rst(board_rst || rst || glitch_en),
    .rst_out(o_board_rst)
);

assign vout = pulse_rdy ? pwm_out : pulse_o;

endmodule
