"""Job class for a job function and dependency list"""


from bfasst.tool import BfasstException


class Job:
    """Class for a job function and dependency list"""

    def __init__(self, function, design_rel_path, dependencies=None):
        self.function = function
        self.design_rel_path = design_rel_path
        self.dependencies = dependencies

    def invert(self):
        """This can be called in the case where we want to invert the job's exception handling"""
        return Job(self.inverter, self.design_rel_path, self.dependencies)

    def inverter(self):
        try:
            self.function()
        except BfasstException:
            return

        raise BfasstException("Job succeeded but was expected to fail")
