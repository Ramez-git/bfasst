-- PowerSequencerSlice

-- (c) 2009.. Gerhard Hoffmann  opencores@hoffmann-hochfrequenz.de
-- Published under BSD license
-- V1.0  first published version
--
-- CLK can be any clock you like. RST must be synchronous to it. 
-- Other inputs are synchronized internally unless generated by same type of slice.
--
-- A high clock of, say 200 MHz will produce a lot of logic for the watchdog counter
-- to time the millisecond events that happen in power supplies. 
-- A few KHz should be optimum.
--
-- Ena_chain_async = '1' initiates a power up sequence. It will run to completion for the whole system,
-- unless some supply fails.  In case of supply failure, an ordered retreat is made. 
-- The supply that comes up last will go down first.
-- Pulling ena_chain_async low switches all power supplies off, stage by stage.
--
-- The generic "ticks" determines the number of clock ticks we are willing to wait 
-- until supply_good_async comes up after supply_ena is activated for a given supply.
--
-- Do not forget PullDown resistors on supply_ena if the sequencer itself is, for example, 
-- in a FPGA that is not yet operational at the very first beginning.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;



entity PowerSequencer is
  generic (
    ticks:            natural := 16;  -- clock ticks we are willing to wait until a power supply has to be operational  
    last_in_chain:    boolean := false
  );

  port (
    clk:               in  std_logic;
    rst:               in  std_logic;

    ena_chain_async:   in  std_logic; -- enable this slice ( and the following ones if possible)
    fail_chain_out:    out std_logic; -- we've got a problem ( or one of the following slices)
    pu_chain_out:      out std_logic; -- power up status of _this_ slice and its slaves

    ena_next:          out std_logic; -- cascade output to next slice
    fail_chain_in:     in  std_logic; -- a cascaded slice has a problem
    pu_chain_in:       in  std_logic; -- power up status of our slaves

    supply_ena:        out std_logic; -- enable to the power supplies controlled by this slice
    supply_good_async: in  std_logic  -- power good from the supplies controlled by this slice
  );
end PowerSequencer;





architecture rtl of PowerSequencer is

  type ps_state is ( 
    s_idle, 
    s_powerup_trigger,
    s_do_powerup, 
    s_check, 
    s_ena_next,
    s_operating,
    s_retreat_trigger,
    s_retreat,
    s_complain
  );

  signal current_state: ps_state;
  
  signal ena_chain:     std_logic;
  signal supply_good:   std_logic;

  signal timer_do:      std_logic;
  signal timer_done:    std_logic;

begin



u_synchronizer: process(clk) is
begin
  if rising_edge(clk)
  then 
    ena_chain   <= ena_chain_async;
    supply_good <= supply_good_async;
  end if;
end process u_synchronizer;



u_statemachine: process(clk) is
begin

  if rising_edge(clk)
  then
  
    if rst = '1'
    then
      supply_ena      <= '0';
      timer_do        <= '0';
      fail_chain_out  <= '0';
      ena_next        <= '0';
      pu_chain_out    <= '0';
 
      current_state   <= s_idle;
      
    else 
      case current_state is


        when s_idle =>            -- reset / idle state
        supply_ena      <= '0';
        timer_do        <= '0';
        fail_chain_out  <= '0';
        ena_next        <= '0';
        pu_chain_out    <= '0';

        if ena_chain = '1'
        then
          current_state <= s_powerup_trigger;
        end if;


      when s_powerup_trigger =>    -- waking up
        supply_ena    <= '1';
        timer_do      <= '1';

        current_state <= s_do_powerup;



      when s_do_powerup =>    -- we stay here for one timer cycle to allow OUR
        timer_do   <= '0';    -- power supply to build up the voltage.

        if timer_done = '1'
        then
          current_state <= s_check;
        end if;



      when s_check =>             -- check wether our supply has come up as expected
        if (supply_good = '1') and (ena_chain = '1')
        then
          ena_next      <= '1';
          current_state <= s_ena_next;
        else
          current_state <= s_retreat_trigger;
        end if;



      when s_ena_next =>          -- ok, enable rest of chain
 
          if (pu_chain_in = '1')  or last_in_chain
          then
            pu_chain_out   <= '1';
            current_state  <= s_operating; 
          elsif (fail_chain_in = '1')
          then
            fail_chain_out <= '1';   -- fail must be communicated on the spot for data saving attempts
            current_state  <= s_operating;  -- looks wrong only at first sight. don't panic. 
          end if;
          
       
          
      when s_operating =>         -- normal operation, but watch our supply and the slaves
  
        if (fail_chain_in = '1') or (supply_good = '0')
        then
            fail_chain_out  <= '1';   -- fail must be communicated on the spot for data saving attempts
        end if; 
  
        if ((ena_chain = '0') or (supply_good = '0'))      -- propagate SwitchOff if there is one
        then
          ena_next  <= '0';
        end if;                  

        if    ((    last_in_chain and (ena_chain = '0'))
           or  (not last_in_chain and (pu_chain_in = '0')))
        then
          current_state  <= s_retreat_trigger; 
        else
          -- normal operation all day long
          null;    
        end if;




      when s_retreat_trigger =>      -- start power down sequence
        supply_ena    <= '0';
        timer_do      <= '1';
        
        current_state <= s_retreat;



      when s_retreat =>     -- We stay here for one timer cycle to allow OUR
        timer_do  <= '0';   -- Power supply to drain

        if (timer_done = '1')
        then
          if (ena_chain = '1') -- don't complain if the user doesn't want the power anyway
          then
            current_state <= s_complain;  -- switchoff because of failure
            fail_chain_out <= '1';
          else
            current_state  <= s_idle;      -- normal switchoff
          end if;
        end if;



      when s_complain =>   -- keep error status until switched off
  
        fail_chain_out  <= '1';
        if (ena_chain = '0')
        then
          current_state <= s_idle;
        end if;



      when others =>    -- whatever surprises the chosen state encoding might provide
        current_state <= s_idle;


      end case;
    end if;  -- not reset
  end if; -- rising_edge(clk)
end process u_statemachine;



uti: entity work.retrigg_timer

  generic  map(
    ticks    => ticks
    )

  port map (
    clk     => clk,
    rst     => rst,
    do      => timer_do,
    done    => timer_done,
    running => open
  );



end architecture rtl;



