set board_file [file normalize "/home/marvardoul/PUF_SWITCH_NEW/PUF_PROJECT/puf_integrataion/puf_integrataion.srcs/sources_1/new/board_top.vhd"]
set rmii_xdc [file normalize "/home/marvardoul/PUF_SWITCH_NEW/PUF_PROJECT/puf_integrataion/puf_integrataion.srcs/constrs_1/new/rmii_dp83848_2port.xdc"]

puts "BOARD TOP:"
puts $board_file

puts "RMII XDC:"
puts $rmii_xdc

if {[llength [get_files -quiet $rmii_xdc]] == 0} {
    add_files -fileset constrs_1 $rmii_xdc
}

set_property USED_IN {synthesis implementation} [get_files $rmii_xdc]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "PHYSICAL RMII INTEGRATION FILES:"
get_files -all *puf_rmii_switch_2port.vhd
get_files -all *puf_egress_trailer.vhd
get_files -all *switch_core.vhd
get_files -all *board_top.vhd
get_files -all *rmii_dp83848_2port.xdc

puts ""
puts "TOP:"
puts [get_property top [current_fileset]]
