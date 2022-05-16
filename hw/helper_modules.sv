`timescale 1ns/1ns

module xprod_helper #(parameter Q = 8, parameter arr_size = 10) (
    input logic signed [Q+Q-1:0] in_val,
    input logic signed [Q+Q-1:0]  out_val,
    input logic [Q-1:0]  lrate,
    input logic clock,
    input logic signed [Q+Q-1:0]  to_add,
    output logic signed [Q+Q-1:0] in_x_out_m_s,
    output logic signed [Q+Q-1:0] prod_final,
    output logic signed [Q+Q-1:0] inxx,
    output logic signed [Q+Q-1:0] result
);

    logic  signed [(Q+Q)*2-1:0] in_x_out_m;
    MUL #(.Q0I(Q), .Q0W(Q), .Q1I(Q), .Q1W(Q)) multd (.input_v(in_val), .weight(out_val), .product(in_x_out_m));

    // Multiply the product by the learning rate.
    logic signed [(Q + Q)*2 - 1 :0] i_o_lr;
    MUL #(.Q0I(Q), .Q0W(0), .Q1I(Q), .Q1W(Q)) multd2 (.input_v(in_x_out_m_s), .weight(lrate), .product(i_o_lr));
     
    logic signed [(Q + Q)*2 - 1 :0] prod_abs;
    assign prod_abs = (i_o_lr[(Q + Q)*2 - 1]) ? -i_o_lr : i_o_lr;
    logic signed [(Q + Q)*2 - 1 :0] prod_abs_rounded;
    assign prod_abs_rounded = prod_abs/(2**Q); 
    always @(posedge clock) begin
    in_x_out_m_s <= in_x_out_m / ((16'd2)**Q);
        prod_final <= (i_o_lr[(Q + Q)*2 - 1]) ? -prod_abs_rounded[(Q + Q)-1:0] : prod_abs_rounded[(Q + Q)-1:0]; 
    end 
    assign inxx = to_add;
   
    // Add to input
    assign result = to_add + prod_final;
endmodule


module reset_module #(parameter HINT = "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RESET") (
    input wire clock,
    output wire reset
);
    flex_ram  #(.NUM_WORDS(8), .ADDR_WIDTH(4), .WORD_SIZE(1), .MIF_FILE("./mem_files/reset.mif"), .HINT(HINT)) ir2 (
                .address(4'b0), .clock(clock), .data(1'b0), .wren(1'b0), .q(reset));
endmodule


module entry_module #(parameter HINT = "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=EN", parameter WIDTH=16) (
    input wire clock,
    output logic [WIDTH-1:0] reset
);
    flex_ram  #(.NUM_WORDS(1), .ADDR_WIDTH(1), .WORD_SIZE(WIDTH), .MIF_FILE(""), .HINT(HINT)) ir2 (
                .address(1'b0), .clock(clock), .data(1'b0), .wren(1'b0), .q(reset));
endmodule


// Convert binary input to hex display.
module hex_display(
    input wire clock,
    output wire [6:0] HEX,
    input wire [8:0]  data
);
    reg [6:0] hex_reg;
    always @(posedge clock) begin
        if (data == 0) begin
            hex_reg <= 7'b1000000; 
        end else if (data == 1) begin
            hex_reg <= 7'b1111001;
        end else if (data == 2) begin
            hex_reg <= 7'b0100100;
        end else if (data == 3) begin
            hex_reg <= 7'b0110000;
        end else if (data == 4) begin
            hex_reg <= 7'b0011000;
        end else if (data == 5) begin
            hex_reg <= 7'b0010010;
        end else if (data == 6) begin
            hex_reg <= 7'b0000010;
        end else if (data == 7) begin
            hex_reg <= 7'b1111000;
        end else if (data == 8) begin
            hex_reg <= 7'b0000000;
        end else if (data == 9) begin
            hex_reg <= 7'b0010000;
        end else begin
            hex_reg <= 7'b0111111;
        end
    end
    assign HEX = hex_reg;
endmodule


// Single port quartus RAM module with flexible dimensions. 
// Size of RAM determined through input parameters.
module flex_ram
#(
    parameter NUM_WORDS = 256,
    parameter ADDR_WIDTH = 8,
    parameter WORD_SIZE = 64,
    parameter MIF_FILE="./mem_files/input_data.mif",
    parameter HINT="ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=NONE"
)(
    address, clock, data, wren, q
);

    input [ADDR_WIDTH-1:0] address;
    input clock;
    input [WORD_SIZE-1:0] data;
    input wren;
    output [WORD_SIZE-1:0]  q;
    wire [WORD_SIZE-1:0] sub_wire0;
    wire [WORD_SIZE-1:0] q = sub_wire0[WORD_SIZE-1:0];
    
    altsyncram altsyncram_component (
        .address_a (address),
        .clock0 (clock),
        .data_a (data),
        .wren_a (wren),
        .q_a (sub_wire0),
        .aclr0 (1'b0),
        .aclr1 (1'b0),
        .address_b (1'b1),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a (1'b1),
        .byteena_b (1'b1),
        .clock1 (1'b1),
        .clocken0 (1'b1),
        .clocken1 (1'b1),
        .clocken2 (1'b1),
        .clocken3 (1'b1),
        .data_b (1'b1),
        .eccstatus (),
        .q_b (),
        .rden_a (1'b1),
        .rden_b (1'b1),
        .wren_b (1'b0));
    defparam
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.init_file = MIF_FILE,
        altsyncram_component.intended_device_family = "Cyclone IV GX",
        altsyncram_component.lpm_hint = HINT,
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = NUM_WORDS,
        altsyncram_component.operation_mode = "SINGLE_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_reg_a = "CLOCK0",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
        altsyncram_component.widthad_a = ADDR_WIDTH,
        altsyncram_component.width_a = WORD_SIZE,
        altsyncram_component.width_byteena_a = 1;
endmodule

module RELU_TD
#(
    parameter Q0 = 8,
    parameter Q1 = 8,
    parameter Q = Q0+Q1
)(
    input wire clock,
    input wire [Q-1:0] in,
    output logic [Q-1:0] out
);
    always @ (posedge clock) begin
        if (in == 0) begin
            out <= 0;
        end else begin
            out <= (16'b1 << Q1);
        end
    end
endmodule

module RELU
#(
    parameter Q0 = 8,
    parameter Q1 = 8,
    parameter Q = Q0+Q1
)(
    input wire clock,
    input wire [Q-1:0] in,
    output logic [Q-1:0] out
);
    always @ (posedge clock) begin
        if (in[Q-1]) begin
            out <= 0;
        end else begin
            out <= in;
        end
    end
endmodule

module TANH_LUT
#(
    parameter Q0 = 10,
    parameter Q1 = 16,
    parameter MAX=0,
    parameter Q = Q0+Q1
)(
    input wire clock,
    input wire [Q0+Q1-1:0] in,
    output wire [Q0+Q1-1:0] out
);
    // TANH function is implemented using a LUT.
    // To conserve resources we also have some logic
    // here though for when the output is -1 or 1.
    reg unsigned [Q-1:0]     addr_reg;
    logic [Q-1:0]     outr;
    logic [Q-1:0]     inp;
    
    // inp is the absolute value of in
    assign inp = (in[Q-1]) ? -in : in;
    reg [Q-1:0] mem [MAX:0];
    initial begin
        $readmemb("./mem_files/tanh_data.mem", mem);    
    end
    
    // Register the address
    always @ (posedge clock) begin
        addr_reg <= inp[Q-2:0];
    end
    
    always @ (*) begin
        // Check based on the input absolute value, if the output is 1.
        if (inp > MAX) begin
            // In which case set the output to 1.
            outr <= 16'd1 << Q1;
        end else begin
            // Otherwise use the LUT
            outr <= mem[addr_reg];
        end
    end
    
    // Invert the output if the input was negative.
    assign out = (in[Q-1]) ? -outr : outr;
endmodule
   

module SIGMOID_TD
#(
    parameter Q0 = 10,
    parameter Q1 = 16,
    parameter Q = Q0+Q1
)(
    input wire clock,
    input wire signed [Q0+Q1-1:0] in,
    output logic signed [Q0+Q1-1:0] out
);
    always @ (posedge clock) begin
        out <= (in * ((16'b1 << Q1) - in)) / (16'b1 << Q1);
    end
endmodule


module SIGMOID
#(
    parameter Q0 = 10,
    parameter Q1 = 16,
    parameter MAX=0,
    parameter Q = Q0+Q1
)(
    input wire clock,
    input wire [Q0+Q1-1:0] in,
    output wire [Q0+Q1-1:0] out
);
    // TANH function is implemented using a LUT.
    // To conserve resources we also have some logic
    // here though for when the output is -1 or 1.
    reg unsigned [Q-1:0]     addr_reg;
    logic [Q-1:0]     outr;
    logic [Q-1:0]     inp;
    
    // inp is the absolute value of in
    assign inp = (in[Q-1]) ? -in : in;
    reg [Q-1:0] mem [MAX:0];
    initial begin
        $readmemb("./mem_files/sigmoid.mem", mem);    
    end
    
    // Register the address
    always @ (posedge clock) begin
        addr_reg <= inp[Q-2:0];
    end
    
    always @ (*) begin
        // Check based on the input absolute value, if the output is 1.
        if (inp > MAX) begin
            // In which case set the output to 1.
            outr <= 16'd1 << Q1;
        end else begin
            // Otherwise use the LUT
            outr <= mem[addr_reg];
        end
    end
    
    // Invert the output if the input was negative.
    assign out = (in[Q-1]) ? (16'b1 << Q1)-outr : outr;
endmodule


// Take dot product of an input vector and a weight vector.
module GET_MAX
#(
    parameter N = 4,
    parameter W = 16,
    parameter IDX_W = 8
)(
    input wire [N-1:0][W-1 :0] input_v,
    output logic  [IDX_W-1:0] max_idx,
    output logic [W-1:0] max_val
);
    // Calculate a dot product using an adder tree and N multipliers
    genvar i;
    wire signed [W-1:0] curr_max_val;
    wire [IDX_W-1:0] curr_max_idx;
    logic big0, big1, big2, big3, big4, big5, big6, big7, big8, big9;
    assign big0 = (input_v[0] > input_v[1]) &&
                  (input_v[0] > input_v[2]) &&
                  (input_v[0] > input_v[3]) &&
                  (input_v[0] > input_v[4]) &&
                  (input_v[0] > input_v[5]) &&
                  (input_v[0] > input_v[6]) &&
                  (input_v[0] > input_v[7]) &&
                  (input_v[0] > input_v[8]) &&
                  (input_v[0] > input_v[9]);
    assign big1 = (input_v[1] > input_v[0]) &&
                  (input_v[1] > input_v[2]) &&
                  (input_v[1] > input_v[3]) &&
                  (input_v[1] > input_v[4]) &&
                  (input_v[1] > input_v[5]) &&
                  (input_v[1] > input_v[6]) &&
                  (input_v[1] > input_v[7]) &&
                  (input_v[1] > input_v[8]) &&
                  (input_v[1] > input_v[9]);
    assign big2 = (input_v[2] > input_v[1]) &&
                  (input_v[2] > input_v[0]) &&
                  (input_v[2] > input_v[3]) &&
                  (input_v[2] > input_v[4]) &&
                  (input_v[2] > input_v[5]) &&
                  (input_v[2] > input_v[6]) &&
                  (input_v[2] > input_v[7]) &&
                  (input_v[2] > input_v[8]) &&
                  (input_v[2] > input_v[9]);
    assign big3 = (input_v[3] > input_v[1]) &&
                  (input_v[3] > input_v[2]) &&
                  (input_v[3] > input_v[0]) &&
                  (input_v[3] > input_v[4]) &&
                  (input_v[3] > input_v[5]) &&
                  (input_v[3] > input_v[6]) &&
                  (input_v[3] > input_v[7]) &&
                  (input_v[3] > input_v[8]) &&
                  (input_v[3] > input_v[9]);
    assign big4 = (input_v[4] > input_v[1]) &&
                  (input_v[4] > input_v[2]) &&
                  (input_v[4] > input_v[3]) &&
                  (input_v[4] > input_v[0]) &&
                  (input_v[4] > input_v[5]) &&
                  (input_v[4] > input_v[6]) &&
                  (input_v[4] > input_v[7]) &&
                  (input_v[4] > input_v[8]) &&
                  (input_v[4] > input_v[9]);
    assign big5 = (input_v[5] > input_v[1]) &&
                  (input_v[5] > input_v[2]) &&
                  (input_v[5] > input_v[3]) &&
                  (input_v[5] > input_v[4]) &&
                  (input_v[5] > input_v[0]) &&
                  (input_v[5] > input_v[6]) &&
                  (input_v[5] > input_v[7]) &&
                  (input_v[5] > input_v[8]) &&
                  (input_v[5] > input_v[9]);
    assign big6 = (input_v[6] > input_v[1]) &&
                  (input_v[6] > input_v[2]) &&
                  (input_v[6] > input_v[3]) &&
                  (input_v[6] > input_v[4]) &&
                  (input_v[6] > input_v[5]) &&
                  (input_v[6] > input_v[0]) &&
                  (input_v[6] > input_v[7]) &&
                  (input_v[6] > input_v[8]) &&
                  (input_v[6] > input_v[9]);
    assign big7 = (input_v[7] > input_v[1]) &&
                  (input_v[7] > input_v[2]) &&
                  (input_v[7] > input_v[3]) &&
                  (input_v[7] > input_v[4]) &&
                  (input_v[7] > input_v[5]) &&
                  (input_v[7] > input_v[6]) &&
                  (input_v[7] > input_v[0]) &&
                  (input_v[7] > input_v[8]) &&
                  (input_v[7] > input_v[9]);
    assign big8 = (input_v[8] > input_v[1]) &&
                  (input_v[8] > input_v[2]) &&
                  (input_v[8] > input_v[3]) &&
                  (input_v[8] > input_v[4]) &&
                  (input_v[8] > input_v[5]) &&
                  (input_v[8] > input_v[6]) &&
                  (input_v[8] > input_v[7]) &&
                  (input_v[8] > input_v[0]) &&
                  (input_v[8] > input_v[9]);
    assign max_val = big0? input_v[0] : big1? input_v[1] : big2? input_v[2] : big3? input_v[3] : 
                     big4? input_v[4] : big5? input_v[5] : big6? input_v[6] : big7? input_v[7] :
                     big8? input_v[8] : input_v[9]; 
    assign max_idx = big0? 0 : big1? 1 : big2? 2 : big3? 3 : big4? 4 : big5? 5 : big6? 6 : big7? 7 : big8? 8 : 9; 

endmodule


// Take dot product of an input vector and a weight vector.
module GET_VAL_AT_IDX
#(
    parameter [15:0] N = 4,
    parameter W = 16,
    parameter IDX_W = 8
)(
    input wire [N-1:0][W-1 :0] input_v,
    output logic  [IDX_W-1:0] max_idx,
    output logic [W-1:0] max_val
);
    // Calculate a dot product using an adder tree and N multipliers
    genvar i;
    wire signed [W-1:0] curr_max_val;
    wire signed [W-1:0] curr_val;
    assign curr_val = input_v[0];
    wire [IDX_W-1:0] curr_max_idx;
   
    generate
        if (N > 1) begin
            GET_MAX #(.W(W), .N(N-16'b1), .IDX_W(IDX_W)) mul_mod(
                      .input_v(input_v[N-1:1]),
                      .max_val(curr_max_val), .max_idx(curr_max_idx));    

            always @ (*) begin
                if (curr_max_val > curr_val) begin
                    max_val = curr_max_val;
                    max_idx = curr_max_idx + 1;
                end else begin
                    max_val = curr_val;
                    max_idx = 0;
                end
            end 
        end else begin
            assign max_val = input_v;
            assign max_idx = 0; 
        end 
    endgenerate
endmodule


// Copy a section of memory from DRAM into SRAM on start.
module copy_dram_to_sram (
    // Clocking and control
    input logic clk, input logic rst_n,
    input logic start, output logic done,
    input logic [31:0] num_words, // number of 16bit words to read from memory
    input logic [31:0] mem_baddr, // base address (in terms of 16bit words)
     
    // master (SDRAM-facing)
    input logic master_waitrequest, output logic [31:0] master_address,
    output logic master_read, input logic [31:0] master_readdata, input logic master_readdatavalid,
    output logic master_write, output logic [31:0] master_writedata,
     
    // Interface with SRAM
    output logic mem_write, output logic [15:0] mem_writedata, output logic [31:0] mem_address);
    logic [31:0] iter, mem_baddr_r;
    logic [15:0] mem_writedata_next;
    enum {IDLE, READ, WRITE, INCR, COPY, DONE} state;
    assign master_write = 1'b0;
    assign master_writedata = 32'b0;
    assign master_read = ((state === COPY) && (iter < num_words))? 1'b1 : 1'b0;
    assign master_address = 32'h09000000 + (mem_baddr_r << 1) + (iter << 1);
    assign mem_address = iter;
    
    always_ff @(posedge clk or negedge rst_n) begin 
        if (~rst_n) begin // Reset everything
            mem_baddr_r        <= 32'b0;
            iter               <= 32'b0;
            mem_writedata_next <= 16'b0;
            done               <= 1'b0;
            state              <= IDLE;
            mem_write          <= 1'b0;
        end else begin    
            case(state)
                IDLE: if (start) begin // wait for start
                    state <= COPY;
                    mem_baddr_r <= mem_baddr;
                    iter <= 32'b0;
                end
                COPY: begin // copy until we reach num_words
                    if (iter < num_words) begin
                        state <= (master_waitrequest)? COPY : READ;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                   end
                end
                READ: begin
                    mem_writedata <= master_readdata[15:0];
                    mem_writedata_next <= master_readdata[31:16];
                    if (master_readdatavalid) begin
                        state <= WRITE;    
                        mem_write <= 1'b1;
                    end
                end
                WRITE: begin
                    state <= INCR;
                    iter <= iter + 32'b1;
                    mem_writedata <= mem_writedata_next;
                end
                INCR: begin
                    mem_write <= 1'b0;
                    state <= COPY;
                    iter <= iter + 32'b1;
                end
                DONE: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
