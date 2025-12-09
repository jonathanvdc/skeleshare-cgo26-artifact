	component floating_point_dsp is
		port (
			aclr   : in  std_logic                     := 'X';             -- aclr
			ay     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- ay
			az     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- az
			clk    : in  std_logic                     := 'X';             -- clk
			ena    : in  std_logic                     := 'X';             -- ena
			result : out std_logic_vector(31 downto 0)                     -- result
		);
	end component floating_point_dsp;

	u0 : component floating_point_dsp
		port map (
			aclr   => CONNECTED_TO_aclr,   --   aclr.aclr
			ay     => CONNECTED_TO_ay,     --     ay.ay
			az     => CONNECTED_TO_az,     --     az.az
			clk    => CONNECTED_TO_clk,    --    clk.clk
			ena    => CONNECTED_TO_ena,    --    ena.ena
			result => CONNECTED_TO_result  -- result.result
		);

