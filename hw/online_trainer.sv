`timescale 1ns/1ns

// This module wraps around the inference module. It also instantiates the input RAM.
// And it does the final softmax function
// Layer widths, activations and datawidth are specified as input parameters.
// Weights, output index and input index are inputs and outputs
// This module wraps around the inference module. It also instantiates the input RAM.
// And it does the final softmax function
// Layer widths, activations and datawidth are specified as input parameters.
module multicycle_train_engine_outer
#(
    // Precision
    parameter Q0I = 8,
    parameter Q0W = 8,
    parameter Q1I = 8,
    parameter Q1W = 8,
    parameter QI = Q0I + Q1I,
    parameter INPUT_IDX_WIDTH = 8,
    parameter NUM_OUTS = 10,
    // Network architecture specification
    parameter NUM_LAYERS= 3,
    parameter [9:0][63:0] BATCHES_PER_LAYER = {64'd1,64'd1,64'd1,64'd1,64'd1,64'd1,64'd10,64'd10,64'd20,64'd784},
    parameter [9:0][63:0] WIDTHS = {64'd0, 64'd0, 64'b0, 64'd0, 64'b0, 64'd0, 64'd1, 64'd1, 64'd1, 64'd1},
    parameter [9:0][63:0] TWIDTHS = {WIDTHS[9]*BATCHES_PER_LAYER[9],WIDTHS[8]*BATCHES_PER_LAYER[8],WIDTHS[7]*BATCHES_PER_LAYER[7],WIDTHS[6]*BATCHES_PER_LAYER[6],WIDTHS[5]*BATCHES_PER_LAYER[5],WIDTHS[4]*BATCHES_PER_LAYER[4],WIDTHS[3]*BATCHES_PER_LAYER[3],WIDTHS[2]*BATCHES_PER_LAYER[2],WIDTHS[1]*BATCHES_PER_LAYER[1],WIDTHS[0]*BATCHES_PER_LAYER[0]},
    parameter [63:0] NUM_WEIGHTS = TWIDTHS[0]*TWIDTHS[1]+TWIDTHS[1]*TWIDTHS[2]+TWIDTHS[2]*TWIDTHS[3]+TWIDTHS[3]*TWIDTHS[4]+TWIDTHS[4]*TWIDTHS[5]+TWIDTHS[5]*TWIDTHS[6]+TWIDTHS[6]*TWIDTHS[7]+TWIDTHS[7]*TWIDTHS[8]+TWIDTHS[8]*TWIDTHS[9],
    parameter [63:0] NUM_WEIGHTS0 = WIDTHS[0]*TWIDTHS[1],
    parameter [63:0] NUM_WEIGHTS1 = TWIDTHS[1]*TWIDTHS[2],
    parameter [63:0] NUM_WEIGHTS2 = TWIDTHS[2]*TWIDTHS[3],
    // Weights to load initially. 
    parameter WEIGHT0_FILE = "./mem_files/weights0.mif",
    parameter WEIGHT1_FILE = "./mem_files/weights1.mif",
    parameter WEIGHT2_FILE = "./mem_files/weights2.mif"
) 
(
    // Control signals
    input wire clock, input wire reset, input logic start, input logic train,
    output logic done, input logic [15:0] lrate,
    // Outputs
    output logic [INPUT_IDX_WIDTH-1:0]               output_idx,
    output signed [NUM_OUTS-1:0][Q0I + Q1I - 1:0] output_v,
    // Interface with input memory.
    input logic [15:0] mem_input,
    output logic [9:0] mem_address,
    input logic [7:0] expected_out
);
    // Register the softmax output
    logic [INPUT_IDX_WIDTH-1:0] max_idx;
    always@(posedge clock) begin
        output_idx <= max_idx;
    end
    GET_MAX #(.W(QI), .N(NUM_OUTS), .IDX_W(INPUT_IDX_WIDTH)) gm (.input_v(output_v), .max_idx(max_idx));

    // Internal signals (between inf engine and weight arrays)
    wire [NUM_WEIGHTS0-1:0][QI-1:0]  w0;
    wire [NUM_WEIGHTS1-1:0][QI-1:0]  w1;
    wire [NUM_WEIGHTS2-1:0][QI-1:0]  w2;
    wire [NUM_WEIGHTS0-1:0][QI-1:0]  w0_new;
    wire [NUM_WEIGHTS1-1:0][QI-1:0]  w1_new;
    wire [NUM_WEIGHTS2-1:0][QI-1:0]  w2_new;
    logic wwr0, wwr1, wwr2;
    
    wire signed [NUM_OUTS-1:0][QI - 1:0] output_vi;
    wire [WIDTHS[0]-1:0][QI-1:0]  input_v;
    wire [63:0]  batch_idx;
    assign output_v = output_vi;   
    
    // Instantiate the inference engine
    multicycle_train_engine #(.Q1W(8),.Q1I(8), .Q0W(8), .Q0I(8), .NUM_LAYERS(3), 
        .BATCHES_PER_LAYER(BATCHES_PER_LAYER), .WIDTHS(WIDTHS)) ie0x (
        .train(train), .clock(clock), .reset(reset), .done(done), .start(start), .lrate(lrate),  // Control
        // Input / output signals
        .batch_idx(batch_idx), .input_v(input_v), .expected_out(expected_out), .output_v(output_vi), 
        // Weight signals
        .weight_v2(w2), .weight_v1(w1), .weight_v0(w0), .weight_v2_out(w2_new), .weight_v1_out(w1_new), 
        .weight_v0_out(w0_new), .weight_wr0(wwr0), .weight_wr1(wwr1), .weight_wr2(wwr2));
      
    // Store weights - 
    flex_ram #(.NUM_WORDS(2**10), .ADDR_WIDTH(10), .WORD_SIZE(16*20), .MIF_FILE(WEIGHT0_FILE), 
        .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=W0")) wr0x (
        .clock(clock), .wren(wwr0), .q(w0), .data(w0_new), .address(batch_idx[9:0]));
    flex_ram #(.NUM_WORDS(1), .ADDR_WIDTH(1), .WORD_SIZE(16*10*20), .MIF_FILE(WEIGHT1_FILE), 
        .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=W1")) wr1x (
        .clock(clock), .wren(wwr1), .q(w1), .data(w1_new), .address(1'b0)); 
    flex_ram #(.NUM_WORDS(1), .ADDR_WIDTH(1), .WORD_SIZE(16*10*10), .MIF_FILE(WEIGHT2_FILE), 
        .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=W2")) wr2x (
        .clock(clock), .wren(wwr2), .q(w2), .data(w2_new), .address(1'b0));  
    assign mem_address = batch_idx[9:0];
    assign input_v = mem_input;
endmodule

// The inference engine is just NUM_LAYERS fully connected layers.
// Layer widths, activations and datawidth are specified as input parameters.
// Weights, inputs and outputs are on an input bus
module multicycle_train_engine
#(
    parameter NUM_LAYERS = 3,
    parameter Q0I = 8,
    parameter Q0W = 8,
    parameter Q1I = 8,   
    parameter Q1W = 8,
    parameter [9:0][63:0] BATCHES_PER_LAYER = {64'd1,64'd1,64'd1,64'd1,64'd1,64'd1,64'd10,64'd10,64'd20,64'd784},
    parameter [9:0][63:0] WIDTHS = {64'd0, 64'd0, 64'd0, 64'd0, 64'd0, 64'd0, 64'd1, 64'd1, 64'd1, 64'd1},
    parameter [9:0][63:0] TWIDTHS = {WIDTHS[9]*BATCHES_PER_LAYER[9],WIDTHS[8]*BATCHES_PER_LAYER[8],WIDTHS[7]*BATCHES_PER_LAYER[7],WIDTHS[6]*BATCHES_PER_LAYER[6],WIDTHS[5]*BATCHES_PER_LAYER[5],WIDTHS[4]*BATCHES_PER_LAYER[4],WIDTHS[3]*BATCHES_PER_LAYER[3],WIDTHS[2]*BATCHES_PER_LAYER[2],WIDTHS[1]*BATCHES_PER_LAYER[1],WIDTHS[0]*BATCHES_PER_LAYER[0]},
    parameter [63:0] NUM_WEIGHTS0 = 1*TWIDTHS[1],
    parameter [63:0] NUM_WEIGHTS1 = TWIDTHS[1]*TWIDTHS[2],
    parameter [63:0] NUM_WEIGHTS2 = TWIDTHS[2]*TWIDTHS[3],
    parameter [63:0] NUM_OUTPUTS = 10,
    parameter QI = Q0I + Q1I,
    parameter QW = Q0W + Q1W  
)
(
    // Control logic
    input wire  clock, input wire reset, input wire start, input wire train,
    output logic done, input logic [15:0] lrate,
    // Weight inputs, outputs
    input wire [NUM_WEIGHTS0-1:0][QW - 1:0] weight_v0,
    input wire [NUM_WEIGHTS1-1:0][QW - 1:0] weight_v1,
    input wire [NUM_WEIGHTS2-1:0][QW - 1:0] weight_v2,
    output logic weight_wr0, output logic weight_wr1, output logic weight_wr2,
    output logic [NUM_WEIGHTS0-1:0][QW - 1:0] weight_v0_out,
    output logic [NUM_WEIGHTS1-1:0][QW - 1:0] weight_v1_out,
    output logic [NUM_WEIGHTS2-1:0][QW - 1:0] weight_v2_out,
    // Input and output neurons
    output wire [NUM_OUTPUTS-1:0][QI - 1:0] output_v,
    input wire [WIDTHS[0]-1:0][QI-1:0] input_v,
    input logic [7:0] expected_out, // Needed for training
    output logic [63:0] batch_idx   // Index into inputs
); 
    // Should we write the weights?
    logic l0_wr;
    assign weight_wr0 = l0_wr && train;
    assign weight_wr1 = done && train;
    assign weight_wr2 = done && train;

    // Internal signals between layers. 
    wire [TWIDTHS[1]-1:0][QI - 1:0] output_v0;
    wire [TWIDTHS[2]-1:0][QI - 1:0] output_v1;
    wire [TWIDTHS[3]-1:0][QI - 1:0] output_v2;
    wire [TWIDTHS[1]-1:0][QI - 1:0] out_der_0;
    wire [TWIDTHS[2]-1:0][QI - 1:0] out_der_1;
     
    // Cotnrol and statemachine signals.
    wire done0, done1, done2;
    logic reset0, reset1, reset2, start_bp0, start_bp1, start_bp2;
    enum {IDLE_I, START_I, WAIT_I0, WAIT_I1, WAIT_I2, NEXT_I, DONE_I, DONE_I2, DONE_I3, START_BP, BP2, BP1, BP0} state;
    
    // Calculate the output error
    logic [NUM_OUTPUTS-1:0][QI-1:0] one_hot_exp;
    logic [NUM_OUTPUTS-1:0][QI-1:0] out_der;
    genvar i, t;
    generate
        for (i=0; i < NUM_OUTPUTS; i=i+1) begin : output_loop
            assign one_hot_exp[i] = (expected_out == i)? (16'b1 << Q1I) : {QI{1'b0}};
            assign out_der[i] = one_hot_exp[i] - output_v[i]; 
        end
    endgenerate
      
    // Do inference through all layers - and then backpropagate
    initial state = IDLE_I;
    always @ (posedge clock) begin
        if (reset == 1'b1) begin
            state <= IDLE_I; 
            reset0 <= 1'b0;
            reset1 <= 1'b0;
            reset2 <= 1'b0;
            start_bp2 <= 1'b0;
            start_bp1 <= 1'b0;
            start_bp0 <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
            IDLE_I: begin // Wait for start signal
                done <= 1'b0;
                state <= (start)? START_I : IDLE_I;
                reset0 <= start;
            end
            START_I: begin // Start inference.
                state <= WAIT_I0;
                reset0 <= 1'b0;
            end
            WAIT_I0: begin // Wait for L0 inference
                reset0 <= 1'b0;
                if (done0) begin
                    state <= WAIT_I1;
                    reset1 <= 1'b1;
                end
            end 
            WAIT_I1: begin // Wait for L1 inference    
                reset1 <= 1'b0; 
                if (done1) begin
                    state <= WAIT_I2;
                    reset2 <= 1'b1;
                end
            end 
            WAIT_I2: begin  // Wait for L2 inference
                reset2 <= 1'b0;
                if (done2) begin
                    state <= START_BP ;
                    start_bp2 <= (train);
                end
            end 
            START_BP: begin // Start backpropagation
                state <= (train) ? BP2 : DONE_I;
                start_bp2 <= 1'b0;
            end
            BP2: begin // Backpropagate layer 2
                state <= (done2)? BP1 : BP2;
                start_bp1 <= done2;
            end
            BP1: begin // Backpropagate layer 1
                start_bp1 <= 1'b0;
                state <= (done1) ? BP0 : BP1;
                start_bp0 <= done1;
            end
            BP0: begin // Backpropagate layer 0
                start_bp0 <= 1'b0;
                state <= (done0)? DONE_I : BP0;
            end
            DONE_I: begin // Go right to idle. 
                done <= 1'b1;
                state <= DONE_I2;
            end
            DONE_I2: begin // Go right to idle. 
                done <= 1'b1;
                state <= DONE_I3;
            end
            DONE_I3: begin // Go right to idle. 
                done <= 1'b1;
                state <= IDLE_I;
            end
            endcase
        end 
    end 
    
    // Instantiate the layers
    multicycle_fc_layer_outer_l0_t #(
        .BATCHES(BATCHES_PER_LAYER[0]), .Q1W(Q1W), .Q1I(Q1I), .Q0I(Q0I), .Q0W(Q0W), 
        .IN_WIDTH(WIDTHS[0]), .OUT_WIDTH(TWIDTHS[1]), .ACT("RELU")) fc0 (
        .weight_write(l0_wr), .lrate(lrate), .weight_out(weight_v0_out), .start_bp(start_bp0),
        .done(done0), .clock(clock), .reset(reset0), .input_v(input_v), .weight_v(weight_v0), 
        .output_v(output_v0), .batch_idx(batch_idx),.out_der(out_der_0));     
    MULTICYCLE_FC_LAYER_OUTER_T #(
        .BATCHES(BATCHES_PER_LAYER[1]), .Q1I(Q1I), .Q1W(Q1W), .Q0I(Q0I), .Q0W(Q0W), 
        .IN_WIDTH(WIDTHS[1]), .OUT_WIDTH(TWIDTHS[2]), .ACT("RELU")) fc1 (
        .lrate(lrate), .weight_out(weight_v1_out), .start_bp(start_bp1), .done(done1), .clock(clock),
        .reset(reset1),  .input_v(output_v0), .weight_v(weight_v1), .output_v(output_v1),
        .out_der(out_der_1), .in_der(out_der_0));
    MULTICYCLE_FC_LAYER_OUTER_T #(
        .BATCHES(BATCHES_PER_LAYER[2]), .Q1I(Q1I),.Q1W(Q1W), .Q0I(Q0I), .Q0W(Q0W), 
        .IN_WIDTH(WIDTHS[2]), .OUT_WIDTH(TWIDTHS[3]), .ACT("SIGMOID")) fc2 (
        .lrate(lrate),.weight_out(weight_v2_out), .start_bp(start_bp2), .done(done2), .clock(clock), 
        .reset(reset2),  .input_v(output_v1), .weight_v(weight_v2), .output_v(output_v), 
        .out_der(out_der), .in_der(out_der_1));
endmodule
