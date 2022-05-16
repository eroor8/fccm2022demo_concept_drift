`timescale 1ns/1ns


module multicycle_fc_layer_outer_l0_t
#(
    parameter Q0W = 8,
    parameter Q0I = 8,
    parameter Q1I = 8,
    parameter Q1W = 8,
    parameter [63:0] IN_WIDTH = 3,
    parameter [63:0] OUT_WIDTH = 3,
    parameter ACT = "NONE",
    parameter [63:0] BATCHES = 1
)
(
    input wire                              clock,
    input wire                                                reset,
    input logic start_bp, input logic [15:0] lrate,
    input wire [IN_WIDTH-1:0][Q0I + Q1I - 1:0]              input_v,
    output reg [OUT_WIDTH-1:0][Q0I + Q1I - 1:0]              output_v, 
    input wire [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q0W + Q1W - 1 : 0] weight_v,
    output wire [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q0W + Q1W - 1 : 0] weight_out,
    output reg [63:0] batch_idx,
    output logic weight_write,
    input logic [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0] out_der,
    output reg done
);
    // Implement a fully connected layer over the course of multiple cycles.
    // Go through the input vector in batches, calculating all outputs in parallel.
    // When all batches are done, assert done.
    // Register the outputs when adding is done.
    // tidy this very messy SM.
    reg [63:0] curr_count, bp_idx;
    reg add;
    enum {START, WORKING, DONE, BP} state;
    logic [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0] in_der_act;
    logic bp_done, bp_wr;
    
    assign weight_write = (state == BP)? bp_wr : 1'b0; 
    
    wire [OUT_WIDTH-1:0][Q0I + Q1I - 1:0]  output_v_i;
    always @ (posedge clock) begin
        if (reset == 1'b1) begin
            done <= 1'b0;
            state <= START;
            curr_count <= 0;
            batch_idx <= 64'b0;
            add <= 1'b0;
        end else begin
            if (state == START) begin
                done <= 1'b0;
                curr_count <= 1'b0;
                batch_idx <= 64'b0;
                add <= 1'b0;
                state <= WORKING;
            end else if (state == DONE) begin
                done <= 1'b0;
                curr_count <= 1'b0;
                batch_idx <= 64'b0;
                add <= 1'b0;
                if (start_bp) begin
                    state <= BP;
                end
            end else if (state == WORKING) begin
                if (curr_count == BATCHES + 4) begin
                    done <= 1'b1;
                    state <= DONE;
                    output_v <= output_v_i;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 64'b0;
                end else if (curr_count > BATCHES) begin
                    add <= 1'b0;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 64'b0;
                end else begin
                    if (curr_count > 8'b0) begin
                        add <= 1'b1;
                    end
                curr_count <= curr_count + 1'b1;
                batch_idx <= batch_idx + 64'b1;
            end 
        end else begin
            batch_idx <= bp_idx;
            if (bp_done) begin
                done <= 1'b1;
                end
            end
        end 
    end 
    
    MULTICYCLE_FC_LAYER_T #(.Q1W(Q1W),.Q1I(Q1I), .Q0W(Q0W), .Q0I(Q0I), .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH), 
                            .ACT(ACT)) fc (
                            .in_der_act(in_der_act), .out_der(out_der), .clock(clock), .input_v(input_v), 
                            .weight_v(weight_v), .output_v(output_v_i), .reset(reset), .add(add));
    MULTICYCLE_XPROD_ADD_L0 #(.Q1I(Q1I),.Q0I(Q0I), .OUT_WIDTH(OUT_WIDTH), .IN_WIDTH(BATCHES)) fc_bpw (
                              .in_idx(bp_idx), .write_weights(bp_wr), .done(bp_done), .reset(start_bp), .lrate(lrate), 
                              .clock(clock), .out_v(in_der_act), .in_val(input_v), .output_matrix(weight_out), 
                              .input_matrix(weight_v));
endmodule

module MULTICYCLE_XPROD_ADD_L0
#(
    parameter Q0I = 16,
    parameter Q1I = 16,
    parameter IN_WIDTH = 10,
    parameter OUT_WIDTH = 10
)(
    input logic clock,
    input logic reset,
    input logic [15:0] lrate,
    output logic done,
    input  logic signed [Q0I + Q1I - 1 :0]  in_val,
    input  logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0]  out_v,
    input logic signed [OUT_WIDTH-1:0][Q1I + Q0I - 1 :0] input_matrix,
    output logic [OUT_WIDTH-1:0][Q1I + Q0I - 1 :0] output_matrix,
    output logic write_weights,
    output logic [63:0] in_idx
);
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] out_curr;
    logic [15:0] lrate_r;
    logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0]  out_v_r;
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] debug;
    logic signed [OUT_WIDTH-1:0][Q1I + Q0I - 1 :0] input_matrix_r0;
    logic signed [OUT_WIDTH-1:0][Q1I + Q0I - 1 :0] input_matrix_r1;
    
    enum {IDLE, WORKING, WAITING0, WAITING1, WAITING2, WAITING3, WAITING4, WAITING5, WAITING6, WAITING7, WAITING8, DONE} state;
    genvar i, j;
    generate
        for (i=0; i < 20; i=i+1) begin : a_loop
            // One multiplier per output - takes the current input...
            xprod_helper #(.Q(8)) helper (.in_val(in_val), .out_val(out_v[i]), .lrate(lrate_r), .clock(clock),
                                          .to_add(input_matrix_r1[i]), .result(out_curr[i]), .prod_final(debug[i]));
        end
    endgenerate
    always @ (posedge clock) begin
        input_matrix_r0 <= input_matrix;
        input_matrix_r1 <= input_matrix_r0;
        if (reset) begin
            done <= 1'b0;
            state <= WORKING;
            in_idx <= 63'b0;
            lrate_r <= lrate;
            out_v_r <= out_v;
            write_weights <= 1'b0;
        end else begin
            if (state == WORKING) begin
                write_weights <= 1'b0;
                if (in_idx <= (IN_WIDTH)) begin
                    in_idx <= in_idx + 1;
                    state <= WAITING0;
                end else begin
                    in_idx <= 0;
                    done <= 1'b1;
                    state <= DONE;
                end
            end else if (state == WAITING0) begin
                state <= WAITING1;
            end else if (state == WAITING1) begin
                state <= WAITING2;
            end else if (state == WAITING2) begin
                state <= WAITING3;
            end else if (state == WAITING3) begin
                state <= WAITING4;
            end else if (state == WAITING4) begin
                state <= WAITING5;
            end else if (state == WAITING5) begin
                state <= WAITING6;
            end else if (state == WAITING6) begin
                output_matrix <= out_curr;
                state <= WORKING;
                write_weights <= 1'b1;
            end else if (state ==DONE) begin
                done <= 1'b1;
            end
        end
    end
endmodule


module MULTICYCLE_FC_LAYER_OUTER_T
#(
    parameter Q0W = 8,
    parameter Q0I = 8,
    parameter Q1I = 8,
    parameter Q1W = 8,
    parameter IN_WIDTH = 3,
    parameter OUT_WIDTH = 3,
    parameter ACT = "NONE",
    parameter BATCHES = 1
)
(
    input wire clock,
    input wire reset,
    input logic [15:0] lrate,
    input wire [BATCHES-1:0][IN_WIDTH-1:0][Q0I + Q1I - 1:0] input_v,
    output reg [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] output_v, 
    input wire [OUT_WIDTH-1:0][BATCHES-1:0][Q0W + Q1W - 1 : 0] weight_v,
    output wire [OUT_WIDTH-1:0][BATCHES-1:0][Q0W + Q1W - 1 : 0] weight_out,
    input [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0] out_der,
    output [BATCHES-1:0][Q0I+Q1I-1:0] in_der,
    input wire start_bp,
    output reg done
);
    // Implement a fully connected layer over the course of multiple cycles.
    // Go through the input vector in batches, calculating all outputs in parallel.
    // When all batches are done, assert done.
    // Register the outputs when adding is done.
    reg [8:0] curr_count;
    reg [8:0] batch_idx;
    reg add, add_bp;
    enum {IDLE, WORKING, DONE, BP, WAIT} state;
    wire [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] output_v_i;
    wire [IN_WIDTH-1:0][Q0I + Q1I - 1:0] input_v_i;
    wire [IN_WIDTH-1:0][Q0I + Q1I - 1:0] in_der_act_i;
    wire [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q0W + Q1W - 1:0] weight_v_i;
    wire [BATCHES-1:0][IN_WIDTH-1:0][Q0W + Q1W - 1:0] weight_v_i_bp;
    logic [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] in_der_act;
    logic [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] in_der_act_r;
    logic xpr_done;
    genvar i, t;
    generate
        for (i=0; i < OUT_WIDTH; i=i+1) begin : output_loop
            assign weight_v_i[i] = weight_v[i][batch_idx];
        end
        for (t=0; t < BATCHES; t=t+1) begin: ot
            assign weight_v_i_bp[t] = weight_v[batch_idx][t];
        end
    endgenerate
    assign input_v_i = input_v[batch_idx];
    assign in_der_act_i = in_der_act_r[batch_idx];
    always @ (posedge clock) begin
        if (reset == 1'b1) begin
            done <= 1'b0;
            curr_count <= 0;
            batch_idx <= 0;
            add <= 1'b0;
            add_bp <= 1'b0;
            state <= WORKING;
        end else begin
            if (state == DONE) begin
                done <= 1'b0;
                curr_count <= 1'b0;
                batch_idx <= 1'b0;
                add <= 1'b0;
                add_bp <= 1'b0;
                if (start_bp) begin
                    state <= BP;
                    in_der_act_r <= in_der_act;
                    curr_count <= 0;
                    batch_idx <= 0;
                    add <= 1'b0;
                    add_bp <= 1'b0;
                end
            end else if (state == WORKING) begin
                if (curr_count == BATCHES + 3) begin
                    done <= 1'b1;
                    state <= DONE;
                    output_v <= output_v_i;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 1'b0;
                end else if (curr_count >= BATCHES) begin
                    add <= 1'b0;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 1'b0;
                end else begin
                    add <= 1'b1;
                    curr_count <= curr_count + 1'b1;
                    if ((curr_count > 0) && (batch_idx < BATCHES-1)) begin
                        batch_idx <= batch_idx + 1'b1;
                    end
                end
            end else if (state == BP) begin    
                if (curr_count == OUT_WIDTH + 3) begin
                    state <= WAIT;
                    output_v <= output_v_i;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 1'b0;
                end else if (curr_count >= OUT_WIDTH) begin
                    add_bp <= 1'b0;
                    curr_count <= curr_count + 1'b1;
                    batch_idx <= 1'b0;
                end else begin
                    add_bp <= 1'b1;
                    curr_count <= curr_count + 1'b1;
                    if ((curr_count > 0) && (batch_idx < OUT_WIDTH-1)) begin
                        batch_idx <= batch_idx + 1'b1;
                    end
               end
            end else if (state == WAIT) begin
                if (xpr_done) begin
                    done <= 1'b1;
                    state <= DONE;
                end
            end
        end 
    end 
        
    MULTICYCLE_FC_LAYER_T #(.Q1W(Q1W),.Q1I(Q1I), .Q0W(Q0W), .Q0I(Q0I), .IN_WIDTH(IN_WIDTH), 
                            .OUT_WIDTH(OUT_WIDTH), .ACT(ACT)) fc (.in_der_act(in_der_act),
                            .out_der(out_der), .clock(clock), .input_v(input_v_i), .weight_v(weight_v_i),
                            .output_v(output_v_i), .reset(reset), .add(add));
    MULTICYCLE_FC_LAYER_T #(.Q1W(Q1W),.Q1I(Q1I), .Q0W(Q0W), .Q0I(Q0I), .IN_WIDTH(IN_WIDTH), 
                            .OUT_WIDTH(BATCHES), .ACT("NONE")) fc_bp (.in_der_act(), .out_der(),
                            .clock(clock), .input_v(in_der_act_i), .weight_v(weight_v_i_bp), 
                            .output_v(in_der), .reset(start_bp && (state == DONE)), .add(add_bp));
    MULTICYCLE_XPROD_ADD #(.Q1I(Q1I),.Q0I(Q0I), .OUT_WIDTH(OUT_WIDTH), .IN_WIDTH(BATCHES)) fc_bpw (
                           .done(xpr_done), .reset(start_bp), .lrate(lrate), .clock(clock), 
                           .out_v(in_der_act), .in_v(input_v), .output_matrix(weight_out), .input_matrix(weight_v));
endmodule


// Do a cross product of two vectors and add it to an input matrix. 
module MULTICYCLE_XPROD_ADD
#(
    // Input format
    parameter Q0I = 16,
    parameter Q1I = 16,
    // Vector sizes
    parameter IN_WIDTH = 10,
    parameter OUT_WIDTH = 10
)(
    // Control signals
    input logic clock, input logic reset, output logic done, input logic signed [15:0] lrate,
    input  logic signed  [IN_WIDTH-1:0][Q0I + Q1I - 1 :0]  in_v,  // Input vector 1
    input  logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0]  out_v, // Input vector 2
    input logic signed [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q1I + Q0I - 1 :0] input_matrix, // matrix to add to
    output logic signed [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q1I + Q0I - 1 :0] output_matrix // output matrix
);
    // Intermediate values.
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] out_curr;
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] inxx;
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] inter;
    logic signed [OUT_WIDTH-1:0][(Q1I + Q0I) - 1 :0] prod;
    logic [Q0I + Q1I - 1 :0]  in_val;
    
    // Register inputs
    logic [15:0] lrate_r;
    logic signed [IN_WIDTH-1:0][Q0I + Q1I - 1 :0] in_v_r;
    logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0]  out_v_r;
    logic signed [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q1I + Q0I - 1 :0] input_matrix_r;
    
    // Matrix transposes
    logic signed [IN_WIDTH-1:0][OUT_WIDTH-1:0][Q1I + Q0I - 1 :0] output_matrix_t; 
    
    // State and control logic
    enum {IDLE, WORKING, DONE} state;
    logic [32:0] in_idx;
    genvar i, j;
    generate
        // Set different rows of the output matrix in parallel (parallel along OUT dimension)
        for (i=0; i < OUT_WIDTH; i=i+1) begin : a_loop
            // One multiplier per output - takes the current input...
            xprod_helper #(.Q(8)) helper (
                .in_val(in_val), .out_val(out_v_r[i]), .lrate(lrate_r), .clock(clock),
                .to_add(input_matrix_r[i][in_idx-3]), .result(out_curr[i]), .prod_final(prod[i]), 
                .in_x_out_m_s(inter[i]), .inxx(inxx[i]));

            // Calculate the matrix transposes (doesn't use extra logic)
            for (j=0; j < IN_WIDTH; j=j+1) begin : a_loop
                assign output_matrix[i][j] = output_matrix_t[j][i];
            end
        end
    endgenerate
        
    // Iterate through the input and calculate matrix columns one by one
    always @ (posedge clock) begin
        if (reset) begin // On reset, restart.
            done <= 1'b0;
            state <= WORKING;
            in_idx <= 1'b0;
            in_v_r <= in_v;
            out_v_r <= out_v;
            lrate_r <= lrate;
            input_matrix_r <= input_matrix;
            in_val <= in_v_r[0];
        end else begin
            in_val <= in_v_r[in_idx];
            if (state == WORKING) begin
                // Iterate through the input values.
                output_matrix_t[in_idx-3] <= out_curr; 
                if (in_idx <= (IN_WIDTH + 2)) begin
                    in_idx <= in_idx + 1;
                end else begin
                    in_idx <= 0;
                    done <= 1'b1;
                    state <= DONE;
                end
            end else if (state == DONE) begin
                // Wait in done until we see reset again.
                done <= 1'b1;
            end
        end
    end
endmodule



module MULTICYCLE_FC_LAYER_T
#(
   parameter Q0W = 8,
   parameter Q0I = 8,
   parameter Q1I = 8,
   parameter Q1W = 8,
   parameter IN_WIDTH = 3,
   parameter OUT_WIDTH = 3,
   parameter ACT = "NONE"
)
(
   input wire                              clock,
   input wire                                                add,
   input wire                                                reset,
   input wire [IN_WIDTH-1:0][Q0I + Q1I - 1:0]              input_v,
   output reg [OUT_WIDTH-1:0][Q0I + Q1I - 1:0]              output_v, 
   input wire [OUT_WIDTH-1:0][IN_WIDTH-1:0][Q0W + Q1W - 1 : 0] weight_v,
    input logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0] out_der,
    output logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1 :0] in_der_act
);
   // Implement a fully connected layer over the course of multiple cycles.
   // Basically just dot products and activation functions.
   // Each cycle take in a different section of the weight and input vectors.
   // Calculate all outputs in parallel.
   genvar i, j, k;
   logic [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] output_vw;  
   logic signed [OUT_WIDTH-1:0][Q0I + Q1I - 1:0] l_der;   
   logic signed [OUT_WIDTH-1:0][(Q0I + Q1I)*2 - 1:0] in_der_act2; 
    
   generate
      for (i=0; i < OUT_WIDTH; i=i+1) begin : output_loop
          MUL #(.Q0I(Q0I), .Q0W(Q0I), .Q1I(Q1I), .Q1W(Q1I)) multd (.input_v(l_der[i]), .weight(out_der[i]), .product(in_der_act2[i]));
             logic signed [(Q0I + Q1I)*2 - 1:0] in_der_act_i;
             assign in_der_act_i = (in_der_act2[i]/(2**Q1I));
            assign in_der_act[i] = in_der_act_i[Q0I + Q1I - 1:0];
          wire [Q0I + Q1I - 1:0]            output_i;
          MULTICYCLE_DOT #(.Q1I(Q1I),.Q1W(Q1W), .Q0W(Q0W), .Q0I(Q0I), .N(IN_WIDTH)) dot_mod(.input_v(input_v),
                      .weight_v(weight_v[i]),
                      .out(output_i),
                      .clock(clock), .reset(reset), .add(add));
      if (ACT == "TANH") begin
              TANH_LUT #(.Q0(Q0I), .Q1(Q1I), .MAX(4879)) tanhx (.in(output_i), .out(output_vw[i]), .clock(clock));
      end else if (ACT == "RELU") begin
         RELU #(.Q0(Q0I), .Q1(Q1I)) rel (.in(output_i), .out(output_vw[i]), .clock(clock));
         RELU_TD #(.Q0(Q0I), .Q1(Q1I)) rel_td (.in(output_vw[i]), .out(l_der[i]), .clock(clock));
      end else if (ACT == "SIGMOID") begin
             SIGMOID #(.Q0(Q0I), .Q1(Q1I), .MAX(1596)) sm (.in(output_i), .out(output_vw[i]), .clock(clock));
             SIGMOID_TD #(.Q0(Q0I), .Q1(Q1I)) sm_td (.in(output_vw[i]), .out(l_der[i]), .clock(clock));
          end else begin
             always @ (posedge clock) begin
             output_vw[i] <= output_i;
             end
      end
     end
   endgenerate
   
   always @ (posedge clock) begin
      output_v <= output_vw;
   end  
endmodule



module MULTICYCLE_DOT
#(
   parameter N = 4,
   parameter Q0I = 16,
   parameter Q0W = 16,
   parameter Q1W = 16,
   parameter Q1I = 16,
    parameter LONG_WIDTH = 2*Q0I+2*Q1I
)(
   input wire [N-1:0][Q0I+Q1I-1 :0] input_v,
   input [N-1:0][Q0W+Q1W-1:0] weight_v,
   input reset,
   input add,
   input clock,
   output [Q0I+Q1I-1:0] out
);
    // Module to take the dot product of two input vectors over the course of multiple cycles. 
    // Each cycle, a new set of inputs and weights are multiplied and added to a running sum. 
   genvar i;
   wire [N-1:0][LONG_WIDTH-1:0] long_products;
   wire signed [LONG_WIDTH-1:0] long_out_curr;
   reg signed [LONG_WIDTH-1:0] long_out_total;
   wire signed [LONG_WIDTH-1:0] out_pos;
   
    always @ (posedge clock) begin
        if (reset) begin
             long_out_total = 0;
         end else if (add) begin
             long_out_total = long_out_total + long_out_curr;
         end
    end
    
   //assign out = (long_out_total[Q1I-1])? long_out_total[Q0I+Q1I*2-1:Q1I] + 1 : long_out_total[Q0I + Q1I*2-1:Q1I]; // Effectively remove extra Q1 end bits.
   assign out = long_out_total[Q0I + Q1I*2 - 1: Q1I];
   generate
      for (i=0; i < N; i=i+1) begin : output_loop
          MUL #(.Q0W(Q0W), .Q0I(Q0I), .Q1W(Q1W), .Q1I(Q1I)) mul_mod(.input_v(input_v[i]),
                .weight(weight_v[i]),
                      .product(long_products[i]));     
      end
   endgenerate

   ADDER_TREE #(.Q(Q0I*2+Q1I*2), .N(N)) adder (.input_v(long_products), .sum(long_out_curr));
endmodule



// Multiply 2 Q value inputs - combinatorial
module MUL
#(
   parameter Q0I = 16,
   parameter Q0W = 16,
   parameter Q1I = 16,
   parameter Q1W = 16
)(
   input  wire signed  [Q0I + Q1I - 1 :0]  input_v,
   input  wire signed [Q0W + Q1W - 1 :0]  weight,
   output wire signed [(Q1I + Q0I)*2 - 1 :0] product
);
   // Calculate a product... Q0I and Q1I are doubled.
   wire signed [(Q0I + Q1I)*2 - 1 : 0] long_in;
   wire signed [(Q0I + Q1I)*2 - 1 : 0] long_weight;
   assign long_in = input_v;
   assign long_weight = weight*(2**(Q1I-Q1W));
   assign product = (long_in * long_weight);
 
endmodule

// Add a vector of inputs - combinatorial.
module ADDER_TREE
#(
   parameter Q = 16,
   parameter N = 8
)(
   input wire [N-1:0][Q-1:0] input_v,
   output wire [Q-1:0] sum
);
   // This is a recursive adder tree to add N different inputs.
   wire [Q-1:0] half1_sum;
   wire [Q-1:0] half2_sum; 
   
   generate
   if (N == 1) begin
       // If theres just one input, the output is that!
       assign sum = input_v[0]; 
   end else begin
      // Otherwise, instantiate two sub-trees and add them. 
      assign sum = half1_sum + half2_sum;
      ADDER_TREE #(.Q(Q), .N((N - (N%2))/2)) adder1(
                   .input_v(input_v[N-1:(N + (N%2))/2]), .sum(half1_sum));
      ADDER_TREE #(.Q(Q), .N((N + (N%2))/2)) adder2(
                   .input_v(input_v[((N + (N%2))/2)-1:0]), .sum(half2_sum));
   end
   endgenerate
endmodule

// Add a vector of inputs - combinatorial.
module TRANS_DERIV
#(
   parameter Q0 = 16,
   parameter Q1 = 16,
   parameter TYPE = "NONE"
)(
   input wire [Q0 + Q1 - 1:0] in,
   output wire [Q0 + Q1 - 1:0] out
);
   generate
   if (TYPE == "NONE") begin
       assign out = in;
   end else if (TYPE == "TANH") begin
       wire [(Q0+Q1)*2-1:0] prod;
       wire [(Q0+Q1)*2-1:0] outw;
       wire [(Q0+Q1)*2-1:0] outw2;
       MUL #(.Q0I(Q0), .Q0W(Q0), .Q1I(Q1), .Q1W(Q1)) testmul (.input_v(in), .weight(in), .product(prod));
       assign outw = (2**(Q1*2)) - prod;
       assign outw2 = outw >> Q1;
       assign out = ((outw[(Q0+Q1)*2-1] == 0) && (outw[(Q0+Q1)*2-1:Q0*2+Q1-1] > 0)) ? 2**(Q0+Q1-1)-1 : (((outw[(Q0+Q1)*2-1] == 1) && (outw[(Q0+Q1)*2-1:Q0*2+Q1-1] < 2**(Q0+1)-1))? 2**(Q0+Q1-1) :  outw2);
   end 
   endgenerate
endmodule
   


