set_property PACKAGE_PIN D7 [get_ports SYS_CLK_P]
set_property PACKAGE_PIN D6 [get_ports SYS_CLK_N]
set_property IOSTANDARD LVDS [get_ports SYS_CLK_P]
set_property IOSTANDARD LVDS [get_ports SYS_CLK_N]

create_clock -period 10.000 -name SYS_CLK [get_ports SYS_CLK_P]


set_property PACKAGE_PIN AB1 [get_ports {PL_USER_SW[0]}]
set_property PACKAGE_PIN AF1 [get_ports {PL_USER_SW[1]}]
set_property PACKAGE_PIN AE3 [get_ports {PL_USER_SW[2]}]
set_property PACKAGE_PIN AC2 [get_ports {PL_USER_SW[3]}]
set_property PACKAGE_PIN AC1 [get_ports {PL_USER_SW[4]}]
set_property PACKAGE_PIN AD6 [get_ports {PL_USER_SW[5]}]
set_property PACKAGE_PIN AD1 [get_ports {PL_USER_SW[6]}]
set_property PACKAGE_PIN AD2 [get_ports {PL_USER_SW[7]}]

set_property IOSTANDARD LVCMOS12 [get_ports {PL_USER_SW[*]}]


set_property PACKAGE_PIN AB6 [get_ports {PL_USER_PB[0]}]
set_property PACKAGE_PIN AB7 [get_ports {PL_USER_PB[1]}]

set_property IOSTANDARD LVCMOS12 [get_ports {PL_USER_PB[*]}]


set_property PACKAGE_PIN AF5 [get_ports {PL_USER_LED[0]}]
set_property PACKAGE_PIN AE7 [get_ports {PL_USER_LED[1]}]
set_property PACKAGE_PIN AH2 [get_ports {PL_USER_LED[2]}]
set_property PACKAGE_PIN AE5 [get_ports {PL_USER_LED[3]}]
set_property PACKAGE_PIN AH1 [get_ports {PL_USER_LED[4]}]

set_property IOSTANDARD LVCMOS12 [get_ports {PL_USER_LED[*]}]



