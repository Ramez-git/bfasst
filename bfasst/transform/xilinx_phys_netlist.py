""" Creates a xilinx netlist that has only physical primitives"""

import pathlib
import re

import jpype
import jpype.imports
from jpype.types import JInt

from bfasst import jpype_jvm
from bfasst.config import VIVADO_BIN_PATH
from bfasst.tool import ToolProduct
from bfasst.transform.base import TransformTool, TransformException
from bfasst.utils import TermColor
import bfasst.rw_helpers as rw


# pylint: disable=wrong-import-position,wrong-import-order
jpype_jvm.start()
from com.xilinx.rapidwright.device import SiteTypeEnum
from com.xilinx.rapidwright.design import Design, Unisim
from com.xilinx.rapidwright.edif import EDIFDirection, EDIFNet, EDIFPropertyValue, EDIFValueType
from java.lang import System
from java.io import PrintStream, File

# pylint: enable=wrong-import-position,wrong-import-order


class XilinxPhysNetlist(TransformTool):
    """Creates a xilinx netlist that has only physical primitives"""

    TOOL_WORK_DIR = "xilinx_phys_netlist"

    def __init__(self, work_dir, design):
        super().__init__(work_dir, design)
        self.vcc_edif_net = None

        # Rapidwright design / netlist
        self.rw_design = None
        self.rw_netlist = None

        # Cells to use for new Primitives
        self.lut6_2_edif_cell = None
        self.ram32x1s_edif_cell = None
        self.ram32x1s1_edif_cell = None
        self.ram32x1d_edif_cell = None
        self.ram32m_edif_cell = None
        self.bufgctrl_edif_cell = None

    def run(self):
        """Transform the logical netlist into a netlist with only physical primitives"""
        phys_netlist_verilog_path = self.design.impl_edif_path.parent / (
            self.design.impl_edif_path.stem + "_physical.v"
        )
        phys_netlist_edif_path = self.design.impl_edif_path.parent / (
            self.design.impl_edif_path.stem + "_physical.edf"
        )
        self.design.phys_netlist_path = phys_netlist_verilog_path

        # Redirect rapidwright output to file
        System.setOut(PrintStream(File(str(self.work_dir / "rapidwright_stdout.log"))))

        # Check for up to date previous run
        if not self.need_to_rerun(
            tool_products=[
                ToolProduct(phys_netlist_verilog_path),
            ],
            dependency_modified_time=max(
                pathlib.Path(__file__).stat().st_mtime,
                self.design.xilinx_impl_checkpoint_path.stat().st_mtime,
                self.design.impl_edif_path.stat().st_mtime,
            ),
        ):
            self.log("Physical netlist conversion already run")
            return

        self.log(
            "Starting logical to physical netlist conversion for",
            self.design.xilinx_impl_checkpoint_path,
            self.design.impl_edif_path,
            add_timestamp=True,
        )

        phys_netlist_checkpoint = self.work_dir / "phys_netlist.dcp"

        # Catch all Java exceptions since they are not picklable,
        # and so cannot be handled properly by multiprocessing
        # Don't raise from as this is also problematic.
        try:
            self.run_rapidwright(phys_netlist_checkpoint, phys_netlist_edif_path)
        except jpype.JException as exc:
            raise rw.RapidwrightException(str(exc))  # pylint: disable=raise-missing-from

        self.export_new_netlist(phys_netlist_checkpoint, phys_netlist_verilog_path)

    def get_or_create_const_net(self, unisim_cell):
        """Create an edif const cell/net if it doesn't exist"""
        assert unisim_cell in (Unisim.GND, Unisim.VCC)
        port_name = "G" if unisim_cell == Unisim.GND else "P"

        edif_cell = self.rw_netlist.getHDIPrimitive(unisim_cell)

        cell_insts = [
            inst
            for inst in self.rw_netlist.getTopCell().getCellInsts()
            if inst.getCellType() == edif_cell
        ]
        assert len(cell_insts) <= 1

        if cell_insts:
            return cell_insts[0].getPortInst(port_name).getNet()

        # Create new VCC instance as part of top-level
        name = "gnd" if unisim_cell == Unisim.GND else "vcc"

        vcc_edif_inst = self.rw_netlist.getTopCell().createChildCellInst(
            name + "_phys_netlist", edif_cell
        )

        # Create VCC net as part of top-level
        edif_net = EDIFNet(name + "_net_phys_netlist", self.rw_netlist.getTopCell())

        port = vcc_edif_inst.getPort(port_name)
        assert port
        edif_net.createPortInst(port, vcc_edif_inst)

        return edif_net

    def run_rapidwright(self, phys_netlist_checkpoint, phys_netlist_edif_path):
        """Do all rapidwright related processing on the netlist"""

        # Read the checkpoint into rapidwright, and get the netlist
        self.rw_design = Design.readCheckpoint(
            self.design.xilinx_impl_checkpoint_path, self.design.impl_edif_path
        )
        self.rw_netlist = self.rw_design.getNetlist()

        # Init BUFGCTRL cell template
        self.bufgctrl_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.BUFGCTRL)

        # Init LUT cell templates
        self.lut6_2_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.LUT6_2)
        self.ram32x1s_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.RAM32X1S)
        self.ram32x1s1_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.RAM32X1S_1)
        self.ram32x1d_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.RAM32X1D)
        self.ram32m_edif_cell = self.rw_netlist.getHDIPrimitive(Unisim.RAM32M)

        # Get/Create the VCC EDIF Net
        self.vcc_edif_net = self.get_or_create_const_net(Unisim.VCC)

        # Keep a list of old replaced cells to remove after processing
        cells_to_remove = []

        # Keep a list of cells already visited and skip them
        # This happens when we process LUTS mapped to the same BEL
        cells_already_visited = set()

        # First loop through all sites and deal with LUTs.  We can't the later loop that iterates
        # over Design.getCells() as it does not return LUT routethru objects.
        self.process_all_luts(cells_already_visited)

        # Loop through all cells in the design
        for cell in self.rw_design.getCells():
            edif_cell_inst = cell.getEDIFCellInst()

            self.log(
                cell.getName(),
                f"({edif_cell_inst.getCellType().getName() if edif_cell_inst else 'None'})",
            )

            if edif_cell_inst is None:
                self.log("  Skipping")
                continue

            if cell in cells_already_visited:
                continue

            cell_type = edif_cell_inst.getCellType().getName()
            if cell_type in ("MUXF7", "MUXF8"):
                cells_to_remove.extend(self.process_muxf7_muxf8(cell))
                continue

            if cell_type in ("CARRY4",):
                cells_to_remove.extend(self.process_carry4(cell))
                continue

            if cell_type in ("BUFG",):
                cells_to_remove.extend(self.process_bufg(cell))
                continue

            # These primitives don't need to get transformed
            if cell_type in ("IBUF", "OBUF", "OBUFT", "FDSE", "FDRE", "FDCE", "RAMB36E1", "FDPE"):
                continue

            # TODO: Handle other primitives? SRL, FIFO36, DSP48E1, etc.
            print(cell)
            raise TransformException(f"Unsupported cell type {cell_type}")

        # Remove old unusued cells
        self.log("Removing old cells...")
        for cell in cells_to_remove:
            self.log("  ", cell.getName())
            edif_cell_inst = cell.getEDIFCellInst()

            # Remove the port instances
            edif_cell_inst.getParentCell().removeCellInst(edif_cell_inst)

        # Export checkpoint, then run vivado to generate a new netlist
        self.rw_design.unplaceDesign()
        self.rw_design.writeCheckpoint(phys_netlist_checkpoint)

        self.log("\nWriting EDIF phsyical netlist:", phys_netlist_edif_path)
        self.rw_netlist.exportEDIF(phys_netlist_edif_path)

    def process_all_luts(self, cells_already_visited):
        """Visit all LUTs and replace them with LUT6_2 instances"""

        for site_inst in self.rw_design.getSiteInsts():
            if site_inst.getSiteTypeEnum() not in (SiteTypeEnum.SLICEL, SiteTypeEnum.SLICEM):
                continue

            lut_pair_bel_names = [
                ("A6LUT", "A6LUT_O6", "A5LUT", "A5LUT_O5"),
                ("B6LUT", "B6LUT_O6", "B5LUT", "B5LUT_O5"),
                ("C6LUT", "C6LUT_O6", "C5LUT", "C5LUT_O5"),
                ("D6LUT", "D6LUT_O6", "D5LUT", "D5LUT_O5"),
            ]

            gnd_nets = site_inst.getSiteWiresFromNet(self.rw_design.getGndNet())

            lut_rams = []
            for lut6_bel, lut6_pin_out, lut5_bel, lut5_pin_out in lut_pair_bel_names:
                lut6_cell = site_inst.getCell(lut6_bel)
                lut5_cell = site_inst.getCell(lut5_bel)

                if lut6_cell and lut6_cell.getType() == "RAMS32":
                    lut_rams.append(lut6_cell)
                    cells_already_visited.add(lut6_cell)
                    # Sanity check, pretty sure clk is not inverted when this value is one,
                    # so if there is a case where this changes, investigate the design to see.
                    assert (
                        lut6_cell.getEDIFCellInst().getProperty("IS_CLK_INVERTED").getValue()
                        == "1'b1"
                    )
                    # TODO: handle possible gnd net
                    continue
                if len(lut_rams) > 1:
                    self.process_lutrams(lut_rams)

                lut_rams = []

                gnd_generator_pins = []
                if lut6_pin_out in gnd_nets:
                    # If a gnd net, then there can't be a cell there
                    assert lut6_cell is None
                    assert lut5_cell is None

                    gnd_generator_pins.append(lut6_pin_out)

                if lut5_pin_out in gnd_nets:
                    # If a gnd net, then there can't be a cell there
                    # This assumption is not true for LUTRAMs
                    assert lut6_cell is None
                    assert lut5_cell is None

                    gnd_generator_pins.append(lut5_pin_out)

                if lut6_cell or lut5_cell:
                    self.process_lut(lut6_cell, lut5_cell)

                elif gnd_generator_pins:
                    self.process_lut_gnd(site_inst, gnd_generator_pins)

                if lut6_cell:
                    cells_already_visited.add(lut6_cell)
                if lut5_cell:
                    cells_already_visited.add(lut5_cell)

            if len(lut_rams) > 1:
                self.process_lutrams(lut_rams)

    def export_new_netlist(self, phys_netlist_checkpoint, phys_netlist_verilog_path):
        """Export the new netlist to a Verilog netlist file"""

        self.log("\nUsing Vivado to create new netlist:", phys_netlist_verilog_path)

        vivado_tcl_path = self.work_dir / "vivado_checkpoint_to_netlist.tcl"
        with open(vivado_tcl_path, "w") as fp:
            fp.write(f"write_verilog -force {phys_netlist_verilog_path}\n")
            fp.write("exit\n")

        vivado_log_path = self.work_dir / "vivado_edf_to_v.txt"
        cmd = [
            VIVADO_BIN_PATH,
            phys_netlist_checkpoint,
            "-mode",
            "batch",
            "-source",
            vivado_tcl_path,
        ]
        cwd = None
        with open(vivado_log_path, "w") as fp:
            if self.exec_and_log(cmd, cwd, fp).returncode:
                raise TransformException("Vivado failed to export new netlist to verilog")

        self.check_vivado_output(vivado_log_path)

        self.log("Exported new netlist to", phys_netlist_verilog_path)

    def check_vivado_output(self, vivado_log_path):
        """Check the log output of the Vivado exeuction for ERROR messages"""
        txt = open(vivado_log_path).read()

        # Check for ERROR message:
        matches = re.search("^ERROR: (.*)$", txt, re.M)
        if matches:
            raise TransformException(f"Vivado reported an error: {matches.group(1)}")

    def check_ram32x1d(self, lut_rams, parents):
        """Check if cells can be combined to RAM32X1D"""
        same_nets = ["WE", "WCLK", "D"]

        # check for ram32x1d (2 luts)
        lut6_cell = lut_rams[0]
        ram32x1s_cell = parents[0].getInst()
        nets_lh = rw.get_net_names_from_edif_ports(lut6_cell, same_nets, ram32x1s_cell)
        init = lut6_cell.getProperty("INIT")
        for lut6_cell_rh, hier_cell in zip(lut_rams[1:], parents[1:]):
            ram32x1s_cell = hier_cell.getInst()
            nets_rh = rw.get_net_names_from_edif_ports(lut6_cell_rh, same_nets, ram32x1s_cell)
            init2 = lut6_cell_rh.getProperty("INIT")
            if init != init2:
                nets_lh = nets_rh
                init = init2
                lut6_cell = lut6_cell_rh
                continue

            for lh, rh in zip(nets_lh, nets_rh):
                if lh != rh:
                    nets_lh = nets_rh
                    init = init2
                    lut6_cell = lut6_cell_rh
                    break
            else:
                self.process_ram32x1d((lut6_cell, lut6_cell_rh))
                return lut_rams

    def process_ram32x1d(self, cells):
        """
        Replace two RAM32X1S cells with a single RAM32X1D cell.
        """
        parent, edif_cells = self.lutram_assertions(cells)
        new_cell_name = rw.generate_combinded_cell_name(edif_cells)
        cell_str = f"2 LUT_RAMS ({' '.join([str(n.getName()) for n in cells])})"
        self.log(f"\nConverting {cell_str} to RAM32X1D {new_cell_name}")

        ram32x1d = parent.createChildCellInst(new_cell_name, self.ram32x1d_edif_cell)

        ram32x1d.addProperty("INIT", edif_cells[0].getProperty("INIT"))
        rw.valid_net_transfer("WE", ["WE"], edif_cells[0], ram32x1d)
        rw.valid_net_transfer("WCLK", ["WCLK"], edif_cells[0], ram32x1d)
        rw.valid_net_transfer("D", ["D"], edif_cells[0], ram32x1d)

        addrs = ["A0", "A1", "A2", "A3", "A4"]
        for addr in addrs:
            rw.valid_net_transfer(addr, [addr], edif_cells[0], ram32x1d)
        rw.valid_net_transfer("O", ["DPO"], edif_cells[0], ram32x1d)

        rd_addrs = ["DPRA0", "DPRA1", "DPRA2", "DPRA3", "DPRA4"]
        for addr, rd_addr in zip(addrs, rd_addrs):
            rw.valid_net_transfer(addr, [rd_addr], edif_cells[1], ram32x1d)
        rw.valid_net_transfer("O", ["SPO"], edif_cells[1], ram32x1d)

        return ram32x1d

    def process_ram32m(self, cells):
        """
        Replace four RAM32X1S cells with a single RAM32M cell.
        """
        parent, edif_cells = self.lutram_assertions(cells)
        new_cell_name = rw.generate_combinded_cell_name(edif_cells)
        cell_str = f"4 LUT_RAMS ({' '.join([str(n.getName()) for n in cells])})"
        self.log(f"\nConverting {cell_str} to RAM32M {new_cell_name}")

        ram32m = parent.createChildCellInst(new_cell_name, self.ram32m_edif_cell)

        prefix = ["A", "B", "C", "D"]
        for i, cell in zip(prefix, edif_cells):
            val = str(cell.getProperty("INIT").getValue())[4:]
            ram32m.addProperty(f"INIT_{i}", f"64'h{int(val, base=16):0{16}X}")

        rw.valid_net_transfer("WE", ["WE"], edif_cells[0], ram32m)
        rw.valid_net_transfer("WCLK", ["WCLK"], edif_cells[0], ram32m)

        addrs = ["A0", "A1", "A2", "A3", "A4"]
        for i, cell in zip(prefix, edif_cells):
            rw.valid_bus_transfer(addrs, f"ADDR{i}", cell, ram32m)
            rw.valid_bus_transfer("D", f"DI{i}", cell, ram32m)
            rw.valid_bus_transfer("O", f"DO{i}", cell, ram32m)

        return ram32m

    def lutram_assertions(self, lut_rams):
        """
        Run sanity assertions on LUTRAMs.

        Returns:
        (EDIFCell, [EDIFCellInst]) -> (parent cell, [child insts])
        """
        hedif_cells = [c.getEDIFHierCellInst() for c in lut_rams]
        parents1 = [c.getParent() for c in hedif_cells]
        test_type = {t.getCellType().getName() for t in parents1}
        test_type.add("RAM32X1S")
        assert len(test_type) == 1

        # Need to go up 2 levels: True parent -> RAM32X1S -> RAMS32 (current cell)
        parent = {c.getParent().getParent() for c in hedif_cells}
        assert len(parent) == 1

        return (parent.pop().getCellType(), [c.getParent().getInst() for c in hedif_cells])

    def process_lutrams(self, lut_rams):
        """
        Look at LUTRAMs in a site and see if they should be combined into a
        single RAM primitive.  RAMS32 is wrapped in RAM32X1S (parent cell), so
        LUTRAMs only need processed if they can be combined.
        """

        if len(lut_rams) == 1:
            return lut_rams

        parents = [c.getEDIFHierCellInst().getParent() for c in lut_rams]

        if len(lut_rams) == 4:
            same_nets = ["WE", "WCLK"]
            lut6_cell = lut_rams[0]
            ram32x1s_cell = parents[0].getInst()
            nets_lh = rw.get_net_names_from_edif_ports(lut6_cell, same_nets, ram32x1s_cell)
            for lut6_cell, hier_cell in zip(lut_rams[1:], parents[1:]):
                ram32x1s_cell = hier_cell.getInst()
                nets_rh = rw.get_net_names_from_edif_ports(lut6_cell, same_nets, ram32x1s_cell)
                for lh, rh in zip(nets_lh, nets_rh):
                    if lh != rh:
                        return self.check_ram32x1d(lut_rams, parents)
            self.process_ram32m(lut_rams)
            return lut_rams

        return self.check_ram32x1d(lut_rams, parents)

    def process_muxf7_muxf8(self, cell):
        """Process MUXF7/MUXF8 primitive
        Not sure whether inputs can be permuted or not, but for now let's
        assume they can't be and throw a NotImplementedError exception if
        they are permuted in some way."""

        type_name = cell.getEDIFCellInst().getCellType().getName()
        self.log(f"\nProcessing {type_name}", cell)
        if rw.PinMapping.cell_is_default_mapping(cell):
            self.log("  Inputs not permuted, skipping")
            return []

        raise NotImplementedError

    def process_carry4(self, cell):
        """Process CARRY4 primitive
        Not sure whether inputs can be permuted or not, but for now let's
        assume they can't be and throw a NotImplementedError exception if
        they are permuted in some way."""
        type_name = cell.getEDIFCellInst().getCellType().getName()
        self.log(f"\nProcessing {type_name}", cell)

        if rw.PinMapping.cell_is_default_mapping(cell):
            self.log("  Inputs not permuted, skipping")
            return []

        raise NotImplementedError

    def process_bufg(self, bufg_cell):
        """Convert BUFG to BUFGCTRL"""
        bufg_edif_inst = bufg_cell.getEDIFCellInst()
        assert bufg_edif_inst

        type_name = bufg_edif_inst.getCellType().getName()
        self.log(f"\nProcessing {type_name}", bufg_cell)

        assert rw.PinMapping.cell_is_default_mapping(bufg_cell)

        new_cell_name = bufg_edif_inst.getName() + "_phys"
        bufgctrl = bufg_edif_inst.getParentCell().createChildCellInst(
            new_cell_name, self.bufgctrl_edif_cell
        )

        self.log("Created new cell", new_cell_name)

        bufgctrl.setPropertiesMap(bufg_edif_inst.createDuplicatePropertiesMap())

        # set default properties
        for prop_name in ("INIT_OUT", "IS_CE0_INVERTED", "IS_IGNORE1_INVERTED", "IS_S0_INVERTED"):
            bufgctrl.addProperty(prop_name, JInt(0))

        for prop_name in ("IS_CE1_INVERTED", "IS_IGNORE0_INVERTED", "IS_S1_INVERTED"):
            bufgctrl.addProperty(prop_name, JInt(1))

        bufgctrl.addProperty("PRESELECT_I0", "TRUE")
        bufgctrl.addProperty("PRESELECT_I1", "FALSE")

        # Copy pins
        self.log(f"  Copying pins from {bufg_cell.getName()}")

        for pins in bufg_cell.getPinMappingsL2P().items():
            rw.valid_net_transfer(*pins, bufg_edif_inst, bufgctrl)

        # Set default connections
        for port_name in ("CE0", "CE1", "I1", "IGNORE0", "IGNORE1", "S0", "S1"):
            port = bufgctrl.getPort(port_name)
            assert port
            self.vcc_edif_net.createPortInst(port, bufgctrl)

        return [bufg_cell]

    def process_lut_gnd(self, site_inst, pins):
        """Process a LUT that isn't part of the design (ie no cell), but
        is configured to generate a GND signal"""

        self.log(
            TermColor.BLUE,
            f"\nProcessing LUT GND at site {site_inst}, pin(s):",
            ",".join(str(p) for p in pins),
        )

        # Create a new lut6_2 instance
        new_cell_name = str(site_inst.getName()) + "." + ".".join(p for p in pins) + ".GND.gen"
        new_cell_inst = self.rw_design.getTopEDIFCell().createChildCellInst(
            new_cell_name, self.lut6_2_edif_cell
        )
        new_cell_inst.setPropertiesMap(
            {"INIT": EDIFPropertyValue("64'h0000000000000000", EDIFValueType.STRING)}
        )
        self.log("Created new cell", new_cell_name)

        for pin_out in pins:
            self.log("Processing GND output pin", pin_out)

            # Create a new net to replace the global ground
            new_net_name = str(site_inst.getName()) + "." + pin_out + ".GND"
            self.log("  Creating new GND net", new_net_name)
            new_net = EDIFNet(new_net_name, self.rw_design.getTopEDIFCell())

            # Drive net using LUT output port
            lut_out_port = new_cell_inst.getPort("O6" if pin_out.endswith("O6") else "O5")
            self.log("  Connecting new net to LUT output port", lut_out_port.getName())
            assert lut_out_port
            new_net.createPortInst(lut_out_port, new_cell_inst)

            # Loop through ports this GND net needs to drive and connect them up
            for pin_in in site_inst.getSiteWirePins(pin_out):
                cell = site_inst.getCell(pin_in.getBEL())
                if cell:
                    self.log(" ", pin_in, pin_in.getBEL(), site_inst.getCell(pin_in.getBEL()))
                    routed_to_cell_inst = cell.getEDIFCellInst()

                    # Map physical pin back to logical netlist port name
                    assert rw.PinMapping.cell_is_default_mapping(cell)
                    logical_port_name = rw.PinMapping[
                        routed_to_cell_inst.getCellType().getName()
                    ].inverse[pin_in.getName()]

                    routed_to_port_inst = routed_to_cell_inst.getPortInst(logical_port_name)
                    assert routed_to_port_inst

                    # Disconnect const0 net from pin
                    routed_to_cell_inst.getPortInst(logical_port_name).getNet().removePortInst(
                        routed_to_port_inst
                    )

                    # Connect up new LUT GND net to pin
                    if routed_to_port_inst.getPort().isBus():
                        new_net.createPortInst(
                            routed_to_port_inst.getPort(),
                            routed_to_port_inst.getIndex(),
                            routed_to_cell_inst,
                        )
                    else:
                        new_net.createPortInst(routed_to_port_inst.getPort(), routed_to_cell_inst)

                    # Connect inputs to VCC
                    for logical_port in rw.PinMapping["LUT6_2"]:
                        if logical_port.startswith("I"):
                            assert not new_cell_inst.getPortInst(logical_port)
                            self.get_or_create_const_net(Unisim.VCC).createPortInst(
                                new_cell_inst.getPort(logical_port), new_cell_inst
                            )

    def process_lut(self, lut6_cell, lut5_cell):
        """This function takes a LUT* from the netlist and replaces with with a LUT6_2
        with logical mapping equal to the physical mapping."""

        assert lut6_cell is not None
        self.log(
            "\nProcessing and replacing LUT(s):",
            ",".join(
                str(lut_cell) + ("(routethru)" if lut_cell.isRoutethru() else "")
                for lut_cell in (lut6_cell, lut5_cell)
                if lut_cell is not None
            ),
        )
        lut6_edif_cell_inst = lut6_cell.getEDIFCellInst()
        assert lut6_edif_cell_inst

        #### Get name for new LUT6_2 cell
        new_cell_name = lut6_edif_cell_inst.getName() + "_phys"

        # Routethru only?
        if lut6_cell.isRoutethru() and (lut5_cell is None or lut5_cell.isRoutethru()):
            # Suffix routethru as _RT(ABCD)
            new_cell_name = (
                lut6_edif_cell_inst.getName() + "_routethru_" + str(lut6_cell.getBEL().getName())[0]
            )

        if lut5_cell:
            new_cell_name += "_shared"

        #### Create the new LUT6_2 instance
        new_cell_inst = lut6_edif_cell_inst.getParentCell().createChildCellInst(
            new_cell_name, self.lut6_2_edif_cell
        )
        self.log("Created new cell", new_cell_name)

        ##### Copy all properties from existing LUT to new LUT (INIT will be fixed later)
        new_cell_inst.setPropertiesMap(lut6_edif_cell_inst.createDuplicatePropertiesMap())
        # TODO: If other_lut_cell is not None, then check that properties don't conflict?

        #### Wire up inputs/outputs
        physical_pins_to_nets = {}

        self.log(f"Processing LUT {lut6_cell.getName()}")
        for logical_pin, physical_pin in lut6_cell.getPinMappingsL2P().items():
            assert len(physical_pin) == 1
            physical_pin = list(physical_pin)[0]

            port_inst = lut6_edif_cell_inst.getPortInst(logical_pin)
            assert port_inst
            physical_pins_to_nets[physical_pin] = port_inst.getNet()

            self.lut_move_net_to_new_cell(
                lut6_edif_cell_inst, new_cell_inst, logical_pin, physical_pin
            )

        # Now do the same for the other LUT
        if lut5_cell:
            self.log(f"Processing LUT {lut5_cell.getName()}")
            for logical_pin, physical_pin in lut5_cell.getPinMappingsL2P().items():
                assert len(physical_pin) == 1
                physical_pin = list(physical_pin)[0]

                lut5_edif_cell_inst = lut5_cell.getEDIFCellInst()
                port_inst = lut5_edif_cell_inst.getPortInst(logical_pin)
                assert port_inst

                # Disconnect net from logical pin on old cell,
                # and connect to new logical pin (based on physical pin) of new cell
                self.lut_move_net_to_new_cell(
                    lut5_edif_cell_inst,
                    new_cell_inst,
                    logical_pin,
                    physical_pin,
                    already_connected_net=physical_pins_to_nets.get(physical_pin),
                )

        # Connect up remaining inputs to VCC
        for logical_port in rw.PinMapping["LUT6_2"]:
            if logical_port.startswith("I"):
                port = new_cell_inst.getPortInst(logical_port)
                if not port:
                    self.vcc_edif_net.createPortInst(
                        new_cell_inst.getPort(logical_port), new_cell_inst
                    )

        # If old cell is a LUT route through some extra processing is required.
        # LUT route through cells don't exist in the original netlist (the original net
        # goes straight to the FF), so now that the net is going to stop at the LUT input,
        # a new net is needed to connect LUT output to FF
        if lut6_cell.isRoutethru():
            self.create_lut_routethru_net(lut6_cell, False, new_cell_inst)
        if lut5_cell and lut5_cell.isRoutethru():
            self.create_lut_routethru_net(lut5_cell, True, new_cell_inst)

        # Fix the new LUT INIT property based on the new pin mappings
        rw.process_lut_init(lut6_cell, lut5_cell, new_cell_inst, self.log)

        # Return the cells to be removed
        cells_to_remove = []
        if not lut6_cell.isRoutethru():
            cells_to_remove.append(lut6_cell)
        if lut5_cell and not lut5_cell.isRoutethru():
            cells_to_remove.append(lut5_cell)
        return cells_to_remove

    def create_lut_routethru_net(self, cell, is_lut5, new_lut_cell):
        """Extra processing for LUT route through.  Need to create a new net
        connecting from the new LUT6_2 instance to the FF"""

        self.log("Creating routethru for", cell.getName())

        # Create the new net
        new_net_name = (
            cell.getName()
            + "_routethru_"
            + str(cell.getBEL().getName())[0]
            + ("6" if not is_lut5 else "5")
        )
        self.log("  Creating new net", new_net_name)
        new_net = EDIFNet(new_net_name, cell.getEDIFCellInst().getParentCell())

        # Connect net to LUT output
        lut_out_port = new_lut_cell.getPort("O5" if is_lut5 else "O6")
        assert lut_out_port
        self.log(
            "  Connecting new net to LUT", new_lut_cell.getName(), "port", lut_out_port.getName()
        )
        new_net.createPortInst(lut_out_port, new_lut_cell)

        # Connect net to the input of the other cell in this site (FF, CARRY4)
        matching_cells = [
            other_cell
            for other_cell in cell.getSiteInst().getCells()
            if other_cell.getName() == cell.getName() and not other_cell.isRoutethru()
        ]
        assert len(matching_cells) == 1
        routed_to_cell = matching_cells[0]
        routed_to_cell_inst = routed_to_cell.getEDIFCellInst()

        # First figure out which logical pin this routethru goes to.
        # Even though we are calling the gePinMappingsL2P on the LUT cell,
        # it doesn't actually return the logical pin on the LUT, but rather
        # the downstream cell (FF, CARRY4).
        logical_pins = list(cell.getPinMappingsL2P().keys())
        assert len(logical_pins) == 1
        routed_to_port_name = str(logical_pins[0])

        routed_to_port_inst = routed_to_cell_inst.getPortInst(routed_to_port_name)
        assert routed_to_port_inst

        self.log(
            "  Connecting new net to BEL",
            routed_to_cell.getBEL().getName(),
            ", port",
            routed_to_port_name,
        )

        if routed_to_port_inst.getPort().isBus():
            new_net.createPortInst(
                routed_to_port_inst.getPort(), routed_to_port_inst.getIndex(), routed_to_cell_inst
            )
        else:
            new_net.createPortInst(routed_to_port_inst.getPort(), routed_to_cell_inst)

    def lut_move_net_to_new_cell(
        self,
        old_edif_cell_inst,
        new_edif_cell_inst,
        old_logical_pin,
        physical_pin,
        already_connected_net=None,
    ):
        """This function connects the net from old_edif_cell_inst/old_logical_pin,
        to the appropriate logical pin on the new_edif_cell_inst, based on the physical pin,
        and disconnects from the old cell.  It's possible the net is already_connected to the
        new cell, in which case only the disconnect from old cell needs to be performed."""

        self.log(f"  Processing logical pin {old_logical_pin}, physical pin {physical_pin}")

        port_inst = old_edif_cell_inst.getPortInst(old_logical_pin)
        logical_net = port_inst.getNet()
        assert logical_net

        if already_connected_net:
            assert logical_net == already_connected_net
            self.log(f"    Skipping already connected physical pin {physical_pin}")

        else:
            if port_inst.getDirection() == EDIFDirection.INPUT:
                self.log("    Input driven by net", logical_net)

                # A5 becomes I4, A1 becomes I0, etc.
                new_logical_pin = f"I{int(str(physical_pin[1])) - 1}"
                self.log(
                    "    Connecting net",
                    logical_net,
                    "to input pin",
                    new_logical_pin,
                    "on new cell",
                )

            elif port_inst.getDirection() == EDIFDirection.OUTPUT:
                self.log("    Drives net", logical_net)

                new_logical_pin = physical_pin
                self.log("    Connecting net", logical_net, "to output pin", new_logical_pin)

            new_port = new_edif_cell_inst.getPort(new_logical_pin)
            assert new_port
            logical_net.createPortInst(new_port, new_edif_cell_inst)

        # Disconnect connection to port on old cell
        self.log("    Disconnecting net", logical_net, "from pin", old_logical_pin, "on old cell")
        logical_net.removePortInst(port_inst)
