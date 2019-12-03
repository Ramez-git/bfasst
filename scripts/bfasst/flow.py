import enum
import abc
import os

import bfasst


@enum.unique
class Flows(enum.Enum):
    IC2_LSE_CONFORMAL = "IC2_lse_conformal"
    YOSYS_TECH = "yosys_tech"


# This uses a lambda so that I don't have to define all of the functions before this point
flow_fcn_map = {
    Flows.IC2_LSE_CONFORMAL: lambda: flow_ic2_lse_conformal,
    Flows.YOSYS_TECH: lambda: flow_yosys_tech(design, build_dir)
}

def get_flow_fcn_by_name(flow_name):
    invalid_flow = False

    try:
        flow_enum = Flows(flow_name)
    except ValueError:
        invalid_flow = True
        
    if invalid_flow:
        bfasst.utils.error(flow_name, "is not a valid flow name")

    fcn = flow_fcn_map[flow_enum]()
    return fcn



class Tool(abc.ABC):
    def __init__(self, cwd):
        super().__init__()
        self.cwd = cwd

        self.work_dir = self.make_work_dir()

    @property
    @classmethod
    @abc.abstractclassmethod
    def TOOL_WORK_DIR(self):
        raise NotImplementedError

    def make_work_dir(self):
        work_dir = self.cwd / self.TOOL_WORK_DIR

        if not work_dir.is_dir():
            work_dir.mkdir()
        return work_dir

def run_flow(design, flow_type, build_dir):
    assert type(design) is bfasst.design.Design

    flow_fcn = bfasst.flow.get_flow_fcn_by_name(flow_type)
    return flow_fcn(design, build_dir)


def flow_ic2_lse_conformal(design, build_dir):
    # Run Icecube2 LSE synthesis
    synth_tool = bfasst.synth.ic2_lse.IC2_LSE_SynthesisTool(build_dir)
    status = synth_tool.create_netlist(design)
    if status.error:
        return status

    # Run Icecube2 implementations
    impl_tool = bfasst.impl.ic2.IC2_ImplementationTool(build_dir)
    status = impl_tool.implement_bitstream(design)
    if status.error:
        return status

    # Run icestorm bitstream reversal
    reverse_bit_tool = bfasst.reverse_bit.icestorm.Icestorm_ReverseBitTool(
        build_dir)
    status = reverse_bit_tool.reverse_bitstream(design)
    if status.error:
        return status

    # Run conformal
    compare_tool = bfasst.compare.conformal.Conformal_CompareTool(build_dir)
    status = compare_tool.compare_netlists(design)
    if status.error:
        return status

    return status
