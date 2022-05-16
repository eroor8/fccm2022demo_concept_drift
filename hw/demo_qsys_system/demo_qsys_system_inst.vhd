	component demo_qsys_system is
		port (
			clk_clk             : in    std_logic                     := 'X';             -- clk
			leds_new_signal     : out   std_logic_vector(9 downto 0);                     -- new_signal
			pll_locked_export   : out   std_logic;                                        -- export
			reset_reset_n       : in    std_logic                     := 'X';             -- reset_n
			sdram_addr          : out   std_logic_vector(12 downto 0);                    -- addr
			sdram_ba            : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_cas_n         : out   std_logic;                                        -- cas_n
			sdram_cke           : out   std_logic;                                        -- cke
			sdram_cs_n          : out   std_logic;                                        -- cs_n
			sdram_dq            : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
			sdram_dqm           : out   std_logic_vector(1 downto 0);                     -- dqm
			sdram_ras_n         : out   std_logic;                                        -- ras_n
			sdram_we_n          : out   std_logic;                                        -- we_n
			sdram_clk_clk       : out   std_logic;                                        -- clk
			switches_new_signal : in    std_logic_vector(9 downto 0)  := (others => 'X'); -- new_signal
			keys_new_signal     : in    std_logic_vector(2 downto 0)  := (others => 'X')  -- new_signal
		);
	end component demo_qsys_system;

	u0 : component demo_qsys_system
		port map (
			clk_clk             => CONNECTED_TO_clk_clk,             --        clk.clk
			leds_new_signal     => CONNECTED_TO_leds_new_signal,     --       leds.new_signal
			pll_locked_export   => CONNECTED_TO_pll_locked_export,   -- pll_locked.export
			reset_reset_n       => CONNECTED_TO_reset_reset_n,       --      reset.reset_n
			sdram_addr          => CONNECTED_TO_sdram_addr,          --      sdram.addr
			sdram_ba            => CONNECTED_TO_sdram_ba,            --           .ba
			sdram_cas_n         => CONNECTED_TO_sdram_cas_n,         --           .cas_n
			sdram_cke           => CONNECTED_TO_sdram_cke,           --           .cke
			sdram_cs_n          => CONNECTED_TO_sdram_cs_n,          --           .cs_n
			sdram_dq            => CONNECTED_TO_sdram_dq,            --           .dq
			sdram_dqm           => CONNECTED_TO_sdram_dqm,           --           .dqm
			sdram_ras_n         => CONNECTED_TO_sdram_ras_n,         --           .ras_n
			sdram_we_n          => CONNECTED_TO_sdram_we_n,          --           .we_n
			sdram_clk_clk       => CONNECTED_TO_sdram_clk_clk,       --  sdram_clk.clk
			switches_new_signal => CONNECTED_TO_switches_new_signal, --   switches.new_signal
			keys_new_signal     => CONNECTED_TO_keys_new_signal      --       keys.new_signal
		);

