// Get it to work for 250 inputs...

// Then
// show accuracy.
// Get the whole thing to work with 10k inputs ~ 90% accuracy

// Then need to break down the accuracy into chunks and track it

// Then need to load in the changing data.


module accel_core(input logic clk, input logic rst_n,
                // slave (CPU-facing)
                output logic        slave_waitrequest,
                input logic [3:0]   slave_address,
                input logic         slave_read, output logic [31:0] slave_readdata,
                input logic         slave_write, input logic [31:0] slave_writedata,
                // master (SDRAM-facing)
                input logic         master_waitrequest,
                output logic [31:0] master_address,
                output logic        master_read, input logic [31:0] master_readdata, input logic master_readdatavalid,
                output logic        master_write, output logic [31:0] master_writedata,
					 output logic [9:0] leds,
					 input logic [2:0] keys,
					 input logic [9:0] switches);
   parameter INPUT_FILE = "/home/esther/training/model/mnist_out.mif";
	parameter OUTPUT_FILE = "/home/esther/training/model/mnist_out.mif";
	parameter FULL_INPUT_SIZE = 786; // size in 16bit words
   parameter PAIR_COUNT_WIDTH = 32;
   parameter OUTPUT_WIDTH = 8;
	parameter SECTION_SIZE = 100;
   parameter OUTPUT_COUNT = 10;
	logic [31:0] pair_count;
	assign pair_count = 10000*switches[2:0];
	logic [31:0] start_index;
	assign start_index = switches[5:3]*10000*FULL_INPUT_SIZE;
   enum {IDLE, READ, COPY, GET_SOLUTION0, GET_SOLUTION1, GET_SOLUTION2, INF, INCR, DONE} state;
	logic copy_start, copy_done, inf_start, inf_done;
	logic [31:0] input_index, input_size, curr_index, section_index;
   reg [PAIR_COUNT_WIDTH-1:0] correct_count;  // Keep track of current accuracy
   reg [PAIR_COUNT_WIDTH-1:0] curr_correct_count;  // Keep track of current accuracy
   wire [OUTPUT_WIDTH-1:0] expected_idx;      // Correct answer to current inference
   logic [OUTPUT_WIDTH-1:0] solution;         // Calculated answer to current inference
	//logic [7:0] accuracy;
	//logic [31:0] accuracy_wide;
   //assign accuracy_wide = (100*correct_count)/(input_index+1);  // lower LEDs are current accuracy / 10
   //assign curr_accuracy_wide = (100*curr_correct_count)/SECTION_SIZE;  // lower LEDs are current accuracy / 10
   //assign accuracy = accuracy_wide[7:0];
   //assign curr_accuracy = curr_accuracy_wide[15:0];
	logic write_answer;

	// In university monitor program memory viewer, inputs are at
	// 0, 61c etc.
	
	// State machine to communicate with the CPU.
   always@(posedge clk, negedge rst_n) begin
      if (~rst_n) begin
		   // On reset, go to idle state and reset everything.
         state <= IDLE;
			copy_start <= 1'b0;
			inf_start <= 1'b0;
         slave_readdata = 32'd0;
			//leds <= 9'd0;
			section_index <= 32'd0;
			input_index <= 32'd0;
			input_size <= 32'd0;
			correct_count <= 32'd0;
			curr_correct_count <= 32'd0;
      end else begin
         case (state)
            IDLE: begin // Wait for signal from CPU
               if (slave_write === 1) begin
					   if (slave_address == 4'd2) begin
                      state <= COPY;
							 copy_start <= 1'b1;
							 input_size <= FULL_INPUT_SIZE;
		              	correct_count <= 32'd0;
		              	curr_correct_count <= 32'd0;
							input_index <= 0;
					   end
               end else if ( slave_read === 1 ) begin
                  state <= slave_address == 4'd0 ? READ : IDLE;
               end else begin
                  state <= IDLE;
               end
                  slave_waitrequest = ((slave_read | slave_write) === 1) ? 1 : 0;
            end
            READ: begin // The CPU wants some information
               state <= DONE;
               slave_waitrequest = 1;
               slave_readdata = 32'b0;
            end
            COPY: begin // Copy an image into onchip memory
               state <= (copy_done == 1'b1)? GET_SOLUTION0 : COPY;
               inf_start <= (copy_done == 1'b1);
					copy_start <= 1'b0;
            end
            GET_SOLUTION0: begin // Copy an image into onchip memory
               state <= GET_SOLUTION1;
            end
            GET_SOLUTION1: begin // Copy an image into onchip memory
               state <= GET_SOLUTION2;
            end
            GET_SOLUTION2: begin // Copy an image into onchip memory
               state <= INF;
					expected_idx <= input_data;
            end
            INF: begin // Perform inference
				   if (inf_done == 1'b1) begin
					    state <= INCR;
						 write_answer <= (curr_index == (SECTION_SIZE-1));
		             if (solution == expected_idx) begin
                        correct_count <= correct_count + 1'b1;
                        curr_correct_count <= curr_correct_count + 1'b1;
		             end
					end
					inf_start <= 1'b0;
            end
            INCR: begin // Next index
				   write_answer <= 1'b0;
				   if (input_index < pair_count) begin
	                input_index <= input_index + 1;
						 if (curr_index == (SECTION_SIZE-1)) begin
						     curr_index <= 0;
							  curr_correct_count <= 0;
							  section_index <= section_index + 1;
						 end else begin
	                    curr_index <= curr_index + 1;
						 end
						 state <= COPY;
						 copy_start <= 1'b1;
				   end else begin
                   state <= DONE;
					    //input_index <= 0;
					end
            end
            DONE: begin // Go back to idle and deassert waitrequest. 
               slave_waitrequest = 0;
               state <= IDLE;
            end
         endcase
      end
   end
	
	logic mem_write;
	logic [15:0] mem_writedata;
	logic [9:0] mem_address_wr, mem_address_rd;
	
	logic [15:0] input_data;
   wire signed [OUTPUT_COUNT-1:0][15:0] output_v;
	assign leds[7:0] = 8'd1; //accuracy[7:0];
   assign leds[8] = tmp;	
	//assign leds[8:4] = accuracy[3:0];
	
	copy_dram_to_sram cpy (
	  // Control
	  .clk(clk), .rst_n(rst_n), .done(copy_done),
	  .start(copy_start), .num_words(FULL_INPUT_SIZE),
	  .mem_baddr(start_index + (input_index*FULL_INPUT_SIZE)),
	  // Interface with DRAM
     .master_waitrequest(master_waitrequest), 
     .master_address(master_address),
     .master_read(master_read), .master_readdata(master_readdata), 
	  .master_readdatavalid(master_readdatavalid), .master_write(master_write), 
	  .master_writedata(master_writedata),
	  // Interface with SRAM
	  .mem_write(mem_write), .mem_writedata(mem_writedata), .mem_address(mem_address_wr));
	  		  
	// store inputs and expected outputs
	logic tmp;
	flex_ram #(.NUM_WORDS(2**10), .ADDR_WIDTH(10), .WORD_SIZE(16), 
	   .MIF_FILE(INPUT_FILE), .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=INS")) ir1x (
		.address((state == INF)? mem_address_rd : ((state == GET_SOLUTION0 || state == GET_SOLUTION2 || state == GET_SOLUTION1 )? FULL_INPUT_SIZE-1 : mem_address_wr)), .clock(clk), .data(mem_writedata),
		.wren(mem_write), .q(input_data));
   //flex_ram  #(.NUM_WORDS(2**PAIR_COUNT_WIDTH), .ADDR_WIDTH(PAIR_COUNT_WIDTH), .WORD_SIZE(OUTPUT_WIDTH), .MIF_FILE("")) o_ex2 (
	//     .address(input_index), .clock(clk), .data(expected_idx), .wren(write_answer), .q(tmp));
   //flex_ram  #(.NUM_WORDS(2**PAIR_COUNT_WIDTH), .ADDR_WIDTH(PAIR_COUNT_WIDTH), .WORD_SIZE(OUTPUT_WIDTH), .MIF_FILE("")) o_ex3 (
	//     .address(input_index), .clock(clk), .data(solution), .wren(write_answer), .q());
   //flex_ram  #(.NUM_WORDS(2**8), .ADDR_WIDTH(8), .WORD_SIZE(OUTPUT_WIDTH), .MIF_FILE("")) o_ex4 (
	  //   .address(input_index), .clock(clk), .data(correct_count), .wren(write_answer), .q());
   flex_ram  #(.NUM_WORDS(2**10), .ADDR_WIDTH(10), .WORD_SIZE(OUTPUT_WIDTH), .MIF_FILE("")) o_ex6 (
	     .address(section_index), .clock(clk), .data(curr_correct_count), .wren(write_answer), .q());
		
	// Instantiate inference engine...
   multicycle_inference_engine_outer ie0x (
	    .clock(clk), .start(inf_start),
		 .output_idx(solution), .output_v(output_v), .reset(~rst_n), .done(inf_done),
		 .mem_address(mem_address_rd), .mem_input(input_data));   
		  
endmodule


