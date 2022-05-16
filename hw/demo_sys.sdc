create_clock -period 20.0 CLOCK_50
create_generated_clock -name PLL_OUT -source CLOCK_50 -divide_by 1 [get_pins {sys|pll_0|altera_pll_i|outclk_wire[1]~CLKENA0|outclk}]
create_generated_clock -name PLL_OUT -source CLOCK_50 -divide_by 1 [get_pins {sys|pll_0|altera_pll_i|outclk_wire[0]~CLKENA0|outclk}]