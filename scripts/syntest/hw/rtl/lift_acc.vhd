library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity lift_acc is
    port(
        clk: in std_logic;
        reset: in std_logic;

        afu_id: in std_logic_vector(127 downto 0);

        -- sTx.c0.hdr.vc_sel
        read_req_vc_sel: out std_logic_vector(1 downto 0);
        -- sTx.c0.hdr.cl_len
        read_req_cl_len: out std_logic_vector(1 downto 0);
        -- sTx.c0.hdr.req_type
        read_req_type: out std_logic_vector(3 downto 0);
        -- sTx.c0.hdr.address
        read_req_address: out std_logic_vector(41 downto 0);
        -- sTx.c0.hdr.mdata
        read_req_mdata: out std_logic_vector(15 downto 0);
        -- sTx.c0.valid
        read_req_valid: out std_logic;
        -- sRx.c0TxAlmFull
        read_req_alm_full: in std_logic; -- if '1' max 8 more requests can be sent

        -- sRx.c0.hdr.vc_used
        read_rsp_vc_used: in std_logic_vector(1 downto 0);
        -- sRx.c0.hdr.hit_miss
        read_rsp_hit_miss: in std_logic;
        -- sRx.c0.hdr.error
        -- read_rsp_error: in std_logic;
        -- sRx.c0.hdr.cl_num
        read_rsp_cl_num: in std_logic_vector(1 downto 0);
        -- sRx.c0.hdr.resp_type
        read_rsp_type: in std_logic_vector(3 downto 0);
        -- sRx.c0.hdr.mdata
        read_rsp_mdata: in std_logic_vector(15 downto 0);
        -- sRx.c0.data
        read_rsp_data: in std_logic_vector(511 downto 0);
        -- Only one of valid, mmioRdValid and mmioWrValid may be set in a cycle.
        -- When either mmioRdValid or mmioWrValid are true the hdr must be processed specially!
        -- sRx.c0.rspValid
        read_rsp_valid: in std_logic;

        -- sTx.c1.hdr.byte_len
        -- write_req_byte_len: out std_logic_vector(5 downto 0);
        -- sTx.c1.hdr.vc_sel
        write_req_vc_sel: out std_logic_vector(1 downto 0);
        -- sTx.c1.hdr.sop
        write_req_sop: out std_logic; -- start of packet for multi-CL memory write
        -- sTx.c1.hdr.mode
        -- write_req_mode: out std_logic;
        -- sTx.c1.hdr.cl_len
        write_req_cl_len: out std_logic_vector(1 downto 0);
        -- sTx.c1.hdr.req_type
        write_req_type: out std_logic_vector(3 downto 0);
        -- sTx.c1.hdr.byte_start
        -- write_req_byte_start: out std_logic_vector(5 downto 0);
        -- sTx.c1.hdr.address
        write_req_address: out std_logic_vector(41 downto 0);
        -- sTx.c1.hdr.mdata
        write_req_mdata: out std_logic_vector(15 downto 0);
        -- sTx.c1.data
        write_req_data: out std_logic_vector(511 downto 0);
        -- sTx.c1.valid
        write_req_valid: out std_logic;
        -- sRx.c1TxAlmFull
        write_req_alm_full: in std_logic; -- if '1' max 8 more requests can be sent

        -- sRx.c1.hdr.vc_used
        write_rsp_vc_used: in std_logic_vector(1 downto 0);
        -- sRx.c1.hdr.hit_miss
        write_rsp_hit_miss: in std_logic;
        -- sRx.c1.hdr.format
        write_rsp_format: in std_logic; -- for multi-CL memory write requests
        -- sRx.c1.hdr.cl_num
        write_rsp_cl_num: in std_logic_vector(1 downto 0); -- current CL for multi-CL writes
        -- sRx.c1.hdr.resp_type
        write_rsp_type: in std_logic_vector(3 downto 0);
        -- sRx.c1.hdr.mdata
        write_rsp_mdata: in std_logic_vector(15 downto 0);
        -- sRx.c1.rspValid
        write_rsp_valid: in std_logic;

        -- mmioHdr is sRx.c0.hdr cast to t_ccip_c0_ReqMmioHdr
        -- mmioHdr.address
        mmio_req_address: in std_logic_vector(15 downto 0);
        -- mmioHdr.length
        mmio_req_length: in std_logic_vector(1 downto 0); --2’h0: 4 bytes; 2’h1: 8 bytes; 2'h2: 64 bytes (for MMIO Writes only);
        -- mmioHdr.tid
        mmio_req_tid: in std_logic_vector(8 downto 0);
        -- sRx.c0.data
        mmio_req_data: in std_logic_vector(511 downto 0);
        -- sRx.c0.mmioRdValid
        mmio_req_read_valid: in std_logic;
        -- sRx.c0.mmioWrValid
        mmio_req_write_valid: in std_logic;

        -- sTx.c2.hdr.tid
        mmio_rsp_tid: out std_logic_vector(8 downto 0);
        -- sTx.c2.data
        mmio_rsp_data: out std_logic_vector(63 downto 0);
        -- sTx.c2.mmioRdValid
        mmio_rsp_read_valid: out std_logic
    );
end lift_acc;

architecture behavioral of lift_acc is
    signal offset_address: std_logic_vector(41 downto 0) := (others => '0');
    signal offset_address_valid: std_logic := '0';
    signal read_req_address_rel: std_logic_vector(41 downto 0) := (others => '0');
    signal write_req_address_rel: std_logic_vector(41 downto 0) := (others => '0');
    signal read_req_address_abs: std_logic_vector(41 downto 0) := (others => '0');
    signal write_req_address_abs: std_logic_vector(41 downto 0) := (others => '0');
    signal finished: std_logic := '0';
    signal result_consumed: std_logic_vector(0 downto 0) := "0";

    signal cycle_counter: std_logic_vector(63 downto 0) := (others => '0');

    signal read_req_valid_i: std_logic := '0';
    signal write_req_valid_i: std_logic := '0';

    signal read_req_total: std_logic_vector(63 downto 0) := (others => '0');
    signal write_req_total: std_logic_vector(63 downto 0) := (others => '0');
    signal read_req_pending: std_logic_vector(63 downto 0) := (others => '0');
    signal write_req_pending: std_logic_vector(63 downto 0) := (others => '0');
    signal read_alm_full_counter: std_logic_vector(63 downto 0) := (others => '0');
    signal write_alm_full_counter: std_logic_vector(63 downto 0) := (others => '0');

    type   write_req_buffer_type is array (0 to 255) of std_logic_vector(63 downto 0);
    signal write_req_buffer: write_req_buffer_type := (others => (others => '0'));
    signal write_req_buffer_idx: natural range 0 to 256 := 0;
    signal write_req_buffer_mmio_idx: natural range 0 to 256 := 0;

    type   write_rsp_buffer_type is array (0 to 255) of std_logic_vector(63 downto 0);
    signal write_rsp_buffer: write_rsp_buffer_type := (others => (others => '0'));
    signal write_rsp_buffer_idx: natural range 0 to 256 := 0;
    signal write_rsp_buffer_mmio_idx: natural range 0 to 256 := 0;

    component top
        port(
            clk: in type_LogicType;
            reset: in type_LogicType;
            p_in_read_mem_ready: in type_LogicType;
            p_out_read_req_address: out type_IntTypeArithType42;
            p_out_read_req_mdata: out type_VectorTypeLogicTypeArithType16;
            p_out_read_req_valid: out type_LogicType;
            p_out_read_req_total: out type_IntTypeArithType64;
            p_out_read_req_pending: out type_IntTypeArithType64;
	    p_in_read_req_almFull: in type_LogicType;
            p_in_read_rsp_data: in type_VectorTypeLogicTypeArithType512;
            p_in_read_rsp_mdata: in type_VectorTypeLogicTypeArithType16;
            p_in_read_rsp_valid: in type_LogicType;
            p_in_write_mem_ready: in type_LogicType;
            p_out_write_req_address: out type_IntTypeArithType42;
            p_out_write_req_mdata: out type_VectorTypeLogicTypeArithType16;
            p_out_write_req_data: out type_VectorTypeLogicTypeArithType512;
            p_out_write_req_valid: out type_LogicType;
            p_out_write_req_total: out type_IntTypeArithType64;
            p_out_write_req_pending: out type_IntTypeArithType64;
	    p_in_write_req_almFull: in type_LogicType;
            p_in_write_rsp_mdata: in type_VectorTypeLogicTypeArithType16;
            p_in_write_rsp_valid: in type_LogicType;
            p2_out_data: out std_logic_vector(-1 downto 0);
            p2_out_last: out type_LastVectorTypeArithType0;
            p2_out_valid: out type_LogicType;
            p2_in_ready: in type_ReadyVectorTypeArithType0
        );
    end component;

begin

    U0: top
        port map(
            clk => clk,
            reset => reset,
            p_in_read_mem_ready => offset_address_valid,
            p_out_read_req_address => read_req_address_rel,
            p_out_read_req_mdata => read_req_mdata,
            p_out_read_req_valid => read_req_valid_i,
            p_out_read_req_total => read_req_total,
            p_out_read_req_pending => read_req_pending,
	    p_in_read_req_almFull => read_req_alm_full,

            p_in_read_rsp_data => read_rsp_data,
            p_in_read_rsp_mdata => read_rsp_mdata,
            p_in_read_rsp_valid => read_rsp_valid,

            p_in_write_mem_ready => offset_address_valid,
            p_out_write_req_address => write_req_address_rel,
            p_out_write_req_mdata => write_req_mdata,
            p_out_write_req_data => write_req_data,
            p_out_write_req_valid => write_req_valid_i,
            p_out_write_req_total => write_req_total,
            p_out_write_req_pending => write_req_pending,
            p_in_write_req_almFull => write_req_alm_full,

            p_in_write_rsp_mdata => write_rsp_mdata,
            p_in_write_rsp_valid => write_rsp_valid,
            p2_out_data => open,
            p2_out_last => open,
            p2_out_valid => finished,
            p2_in_ready => result_consumed
        );

    read_req_valid <= read_req_valid_i;
    write_req_valid <= write_req_valid_i;

    -- set constant values for the read request header
    read_req_vc_sel <= "00"; -- 2’h0: VA (For producer-consumer type flows); 2’h1: VL0 (For latency sensitive flows); 2’h2: VH0 (For data dependent flow); 2’h3: VH1
    read_req_cl_len <= "00"; -- Length for memory requests 2’h0: 64 bytes (1 CL); 2’h1: 128 bytes (2 CLs); 2’h3: 256 bytes (4 CLs)
    read_req_type <= "0000"; -- RdLine_I (no caching)

    -- set constant values for the write request header
    -- write_req_byte_len <= "000000"; -- must be 0 for cache aligned write
    write_req_vc_sel <= "00"; -- 2’h0: VA (For producer-consumer type flows); 2’h1: VL0 (For latency sensitive flows); 2’h2: VH0 (For data dependent flow); 2’h3: VH1
    write_req_sop <= '1'; -- start of packet always 1, because we always start a new packet
    -- write_req_mode <= '0'; -- cache aligned write (write 1, 2 or 4 cache lines per request (!= writing single bytes))
    write_req_cl_len <= "00"; -- Length for memory requests 2’h0: 64 bytes (1 CL); 2’h1: 128 bytes (2 CLs); 2’h3: 256 bytes (4 CLs)
    write_req_type <= "0001"; -- WrLine_M (caching hint set to Modified)
    -- write_req_byte_start <= "000000"; -- must be 0 for cache aligned write

    read_req_address_abs <= std_logic_vector(unsigned(offset_address) + unsigned(read_req_address_rel));
    read_req_address <= read_req_address_abs;

    write_req_address_abs <= std_logic_vector(unsigned(offset_address) + unsigned(write_req_address_rel));
    write_req_address <= write_req_address_abs;

--    -- dummy logic for testing only TODO TODO
--    -- no read requests
--    read_req_address_rel <= (others => '0');
--    read_req_mdata <= (others => '0');
--    read_req_valid <= '0';
--    -- (repeatedly) write to first address
--    write_req_address_rel <= (others => '0');
--    write_req_mdata <= (others => '0');
--    write_req_data <= x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004142434445464748";
--    write_req_valid <= '1' when offset_address_valid = '1' and write_req_alm_full = '0' else '0';
--    finished <= offset_address_valid;
--    -- end dummy logic

    alm_full_counter: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                read_alm_full_counter <= (others => '0');
                write_alm_full_counter <= (others => '0');
            else
                if read_req_alm_full = '1' then
                    read_alm_full_counter <= std_logic_vector(unsigned(read_alm_full_counter) + 1);
                end if;
                if write_req_alm_full = '1' then
                    write_alm_full_counter <= std_logic_vector(unsigned(write_alm_full_counter) + 1);
                end if;
            end if;
        end if;
    end process;



    mmio_reads: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mmio_rsp_tid <= (others => '0');
                mmio_rsp_data <= (others => '0');
                mmio_rsp_read_valid <= '0';
                write_req_buffer_mmio_idx <= 0;
                write_rsp_buffer_mmio_idx <= 0;
            else
                -- Clear read response flag in case there was a response last cycle.
                mmio_rsp_read_valid <= '0';

                -- serve MMIO read requests
                if mmio_req_read_valid = '1' then
                    -- Copy TID, which the host needs to map the response to the request
                    mmio_rsp_tid <= mmio_req_tid;

                    -- Post responsej
                    mmio_rsp_read_valid <= '1';

                    mmio_rsp_data <= (others => '0');

                    case mmio_req_address is
                        -- AFU header
                        when x"0000" =>
                            mmio_rsp_data <=
                                "0001"& -- Feature type = AFU
                                "00000000"& -- reserved
                                "0000"& -- afu minor revision = 0
                                "0000000"& -- reserved
                                "1" & -- end of DFH list = 1
                                "000000000000000000000000"& -- next DFH offset = 0
                                "0000"& -- afu major revision = 0
                                "000000000000"; -- feature ID = 0
                        -- AFU_ID_L
                        when x"0002" =>
                            mmio_rsp_data <= afu_id(63 downto 0);
                        -- AFU_ID_H
                        when x"0004" =>
                            mmio_rsp_data <= afu_id(127 downto 64);
                        -- DFH_RSVD0
                        when x"0006" =>
                            mmio_rsp_data <= (others => '0');
                        -- DFH_RSVD1
                        when x"0008" =>
                            mmio_rsp_data <= (others => '0');


                        -- finished
                        when x"0020" => -- is 0x80 in software
                            mmio_rsp_data <= (0 => finished, others => '0');
                        -- cycle counter
                        when x"0022" => -- is 0x88 in software
                            mmio_rsp_data <= cycle_counter;



                        -- debug only TODO
                        when x"0030" => -- is 0xC0 in software
                            mmio_rsp_data <= read_req_total;
                        when x"0032" => -- is 0xC8 in software
                            mmio_rsp_data <= write_req_total;
                        when x"0034" => -- is 0xD0 in software
                            mmio_rsp_data <= read_req_pending;
                        when x"0036" => -- is 0xD8 in software
                            mmio_rsp_data <= write_req_pending;
                        when x"0038" => -- is 0xE0 in software
                            mmio_rsp_data <= read_alm_full_counter;
                        when x"003A" => -- is 0xE8 in software
                            mmio_rsp_data <= write_alm_full_counter;
                        when x"003C" => -- is 0xF0 in software
                            mmio_rsp_data <= write_req_buffer(write_req_buffer_mmio_idx);
                            write_req_buffer_mmio_idx <= write_req_buffer_mmio_idx + 1;
                        when x"003E" => -- is 0xF8 in software
                            mmio_rsp_data <= write_rsp_buffer(write_rsp_buffer_mmio_idx);
                            write_rsp_buffer_mmio_idx <= write_rsp_buffer_mmio_idx + 1;



                        when others =>
                            mmio_rsp_data <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;

    mmio_writes: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                offset_address <= (others => '0');
                offset_address_valid <= '0';
                result_consumed <= "0";
            else
                if mmio_req_write_valid = '1' then
                    case mmio_req_address is
                        when x"0000" => -- 0x0 in software
                            offset_address <= mmio_req_data(41 downto 0);
                        when x"0002" => -- 0x8 in software
                            offset_address_valid <= mmio_req_data(0);
                        when x"0004" => -- 0x10 in software
                            result_consumed <= mmio_req_data(0 downto 0);
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    cycle_counter_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cycle_counter <= (others => '0');
            else
                if offset_address_valid = '1' and finished = '0' then
                    cycle_counter <= std_logic_vector(unsigned(cycle_counter) + 1);
                end if;
            end if;
        end if;
    end process;

    write_req_trace: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                write_req_buffer_idx <= 0;
            else
                if write_req_valid_i = '1' then
                    write_req_buffer(write_req_buffer_idx) <= cycle_counter;
                    write_req_buffer_idx <= write_req_buffer_idx + 1;
                end if;
            end if;
        end if;
    end process;

    write_rsp_trace: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                write_rsp_buffer_idx <= 0;
            else
                if write_rsp_valid = '1' then
                    write_rsp_buffer(write_rsp_buffer_idx) <= cycle_counter;
                    write_rsp_buffer_idx <= write_rsp_buffer_idx + 1;
                end if;
            end if;
        end if;
    end process;

end behavioral;
