set ro_loop_nets [get_nets -hier -regexp {.*OSC_COMP/stage_1$}]

set_property ALLOW_COMBINATORIAL_LOOPS TRUE $ro_loop_nets