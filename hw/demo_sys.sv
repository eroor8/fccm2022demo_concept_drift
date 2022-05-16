module demo_sys(input logic CLOCK_50, input logic [3:0] KEY,
             input logic [9:0] SW, output logic [9:0] LEDR,
             output logic DRAM_CLK, output logic DRAM_CKE,
             output logic DRAM_CAS_N, output logic DRAM_RAS_N, output logic DRAM_WE_N,
             output logic [12:0] DRAM_ADDR, output logic [1:0] DRAM_BA, output logic DRAM_CS_N,
             inout logic [15:0] DRAM_DQ, output logic DRAM_UDQM, output logic DRAM_LDQM,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5);
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
     
    logic hard_reset_mem, soft_reset_mem, hard_reset, soft_reset;
     
    // Reset through the JTAG interface.
    reset_module #(.HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=HR")) hr (CLOCK_50, hard_reset_mem);
    reset_module #(.HINT("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=SR")) sr (CLOCK_50, soft_reset_mem);
    assign hard_reset = ~(hard_reset_mem || ~KEY[3]);
    assign soft_reset = ~(soft_reset_mem || ~KEY[0]);
     
    demo_qsys_system sys(.clk_clk(CLOCK_50), .reset_reset_n(hard_reset),
                         .pll_locked_export(),
                         .sdram_clk_clk(DRAM_CLK),
                         .sdram_addr(DRAM_ADDR),
                         .sdram_ba(DRAM_BA),
                         .sdram_cas_n(DRAM_CAS_N),
                         .sdram_cke(DRAM_CKE),
                         .sdram_cs_n(DRAM_CS_N),
                         .sdram_dq(DRAM_DQ),
                         .sdram_dqm({DRAM_UDQM, DRAM_LDQM}),
                         .sdram_ras_n(DRAM_RAS_N),
                         .sdram_we_n(DRAM_WE_N),
                         .leds_new_signal(LEDR),
                         .keys_new_signal({KEY[2], KEY[1], soft_reset}),
                         .switches_new_signal(SW));
endmodule

