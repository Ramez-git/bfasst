"""Subflow that combines xilinx phys netlist and xray/f2b reversal."""

# pylint: disable=duplicate-code

from bfasst.flows.flow import Flow
from bfasst.flows.xilinx_phys_netlist import XilinxPhysNetlist
from bfasst.job import Job
from bfasst.reverse_bit.xray import XRayReverseBitTool
from bfasst.types import ToolType


class XilinxPhysNetlistXrev(Flow):
    """
    Subflow that combines xilinx phys netlist and xray/f2b reversal.
    """

    def create(self):
        """Run XilinxPhysNetlistFlow and the Xray Rev"""

        # Reset job list in case this flow is called multiple times
        self.job_list = []

        if "--max_dsp" not in self.flow_args[ToolType.SYNTH]:
            self.flow_args[ToolType.SYNTH] += " --max_dsp 0"

        self.job_list.extend(XilinxPhysNetlist(self.design, self.flow_args).create())

        xray_rev_tool = XRayReverseBitTool(
            self.design.build_dir, self.design, self.flow_args[ToolType.REVERSE]
        )
        curr_job = Job(
            xray_rev_tool.reverse_bitstream, self.design.rel_path, {self.job_list[-1].uuid}
        )
        self.job_list.append(curr_job)

        return self.job_list
