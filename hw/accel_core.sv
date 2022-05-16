
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
    // Connections to the physical board.
    output logic [9:0] leds,
    input logic [2:0] keys,
    input logic [9:0] switches);
   
    // Important parameters. 
    parameter FULL_INPUT_SIZE = 786;    // Number of values per input (28*28) (first layer size)
    parameter PAIR_COUNT_WIDTH = 32;    // Bits required to count inputs 
    parameter OUTPUT_WIDTH = 8;         // Width of output index (up to 10 -- >= 4)
    parameter SECTION_SIZE = 100;       // Granularity of accuracy tracking
    parameter OUTPUT_COUNT = 10;        // Last layer size

    // Internal signals
    logic [31:0] pair_count;            // Index for iterating through pairs
    logic [31:0] start_index;           // Where to start iterating.
    logic train;                        // Whether to do online training
    logic soft_reset;                   // Re-start inference /training without PLL reset.
    logic [15:0] lrate;
    logic [15:0] lrate_mem;
    logic [15:0] start_mem;
    
    // State and control logic
    enum {IDLE, READ, COPY, GET_SOLUTION0, GET_SOLUTION1, GET_SOLUTION2, INF, INCR, DONE} state;
    logic copy_start, copy_done, inf_start, inf_done, write_curr_acc;
    logic [31:0] input_index, curr_index, section_index; 
    assign slave_readdata = 32'b0;    
    
    // Signals to keep track of the current solution and accuracy. 
    reg [PAIR_COUNT_WIDTH-1:0] correct_count;       // Keep track of total accuracy
    reg [PAIR_COUNT_WIDTH-1:0] curr_correct_count;  // Keep track of current accuracy
    wire [OUTPUT_WIDTH-1:0] expected_idx;           // Correct answer to current inference
    logic [OUTPUT_WIDTH-1:0] solution;              // Calculated answer to current inference

    // Settings based on physical board
    logic switch_mode;
    assign switch_mode = switches[5];
    assign pair_count = (switch_mode == 1'b0)? 10000 : 
                        (switches[1:0] == 2'd3)? 1000*switches[4:2] : 
                        (switches[1:0] == 2'd2)? 100*switches[4:2] : 
                        (switches[1:0] == 2'd2)? 10*switches[4:2] : switches[4:2];
    assign start_index = (switches[5])? 0 : start_mem*FULL_INPUT_SIZE;
    assign train = ~(lrate == 16'b0);
    assign lrate[2:0] = (switch_mode)? {13'd0, switches[8:6]} : lrate_mem;
    assign soft_reset = keys[0];
    entry_module #(.HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=LRATE")) lrate_m (clk, lrate_mem);
    entry_module #(.HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=START")) start_m (clk, start_mem);
    
    // Display current status. 
    assign leds[0] = (input_index > 0);
    assign leds[1] = (input_index > 1000);
    assign leds[2] = (input_index > 2000); 
    assign leds[3] = (input_index > 3000); 
    assign leds[4] = (input_index > 4000); 
    assign leds[5] = (input_index > 5000); 
    assign leds[6] = (input_index > 6000); 
    assign leds[7] = (input_index > 7000); 
    assign leds[8] = (input_index > 8000); 
    assign leds[9] = (state == IDLE);    
    
    // State machine to communicate with the CPU, and iterate through inputs.
   always@(posedge clk, negedge rst_n) begin
      if (~rst_n) begin
		   // On reset, go to idle state and reset everything.
         state <= IDLE;
			copy_start <= 1'b0;
			inf_start <= 1'b0;
			section_index <= 32'd0;
			input_index <= 32'd0;
			correct_count <= 32'd0;
			curr_correct_count <= 32'd0;
      end else begin
         case (state)
            IDLE: begin // Wait for signal from CPU or soft reset
               if ((slave_write === 1) || (~soft_reset)) begin
					   if ((slave_address == 4'd2) || (~soft_reset)) begin
                      state <= COPY;
							 copy_start <= 1'b1;
		              	 correct_count <= 32'd0;
		              	 curr_correct_count <= 32'd0;
							 section_index <= 32'd0;
							 input_index <= 0;
					   end
               end
               slave_waitrequest <= ((slave_write) === 1) ? 1'b1 : 1'b0;
            end
            COPY: begin // Copy an image into onchip memory
               state <= (copy_done == 1'b1)? GET_SOLUTION0 : COPY;
               inf_start <= (copy_done == 1'b1);
					copy_start <= 1'b0;
            end
				// EJR: Can we get rid of a state or two here?
            GET_SOLUTION0: begin // Get the expected solution - set addr
               state <= GET_SOLUTION1;
            end
            GET_SOLUTION1: begin // Get the expected solution - wait
               state <= GET_SOLUTION2;
            end
            GET_SOLUTION2: begin // Get the expected solution - read
               state <= INF;
					expected_idx <= input_data[7:0];
            end
            INF: begin // Perform inference
				   if (inf_done == 1'b1) begin
					    state <= INCR;
						 write_curr_acc <= (curr_index == (SECTION_SIZE-1));
                   correct_count <= correct_count + (solution == expected_idx);
                   curr_correct_count <= curr_correct_count + (solution == expected_idx);
					end
					inf_start <= 1'b0;
            end
            INCR: begin // Incrment index counts, accuracies etc, and go to next.
				   write_curr_acc <= 1'b0;
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
					end
            end
            DONE: begin // Go back to idle and deassert waitrequest. 
               slave_waitrequest = 1'b0;
					if (soft_reset) begin
                   state <= IDLE;
					end
            end
         endcase
      end
   end
	
	// Signals between copier, SRAM and inf engine.
	logic mem_write;
	logic [15:0] mem_writedata;
	logic [9:0] mem_address_wr, mem_address_rd;
	logic [15:0] input_data;  
	
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
	  		  
	// Store the current input
	flex_ram #(.NUM_WORDS(2**10), .ADDR_WIDTH(10), .WORD_SIZE(16),
	    .MIF_FILE(""), .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=INS")
	) ir1x (
		.address((state == INF)? mem_address_rd : 
		    ((state == GET_SOLUTION0 || state == GET_SOLUTION2 || state == GET_SOLUTION1 )? FULL_INPUT_SIZE-1 : 
			 mem_address_wr)), 
		.clock(clk), .data(mem_writedata),
		.wren(mem_write), .q(input_data));
		
	// Store the accuracies over time. 
   flex_ram  #(.NUM_WORDS(2**8), .ADDR_WIDTH(8), .WORD_SIZE(OUTPUT_WIDTH), 
	    .MIF_FILE(""), .HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=ACC")
   ) o_ex99 (
	   .address(section_index), .clock(clk), .data(curr_correct_count), .wren(write_curr_acc), .q());		
		
	// Instantiate inference engine...
   multicycle_train_engine_outer ie0x (
	    // Control signals
	    .clock(clk), .start(inf_start), .train(train), .reset(~rst_n), .done(inf_done), .lrate(lrate),
		 // Outputs 
		 .output_idx(solution), .output_v(), .expected_out(expected_idx),
		 // Interface with mem. 
		 .mem_address(mem_address_rd), .mem_input(input_data));   
endmodule