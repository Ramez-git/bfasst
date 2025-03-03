"""IceStorm reverse bitstream tool."""
import subprocess
import re
import time
import os

import bfasst
from bfasst.reverse_bit.base import ReverseBitTool, ReverseBitException

# PROJECT_TEMPLATE_FILE = 'template_lse.prj'
# IC2_LSE_PROJ_FILE = 'lse_project.prj'


class IcestormReverseBitTool(ReverseBitTool):
    """IceStorm reverse bitstream tool"""

    TOOL_WORK_DIR = "icestorm"

    def reverse_bitstream(self):
        # print("Running ReverseBit")
        self.launch()
        if self.design.cur_error_flow_name is None:
            self.design.reversed_netlist_path = self.cwd / (self.design.top + "_reversed.v")
        else:
            self.design.reversed_netlist_path = self.cwd / (
                self.design.top + "_" + self.design.cur_error_flow_name + "_reversed.v"
            )

        # Decide if this needs to be run
        need_to_run = False

        # Run if reverse netlist file does not exist
        need_to_run |= not self.design.reversed_netlist_path.is_file()

        # Run if reverse netlist file is out of date
        rev_netlist_mtime = self.design.reversed_netlist_path.stat().st_mtime
        netlist_mtime = self.design.netlist_path.stat().st_mtime
        need_to_run |= (not need_to_run) and (rev_netlist_mtime < netlist_mtime)

        if need_to_run:
            # First go through and remove any added stuff from pcf port names
            self.fix_pcf_names()
            # Bitstream to ascii file
            asc_path = self.work_dir / (self.design.top + ".asc")
            self.convert_bit_to_asc(self.design.bitstream_path, asc_path)

            # Ascii to netlist
            self.convert_asc_to_netlist(
                asc_path, self.design.constraints_path, self.design.reversed_netlist_path
            )

        self.write_to_results_file(self.design.reversed_netlist_path, need_to_run)
        self.cleanup()

    def convert_bit_to_asc(self, bitstream_path, asc_path):
        cmd = [bfasst.config.ICESTORM_INSTALL_DIR / "icepack" / "iceunpack", bitstream_path]

        with open(asc_path, "w") as fp:
            process = subprocess.run(cmd, stdout=fp, stderr=subprocess.STDOUT, cwd=self.work_dir)

            if process.returncode:
                raise ReverseBitException("Error converting bitstream to ASCII file.")

    def convert_asc_to_netlist(self, asc_path, constraints_path, netlist_path):
        """Converts an ASC file to a netlist using IceStorm tools."""
        cmd = [
            bfasst.config.ICESTORM_INSTALL_DIR / "icebox" / "icebox_vlog.py",
            "-P",
            constraints_path,
            "-s",
            asc_path,
        ]

        with open(netlist_path, "w") as fp:
            process = subprocess.run(cmd, stdout=fp, stderr=subprocess.STDOUT, cwd=self.work_dir)

            if process.returncode:
                raise ReverseBitException("Error converting ASC file to netlist.")

    # TODO: Ideally, this function should probably check against the top-level
    #       I/O on the original RTL to make sure that none of the signals have
    #       the suffixes we're removing (i.e. they weren't added by IC2). For
    #       now, though, we'll assume that all suf/prefixes are not in the RTL.
    def fix_pcf_names(self):
        """
        Sometimes IC2 implementation can add stuff to signal names in PCF files
        (e.x. clk_i becomes clk_i_ibuf). This function removes those extra
        suffixes/prefixes. This also removes all location information from the
        PCF. For our purposes, we only need the set_io statements to infer
        the I/O signal names.
        """
        set_io_lines = []
        with open(self.design.constraints_path, "r") as pcf:
            for line in pcf:
                if line.split()[0] == "set_io":
                    set_io_lines.append(line)
        with open(self.design.constraints_path, "w") as pcf:
            for line in set_io_lines:
                new_line = re.sub("_ibuf", "", line)
                new_line = re.sub("ibuf_", "", new_line)
                new_line = re.sub("_obuf", "", new_line)
                new_line = re.sub("obuf_", "", new_line)
                new_line = re.sub("_gb_io", "", new_line)
                # While we're at it, if any lines match the wires we don't want
                #   in the pcf (because of a signal tap), don't write the new
                #   line.
                do_write = True
                for tap in self.design.nets_to_remove_from_pcf:
                    if re.search(tap, new_line):
                        do_write = False
                if do_write:
                    pcf.write(new_line)

    def write_to_results_file(self, netlist_path, need_to_run):
        """Writes the results of the reverse bitstream tool to the results file."""
        if self.design.results_summary_path is None:
            print("No results path set!")
            return
        with open(self.design.results_summary_path, "a") as res_f:
            time_modified = time.ctime(os.path.getmtime(netlist_path))
            res_f.write("Results from icestorm netlist (" + time_modified + "):\n")
            if not need_to_run:
                res_f.write("need_to_run is false, results may be out of date\n")
            with open(netlist_path, "r") as net_f:
                netlist = net_f.read()
                num_luts = netlist.count("/* LUT")
                num_carries = netlist.count("/* CARRY")
                num_ffs = netlist.count("/* FF")
                num_always_ffs = netlist.count("always @")
                num_assign_ffs = num_ffs - num_always_ffs
                num_ram40s = netlist.count("SB_RAM40_4K")
                res_f.write("  Number of LUTs: " + str(num_luts) + "\n")
                res_f.write("  Number of carry cells: " + str(num_carries) + "\n")
                res_f.write("  Number of flip flops: " + str(num_ffs) + "\n")
                res_f.write("    Flops w/ assign statements: " + str(num_assign_ffs) + "\n")
                res_f.write("    Flops w/ always statements: " + str(num_always_ffs) + "\n")
                res_f.write("  Number of RAM40Ks: " + str(num_ram40s) + "\n")
            res_f.write("\n")
