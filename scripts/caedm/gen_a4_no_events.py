#!/usr/bin/env python

#import os
from os import listdir
from os.path import isfile, join
import sys

# usage: gendo 

def main():

	# get path to tech-mapped netlist
	pathToDesign = sys.argv[1]
	srcDir = pathToDesign 
	techMapping = pathToDesign + "/" + srcDir.split('/')[-1:][0] + ".vm"

	print "looking for tech-mapped netlist", techMapping, " in", srcDir

	# build file name
	dofile = join(pathToDesign, "dofile_no_events.do")
	print "creating", dofile
	
	# open the file and do the deed
	with open(dofile, "w+") as f:

		f.write("// generated by cmonster\n")

		# set max loop iterations (yosys libraries choke on this)
		f.write("set hdl options -max_for_loop_size 16384\n")

		# read libraries
		# TODO parameterize path to lattice libraries
		f.write("read library -Both -Replace -sensitive -Verilog /auto/fsh/crg3710/research/lattice_libraries/cmonster.v -nooptimize\n")
		f.write("read library -Revised -Replace -sensitive -Verilog /auto/fsh/crg3710/research/yosys_libraries/arith_map.v -nooptimize\n")
		f.write("read library -Revised -Append -sensitive -Verilog /auto/fsh/crg3710/research/yosys_libraries/cells_sim.v -nooptimize\n")

		# renaming rules
		f.write("add renaming rule inputs _ibuf \"\" -map -type PI -Revised\n")
		f.write("add renaming rule outputs _obuf \"\" -map -type PO -Revised\n")
		f.write("add renaming rule input_buf _iobuf \"\" -map -type PI -Revised\n")
		f.write("add renaming rule output_buf _iobuf \"\" -map -type PO -Revised\n")

		# read golden design
		f.write("read design %s -Verilog -Golden -continuousassignment Bidirectional -norangeconstraint -nooptimize\n" % techMapping)

		# read revised design
		print "looking for extracted netlist in", pathToDesign
		for ugh in listdir(pathToDesign):

			if ugh.endswith("_extracted.v"):

				extracted = join(pathToDesign, ugh)
				f.write("read design %s -Verilog -Revised -sensitive -continuousassignment Bidirectional -nosupply -nooptimize\n" % extracted)

				# add secret sauce
				# f.write("set mapping method -name guide\n")
				f.write("set mapping effort high\n")
				f.write("set compare effort complete\n")
				f.write("set system mode lec\n")
				f.write("add compared points -all\n")
				f.write("compare\n")
				f.write("exit -f")

if __name__=="__main__":
	main()
