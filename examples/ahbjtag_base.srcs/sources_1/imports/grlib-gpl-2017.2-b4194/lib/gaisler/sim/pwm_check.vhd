------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2017, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-------------------------------------------------------------------------------
-- Entity:      pwm_check
-- File:        pwm_check.vhd
-- Author:      Jonas Ekergarn - Aeroflex Gaisler (parts are copied from
--              grtestmod.vhd)
-- Description: Simulation unit that examines the PWMs generated by the GRPWM
--              when software/leon3/grpwm.c is run. Note that pwm_check
--              requires that the system includes an I/O memory interface
--              and that grtestmod.vhd is instantiated in the system testbench.
--              If the subtests in software/leon3/grpwm.c is modified then the
--              configuration below and the procedure verify_subtest must be
--              changed as well.
-------------------------------------------------------------------------------

-- pragma translate_off
library ieee, grlib, gaisler;
use ieee.std_logic_1164.all;
use std.textio.all;
use grlib.stdlib.all;
use grlib.stdio.all;
use grlib.devices.all;
use gaisler.sim.all;

entity pwm_check is
  port (
    clk     : in    std_ulogic;
    address : in    std_logic_vector(21 downto 2);
    data    : inout std_logic_vector(31 downto 0);
    iosn    : in    std_ulogic;
    oen     : in    std_ulogic;
    writen  : in    std_ulogic;
    pwm     : in    std_logic_vector(15 downto 0)
 );

end;

architecture sim of pwm_check is

  signal ior, iow : std_ulogic;
  signal addr : std_logic_vector(21 downto 2);
  signal ldata : std_logic_vector(31 downto 0);
  signal pwmh : std_logic_vector(1 downto 0);
  signal pwmh0 : integer := 0;
  signal pwmh1 : integer := 1;
   
  -----------------------------------------------------------------------------
  -- Configuration of the PWMs that should be verified
  -----------------------------------------------------------------------------
  -- Number of "useful" words in the waveform ram. The core will read address
  -- 0 - (STX_WRAMSIZE-1).
  constant ST3_WRAMSIZE : integer := 32;
  constant ST4_WRAMSIZE : integer := 32;

  -- Number of periods to verify for each subtest. Verification of the very
  -- first period after PWM is started is skipped because there is no way of
  -- knowing exactly when it starts. It is assumed that the first period is
  -- correct. If it isn't then the verification of the other periods will fail
  -- as well.
  constant ST1_NPER : integer := 10;
  constant ST2_NPER : integer := 10;
  constant ST3_NPER : integer := 2*ST3_WRAMSIZE;
  constant ST4_NPER : integer := 2*ST4_WRAMSIZE;
  
  type st1_vector is array (0 to ST1_NPER) of integer;
  type st2_vector is array (0 to ST2_NPER) of integer;
  type st3_vector is array (0 to ST3_NPER) of integer;
  type st4_vector is array (0 to ST4_NPER) of integer;
  type st1_array is array (0 to 7) of st1_vector;
  type st2_array is array (0 to 7) of st2_vector;
  type st3_array is array (0 to 7) of st3_vector;
  type st4_array is array (0 to 7) of st4_vector;

  type wram_type is array (0 to 8191) of integer;
  
  -- Polarity for each PWM in the different subtests
  constant ST1_POL : std_logic_vector(7 downto 0) := (others=>'1');
  constant ST2_POL : std_logic_vector(7 downto 0) := (others=>'1');
  constant ST3_POL : std_logic_vector(7 downto 0) := (others=>'1');
  constant ST4_POL : std_logic_vector(7 downto 0) := (others=>'1');
  
  -- Period, compare, and dead band values for each pwm period in subtest 1,
  -- in clock cycles
  constant ST1_PER : st1_array := (
    0 => (others=>200),
    1 => (others=>201),
    2 => (others=>202),
    3 => (others=>203),
    4 => (others=>204),
    5 => (others=>205),
    6 => (others=>206),
    7 => (others=>207));
  constant ST1_COMPA : st1_array := (
    0 => (others=>100),
    1 => (others=>101),
    2 => (others=>102),
    3 => (others=>103),
    4 => (others=>104),
    5 => (others=>105),
    6 => (others=>106),
    7 => (others=>107));
  constant ST1_DB : st1_array := (
    0 => (others=>10),
    1 => (others=>11),
    2 => (others=>12),
    3 => (others=>13),
    4 => (others=>14),
    5 => (others=>15),
    6 => (others=>16),
    7 => (others=>17));

  -- Period, compare, and dead band values for each pwm period in subtest 2,
  -- in clock cycles
  constant ST2_PER : st2_array := (
    0 => (others=>200),
    1 => (others=>202),
    2 => (others=>204),
    3 => (others=>206),
    4 => (others=>208),
    5 => (others=>210),
    6 => (others=>212),
    7 => (others=>214));
  constant ST2_COMPA : st2_array := (
    0 => (others=>50),
    1 => (others=>51),
    2 => (others=>52),
    3 => (others=>53),
    4 => (others=>54),
    5 => (others=>55),
    6 => (others=>56),
    7 => (others=>57));
  constant ST2_DB : st2_array := (
    0 => (others=>10),
    1 => (others=>11),
    2 => (others=>12),
    3 => (others=>13),
    4 => (others=>14),
    5 => (others=>15),
    6 => (others=>16),
    7 => (others=>17));
  
  -- Period, compare, and dead band values for each pwm period in subtest 3,
  -- in clock cycles. (Only the PWM with the highest index is active during
  -- subtest 3, but since we here don't know how many PWM outputs there are,
  -- all get the same value)
  constant ST3_WRAM : wram_type := (
    32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,
    56,57,58,59,60,61,62,63,
    others=>0);
  constant ST3_PER : st3_array := (
    0 => (others=>200),
    1 => (others=>200),
    2 => (others=>200),
    3 => (others=>200),
    4 => (others=>200),
    5 => (others=>200),
    6 => (others=>200),
    7 => (others=>200));
  constant ST3_DB : st3_array := (
    0 => (others=>10),
    1 => (others=>10),
    2 => (others=>10),
    3 => (others=>10),
    4 => (others=>10),
    5 => (others=>10),
    6 => (others=>10),
    7 => (others=>10));

  -- Period, compare, and dead band values for each pwm period in subtest 4,
  -- in clock cycles. (Only the PWM with the highest index is active during
  -- subtest 4, but since we here don't know how many PWM outputs there are,
  -- all get the same value)
  constant ST4_WRAM : wram_type := (
    32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,
    56,57,58,59,60,61,62,63,
    others=>0);
  constant ST4_PER : st4_array := (
    0 => (others=>200),
    1 => (others=>200),
    2 => (others=>200),
    3 => (others=>200),
    4 => (others=>200),
    5 => (others=>200),
    6 => (others=>200),
    7 => (others=>200));
  constant ST4_DB : st4_array := (
    0 => (others=>10),
    1 => (others=>10),
    2 => (others=>10),
    3 => (others=>10),
    4 => (others=>10),
    5 => (others=>10),
    6 => (others=>10),
    7 => (others=>10));
  
  type pwm_int_array is array (0 to 7) of integer;
  type pwm_bool_array is array (0 to 7) of boolean;
  
  procedure verify_subtest (
    constant subtest : in integer;
    constant npwm    : in integer range 1 to 8;
    signal   clk     : in std_ulogic;
    signal   pwm     : in std_logic_vector(15 downto 0);
    signal   pwmh    : in std_logic_vector(1 downto 0)) is
    variable cnt   : pwm_int_array := (others=>0);
    variable cnt2  : pwm_int_array := (others=>0);
    variable pcnt  : pwm_int_array := (others=>0);
    variable parta : pwm_bool_array := (others=>false);
    variable partb : pwm_bool_array := (others=>false);
    variable partc : pwm_bool_array := (others=>false);
    variable partd : pwm_bool_array := (others=>false);
    variable done  : pwm_bool_array := (others=>false);
    variable ST2_COMPB : st2_array;
    variable ST4_COMPB : st4_array;
    variable addr : integer;
    variable il, ih : integer;
  begin
    case subtest is
      when 1 =>
        -------------------------------------------------------------------------
        -- Subtest 1: npwm assymmetric PWM pairs are generated, all with
        -- different periods, compare values, and dead band values. Verify
        -- periods, compare matches, and dead band times.
        -------------------------------------------------------------------------
        for i in 0 to 7 loop
          if npwm < i+1 then done(i) := true; end if;
          -- no dead band time is inserted in the very first pwm period after
          -- startup
          parta(i) := true;        
        end loop;      
        while not(done(0) and done(1) and done(2) and done(3) and
                  done(4) and done(5) and done(6) and done(7)) loop
          wait until rising_edge(clk);
          for i in 0 to npwm-1 loop
            cnt(i) := cnt(i)+1;
          end loop;
          wait until (pwm'event or falling_edge(clk));
          if clk = '1' then
            for i in 0 to npwm-1 loop
              if (not done(i)) then
                if (not parta(i)) then
                  -- pwm is in time period between period start and when paired
                  -- output goes active (after dead band time)
                  if pwm(2*i+1) = ST1_POL(i) then
                    parta(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= ST1_DB(i)(pcnt(i)) then
                        Print("ERROR: Wrong dead band (1) detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)) & ", should be " &
                              tost(ST1_DB(i)(pcnt(i))));
                      end if;
                    end if;
                  end if;
                elsif (not partb(i)) then
                  -- pwm is in time period between paired output going active and
                  -- paired output going inactive
                  if pwm(2*i+1) = (not ST1_POL(i)) then
                    partb(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= ST1_COMPA(i)(pcnt(i)) then
                        Print("ERROR: Wrong compare match detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)) & ", should be " &
                              tost(ST1_COMPA(i)(pcnt(i))));
                      end if;
                      if ST1_DB(i)(pcnt(i)) = 0 then
                        partc(i) := true;
                        if pwm(2*i) /= ST1_POL(i) then
                          Print("ERROR: Both outputs did not switch simultaneously"
                                & " even though dead band time was zero");
                        end if;
                      end if;
                    end if;
                  end if;
                elsif (not partc(i)) then
                  -- pwm is in time period between paired output going inactive and
                  -- output going active (after dead band time)
                  if pwm(2*i) = ST1_POL(i) then
                    partc(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= (ST1_COMPA(i)(pcnt(i)) +
                                    ST1_DB(i)(pcnt(i))) then
                        Print("ERROR: Wrong dead band (2) time detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)-ST1_COMPA(i)(pcnt(i))) &
                              ", should be " & tost(ST1_DB(i)(pcnt(i))));
                      end if;
                    end if;
                  end if;
                else
                  -- pwm is in time period between output going active and period end
                  -- (output going inactive)
                  if pwm(2*i) = (not ST1_POL(i)) then
                    parta(i) := false; partb(i) := false; partc(i) := false;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= ST1_PER(i)(pcnt(i)) then
                        Print("ERROR: Wrong PWM period detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)) & ", should be " &
                              tost(ST1_PER(i)(pcnt(i))));
                      end if;
                    end if;
                    if pcnt(i) = ST1_NPER then
                      done(i) := true;
                    end if;
                    pcnt(i) := pcnt(i)+1;                  
                    cnt(i) := 0;
                    if pcnt(i) < ST1_NPER then
                      if ST1_DB(i)(pcnt(i)) = 0 then
                        parta(i) := true;
                        if pwm(2*i+1) /= ST1_POL(i) then
                          Print("ERROR: Both outputs did not switch simultaneously"
                                & " even though dead band time was zero");
                        end if;
                      end if;
                    end if;
                  end if;
                end if;
              end if;
            end loop;
          end if;
        end loop;            
      when 2 =>
        -------------------------------------------------------------------------
        -- Subtest 2: npwm symmetric PWM pairs are generated, all with
        -- different periods, compare values, and dead band values. Verify
        -- periods, compare matches, and dead band times 
        -------------------------------------------------------------------------         
        for i in 0 to 7 loop
          for j in 0 to ST2_NPER loop
            ST2_COMPB(i)(j) := ST2_PER(i)(j)-ST2_COMPA(i)(j);
          end loop;
          if npwm < i+1 then done(i) := true; end if;
        end loop;
        while not(done(0) and done(1) and done(2) and done(3) and
                  done(4) and done(5) and done(6) and done(7)) loop
          wait until rising_edge(clk);
          for i in 0 to npwm-1 loop
            cnt(i) := cnt(i)+1; cnt2(i) := cnt2(i)+1;
          end loop;
          wait until (pwm'event or falling_edge(clk));
          if clk = '1' then
            for i in 0 to npwm-1 loop
              if (not done(i)) then
                if (not parta(i)) then
                  -- pwm is in time period between period start and when paired
                  -- output goes inactive
                  if pwm(2*i+1) = (not ST2_POL(i)) then
                    parta(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= ST2_COMPA(i)(pcnt(i)) then
                        Print("ERROR: Wrong compare match 1 detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)) & ", should be " &
                              tost(ST2_COMPA(i)(pcnt(i))));
                      end if;
                      if ST2_DB(i)(pcnt(i)) = 0 then
                        partb(i) := true;
                        if pwm(2*i) /= ST2_POL(i) then
                          Print("ERROR: Both outputs did not switch simultaneously"
                                & " even though dead band time was zero");
                        end if;
                      end if;
                    end if;
                  end if;
                elsif (not partb(i)) then
                  -- pwm is in time period between paired output going inactive and
                  -- output going active (after dead band time)
                  if pwm(2*i) = ST2_POL(i) then
                    partb(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= (ST2_COMPA(i)(pcnt(i)) +
                                    ST2_DB(i)(pcnt(i))) then
                        Print("ERROR: Wrong dead band (1) time detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)-ST2_COMPA(i)(pcnt(i))) &
                              ", should be " & tost(ST2_DB(i)(pcnt(i))));
                      end if;
                    end if;
                  end if;
                elsif (not partc(i)) then
                  -- pwm is in time period between output going active and
                  -- output going inactive
                  if pwm(2*i) = (not ST2_POL(i)) then
                    partc(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= ST2_COMPB(i)(pcnt(i)) then
                        Print("ERROR: Wrong compare match (2) detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)) & ", should be " & 
                              tost(ST2_COMPB(i)(pcnt(i))));
                      end if;
                      if ST2_DB(i)(pcnt(i)) = 0 then
                        partd(i) := true;
                        if pwm(2*i+1) /= ST2_POL(i) then
                          Print("ERROR: Both outputs did not switch simultaneously"
                                & " even though dead band time was zero");
                        end if;
                      end if;
                    else
                      if ST2_DB(i)(0) = 0 then
                        cnt2(i) := 0;
                        partd(i) := true;                        
                      end if;
                    end if;
                  end if;
                elsif (not partd(i)) then
                  -- pwm is in time period between output going inactive and
                  -- paired output going active (after dead band time)
                  if pwm(2*i+1) = ST2_POL(i) then
                    partd(i) := true;
                    if pcnt(i) /= 0 then
                      if cnt(i) /= (ST2_COMPB(i)(pcnt(i)) +
                                    ST2_DB(i)(pcnt(i))) then
                        Print("ERROR: Wrong dead band (2) time detected for pwm " &
                              tost(i+1) & " in period = " & tost(pcnt(i)) &
                              ". Is " & tost(cnt(i)-ST2_COMPB(i)(pcnt(i))) &
                              ", should be " & tost(ST2_DB(i)(pcnt(i))));
                      end if;
                    else
                      cnt2(i) := 0;
                    end if;
                  end if;
                end if;
              end if;
            end loop;            
          end if;
          for i in 0 to npwm-1 loop
            if (not done(i)) then
              if partd(i) then
                -- pwm is in time period between paired output going active
                -- and period end
                if pcnt(i) /= 0 then
                  if cnt(i) = ST2_PER(i)(pcnt(i)) then
                    parta(i) := false; partb(i) := false;
                    partc(i) := false; partd(i) := false;
                    pcnt(i) := pcnt(i)+1;
                    cnt(i) := 0;
                  end if;
                else
                  if (cnt2(i)+ST2_COMPB(i)(0)+ST2_DB(i)(0)) =
                    ST2_PER(i)(0) then
                    parta(i) := false; partb(i) := false;
                    partc(i) := false; partd(i) := false;
                    pcnt(i) := pcnt(i)+1;
                    cnt(i) := 0;
                  end if;
                end if;
                if pcnt(i) = ST2_NPER then
                  done(i) := true;
                end if;
              end if;
            end if;
          end loop;
        end loop;
      when 3 =>
        -------------------------------------------------------------------------
        -- Subtest 3: One asymmetric waveform PWM is generated. Verify period,
        -- compare matches and dead band time
        -------------------------------------------------------------------------
        parta(npwm-1) := true;   
        while not done(npwm-1) loop
          wait until rising_edge(clk);
          cnt(npwm-1) := cnt(npwm-1)+1;
          wait until (pwmh'event or falling_edge(clk));
          if clk = '1' then
            addr := pcnt(npwm-1) - (pcnt(npwm-1)/ST3_WRAMSIZE)*ST3_WRAMSIZE;
            if (not parta(npwm-1)) then
              -- pwm is in time period between period start and when paired
              -- output goes active (after dead band time)
              if pwmh(1) = ST3_POL(npwm-1) then
                parta(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= ST3_DB(npwm-1)(pcnt(npwm-1)) then
                    Print("ERROR: Wrong dead band (1) detected for pwm " &
                          tost((npwm-1)+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)) & ", should be " &
                          tost(ST3_DB(npwm-1)(pcnt(npwm-1))));
                  end if;
                end if;
              end if;
            elsif (not partb(npwm-1)) then
              -- pwm is in time period between paired output going active and
              -- paired output going inactive
              if pwmh(1) = (not ST3_POL(npwm-1)) then
                partb(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= ST3_WRAM(addr) then
                    Print("ERROR: Wrong compare match detected for pwm " &
                          tost((npwm-1)+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)) & ", should be " &
                          tost(ST3_WRAM(addr)));
                  end if;
                  if ST3_DB(npwm-1)(pcnt(npwm-1)) = 0 then
                    partc(npwm-1) := true;
                    if pwmh(0) /= ST3_POL(npwm-1) then
                      Print("ERROR: Both outputs did not switch simultaneously"
                            & " even though dead band time was zero");
                    end if;
                  end if;
                end if;
              end if;
            elsif (not partc(npwm-1)) then
              -- pwm is in time period between paired output going inactive and
              -- output going active (after dead band time)
              if pwmh(0) = ST3_POL(npwm-1) then
                partc(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= (ST3_WRAM(addr) +
                                     ST3_DB(npwm-1)(pcnt(npwm-1))) then
                    Print("ERROR: Wrong dead band (2) time detected for pwm " &
                          tost((npwm-1)+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)-ST3_WRAM(addr)) &
                          ", should be " & tost(ST3_DB(npwm-1)(pcnt(npwm-1))));
                  end if;
                end if;
              end if;
            else
              -- pwm is in time period between output going active and period end
              -- (output going inactive)
              if pwmh(0) = (not ST3_POL(npwm-1)) then
                parta(npwm-1) := false; partb(npwm-1) := false; partc(npwm-1) := false;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= ST3_PER(npwm-1)(pcnt(npwm-1)) then
                    Print("ERROR: Wrong PWM period detected for pwm " &
                          tost((npwm-1)+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)) & ", should be " &
                          tost(ST3_PER(npwm-1)(pcnt(npwm-1))));
                  end if;
                end if;
                if pcnt(npwm-1) = ST3_NPER then
                  done(npwm-1) := true;
                end if;
                pcnt(npwm-1) := pcnt(npwm-1)+1;                  
                cnt(npwm-1) := 0;
                if pcnt(npwm-1) < ST3_NPER then
                  if ST3_DB(npwm-1)(pcnt(npwm-1)) = 0 then
                    parta(npwm-1) := true;
                    if pwmh(1) /= ST3_POL(npwm-1) then
                      Print("ERROR: Both outputs did not switch simultaneously"
                            & " even though dead band time was zero");
                    end if;
                  end if;
                end if;
              end if;
            end if;
          end if;
        end loop;            
      when 4 =>
        -------------------------------------------------------------------------
        -- Subtest 4: One symmetric waveform PWM is generated. Verify period,
        -- compare matches, and dead band time
        -------------------------------------------------------------------------
        for j in 0 to ST4_NPER loop
          addr := j - (j/ST4_WRAMSIZE)*ST4_WRAMSIZE;
          ST4_COMPB(npwm-1)(j) := ST4_PER(npwm-1)(j)-ST4_WRAM(addr);
        end loop;
        while not done(npwm-1) loop
          wait until rising_edge(clk);
          cnt(npwm-1) := cnt(npwm-1)+1; cnt2(npwm-1) := cnt2(npwm-1)+1;
          wait until (pwmh'event or falling_edge(clk));
          if clk = '1' then
            addr := pcnt(npwm-1) - (pcnt(npwm-1)/ST4_WRAMSIZE)*ST4_WRAMSIZE;
            if (not parta(npwm-1)) then
              -- pwm is in time period between period start and when paired
              -- output goes inactive
              if pwmh(1) = (not ST4_POL(npwm-1)) then
                parta(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= ST4_WRAM(addr) then
                    Print("ERROR: Wrong compare match 1 detected for pwm " &
                          tost(npwm-1+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)) & ", should be " &
                          tost(ST4_WRAM(addr)));
                  end if;
                  if ST4_DB(npwm-1)(pcnt(npwm-1)) = 0 then
                    partb(npwm-1) := true;
                    if pwmh(0) /= ST4_POL(npwm-1) then
                      Print("ERROR: Both outputs did not switch simultaneously"
                            & " even though dead band time was zero");
                    end if;
                  end if;
                end if;
              end if;
            elsif (not partb(npwm-1)) then
              -- pwm is in time period between paired output going inactive and
              -- output going active (after dead band time)
              if pwmh(0) = ST4_POL(npwm-1) then
                partb(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= (ST4_WRAM(addr) +
                                     ST4_DB(npwm-1)(pcnt(npwm-1))) then
                    Print("ERROR: Wrong dead band (1) time detected for pwm " &
                          tost(npwm-1+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)-ST4_WRAM(addr)) &
                          ", should be " & tost(ST4_DB(npwm-1)(pcnt(npwm-1))));
                  end if;
                end if;
              end if;
            elsif (not partc(npwm-1)) then
              -- pwm is in time period between output going active and
              -- output going inactive
              if pwmh(0) = (not ST4_POL(npwm-1)) then
                partc(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= ST4_COMPB(npwm-1)(pcnt(npwm-1)) then
                    Print("ERROR: Wrong compare match (2) detected for pwm " &
                          tost(npwm-1+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)) & ", should be " & 
                          tost(ST4_COMPB(npwm-1)(pcnt(npwm-1))));
                  end if;
                  if ST4_DB(npwm-1)(pcnt(npwm-1)) = 0 then
                    partd(npwm-1) := true;
                    if pwmh(1) /= ST4_POL(npwm-1) then
                      Print("ERROR: Both outputs did not switch simultaneously"
                            & " even though dead band time was zero");
                    end if;
                  end if;
                else
                  if ST4_DB(npwm-1)(0) = 0 then
                    cnt2(npwm-1) := 0;
                    partd(npwm-1) := true;                        
                  end if;
                end if;
              end if;
            elsif (not partd(npwm-1)) then
              -- pwm is in time period between output going inactive and
              -- paired output going active (after dead band time)
              if pwmh(1) = ST4_POL(npwm-1) then
                partd(npwm-1) := true;
                if pcnt(npwm-1) /= 0 then
                  if cnt(npwm-1) /= (ST4_COMPB(npwm-1)(pcnt(npwm-1)) +
                                     ST4_DB(npwm-1)(pcnt(npwm-1))) then
                    Print("ERROR: Wrong dead band (2) time detected for pwm " &
                          tost(npwm-1+1) & " in period = " & tost(pcnt(npwm-1)) &
                          ". Is " & tost(cnt(npwm-1)-ST4_COMPB(npwm-1)(pcnt(npwm-1))) &
                          ", should be " & tost(ST4_DB(npwm-1)(pcnt(npwm-1))));
                  end if;
                else
                  cnt2(npwm-1) := 0;
                end if;
              end if;
            end if;
          end if;
          if partd(npwm-1) then
            -- pwm is in time period between paired output going active
            -- and period end
            if pcnt(npwm-1) /= 0 then
              if cnt(npwm-1) = ST4_PER(npwm-1)(pcnt(npwm-1)) then
                parta(npwm-1) := false; partb(npwm-1) := false;
                partc(npwm-1) := false; partd(npwm-1) := false;
                pcnt(npwm-1) := pcnt(npwm-1)+1;
                cnt(npwm-1) := 0;
              end if;
            else
              if (cnt2(npwm-1)+ST4_COMPB(npwm-1)(0)+ST4_DB(npwm-1)(0)) =
                ST4_PER(npwm-1)(0) then
                parta(npwm-1) := false; partb(npwm-1) := false;
                partc(npwm-1) := false; partd(npwm-1) := false;
                pcnt(npwm-1) := pcnt(npwm-1)+1;
                cnt(npwm-1) := 0;
              end if;
            end if;
            if pcnt(npwm-1) = ST4_NPER then
              done(npwm-1) := true;
            end if;
          end if;
        end loop;
      when others => null;
    end case;
  end verify_subtest;

begin
  
  ior <= iosn or oen;
  iow <= iosn or writen;
  data <= (others => 'Z');  
  addr <= to_X01(address) when rising_edge(clk) else addr;
  ldata <= to_X01(data) when rising_edge(clk) else ldata;
  pwmh <= pwm(pwmh1 downto pwmh0);

  process
    variable vid, did, subtest : integer;
    variable npwm : integer := 8;
  begin
    pwmh0 <= 2*(npwm-1);
    pwmh1 <= 2*(npwm-1)+1;
        
    wait until ((rising_edge(ior) nor falling_edge(ior)) and rising_edge(iow));
    case addr(7 downto 2) is
      when "000000" =>
        vid := conv_integer(ldata(31 downto 24));
        did := conv_integer(ldata(23 downto 12));
      when "000010" =>
        subtest := conv_integer(ldata(7 downto 0));
        if vid = VENDOR_GAISLER and did = GAISLER_PWM then
          if subtest > 246 then
            -- set npwm
            npwm := 255 - subtest;
          else
            verify_subtest(subtest, npwm, clk, pwm, pwmh);
          end if;
        end if;
      when others =>
    end case;
  end process;
  
end sim;
-- pragma translate_on

