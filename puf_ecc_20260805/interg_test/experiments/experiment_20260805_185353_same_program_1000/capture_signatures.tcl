proc fail {message} {
    puts stderr "ERROR: $message"
    exit 1
}

proc find_named_probe {core patterns} {
    set probes [get_hw_probes -quiet -of_objects $core]

    foreach pattern $patterns {
        foreach probe $probes {
            set probe_name [string tolower [get_property NAME $probe]]

            if {[string match $pattern $probe_name]} {
                return $probe
            }
        }
    }

    return ""
}

if {[llength $argv] < 5} {
    fail "Usage: capture_signatures.tcl <count> <output_dir> <ltx_file> <bit_file> <program_0_or_1>"
}

set capture_count [lindex $argv 0]
set output_dir    [file normalize [lindex $argv 1]]
set ltx_file      [file normalize [lindex $argv 2]]
set bit_file      [file normalize [lindex $argv 3]]
set program_fpga  [lindex $argv 4]

file mkdir $output_dir

puts "Capture count : $capture_count"
puts "Output folder : $output_dir"
puts "Probe file    : $ltx_file"
puts "Bitstream     : $bit_file"
puts "Program FPGA  : $program_fpga"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set hw_device ""

foreach device [get_hw_devices] {
    set device_name [string tolower [get_property NAME $device]]
    set device_part [string tolower [get_property PART $device]]

    if {[string match "*xczu3*" $device_name] ||
        [string match "*xczu3*" $device_part]} {
        set hw_device $device
        break
    }
}

if {$hw_device eq ""} {
    puts "Detected hardware devices:"
    puts [get_hw_devices]
    fail "XCZU3 device was not found."
}

current_hw_device $hw_device

set_property PROBES.FILE $ltx_file $hw_device
set_property FULL_PROBES.FILE $ltx_file $hw_device

if {$program_fpga eq "1"} {
    puts "Programming FPGA..."

    set_property PROGRAM.FILE $bit_file $hw_device
    program_hw_devices $hw_device
}

refresh_hw_device $hw_device

set ila_cores [get_hw_ilas -quiet -of_objects $hw_device]
set vio_cores [get_hw_vios -quiet -of_objects $hw_device]

if {[llength $ila_cores] == 0} {
    fail "No ILA core was detected."
}

if {[llength $vio_cores] == 0} {
    fail "No VIO core was detected."
}

set ila ""

foreach candidate $ila_cores {
    set signature_probe [find_named_probe $candidate {
        "*signature_internal*"
        "*signature_valid_mask*"
    }]

    if {$signature_probe ne ""} {
        set ila $candidate
        break
    }
}

if {$ila eq ""} {
    set ila [lindex $ila_cores 0]
}

set vio ""
set start_probe ""

foreach candidate $vio_cores {
    set candidate_probe [find_named_probe $candidate {
        "*signature_start*"
        "*vio_start*"
        "*start*"
    }]

    if {$candidate_probe ne ""} {
        set vio $candidate
        set start_probe $candidate_probe
        break
    }
}

if {$start_probe eq ""} {
    foreach candidate $vio_cores {
        foreach probe [get_hw_probes -quiet -of_objects $candidate] {
            if {[lsearch -exact [list_property $probe] OUTPUT_VALUE] >= 0} {
                set vio $candidate
                set start_probe $probe
                break
            }
        }

        if {$start_probe ne ""} {
            break
        }
    }
}

if {$start_probe eq ""} {
    puts "Available VIO probes:"
    foreach candidate $vio_cores {
        foreach probe [get_hw_probes -quiet -of_objects $candidate] {
            puts "  [get_property NAME $probe]"
        }
    }

    fail "Could not identify the VIO start probe."
}

set trigger_probe [find_named_probe $ila {
    "*ecc_done_internal*"
    "*signature_done_internal*"
    "*signature_ready_internal*"
}]

if {$trigger_probe eq ""} {
    puts "Available ILA probes:"
    foreach probe [get_hw_probes -quiet -of_objects $ila] {
        puts "  [get_property NAME $probe]"
    }

    fail "Could not identify an ECC/signature completion trigger."
}

puts "Using device       : [get_property NAME $hw_device]"
puts "Using ILA          : [get_property NAME $ila]"
puts "Using VIO          : [get_property NAME $vio]"
puts "Start probe        : [get_property NAME $start_probe]"
puts "Trigger probe      : [get_property NAME $trigger_probe]"

catch {set_property CONTROL.CAPTURE_MODE BASIC $ila}
catch {set_property CONTROL.TRIGGER_CONDITION AND $ila}
set_property CONTROL.TRIGGER_POSITION 0 $ila
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trigger_probe

# Ensure that START is initially low.
set_property OUTPUT_VALUE 0 $start_probe
commit_hw_vio $start_probe
after 100

for {set capture_index 1} {$capture_index <= $capture_count} {incr capture_index} {
    puts ""
    puts "Capturing signature $capture_index of $capture_count..."

    run_hw_ila $ila
    after 100

    set_property OUTPUT_VALUE 1 $start_probe
    commit_hw_vio $start_probe

    after 5

    set_property OUTPUT_VALUE 0 $start_probe
    commit_hw_vio $start_probe

    if {[catch {
        wait_on_hw_ila -timeout 10000 $ila
    } wait_error]} {
        fail "ILA timeout during capture $capture_index: $wait_error"
    }

    set data_object [upload_hw_ila_data $ila]

    set csv_file [file join $output_dir \
        [format "capture_%03d.csv" $capture_index]]

    file delete -force $csv_file
    write_hw_ila_data -csv_file $csv_file $data_object

    puts "Saved: $csv_file"
}

puts ""
puts "CAPTURE_COMPLETE"

catch {close_hw_target}
catch {disconnect_hw_server}
catch {close_hw_manager}

exit 0
