import abc

from bfasst.tool import Tool
from bfasst.status import Status, ErrorInjectionStatus


class ErrorInjectionTool(Tool):
    def __init__(self, cwd, flow_args="") -> None:
        super().__init__(cwd, flow_args)
        self.success_status = Status(ErrorInjectionStatus.SUCCESS)

    # run_error_flows
    # If one or more error flows are specified with an error flow YAML,
    #   this function runs each of them and returns ([netlist_list], status),
    #   where:
    #     - [netlist list] is a list of paths to corrupted netlists generated by
    #       the error flows. e.x. if the YAML file specifies 2 flows, the netlist
    #       list will be [path_to_corrupt_netlist_1, path_to_corrupt_netlist_2]
    #     - status is a Status object from bfasst.status
    @abc.abstractmethod
    def run_error_flows(self, design):
        pass
