load_package report
package require cmdline

# Get command line options
set options {{"lrate.arg" "0000000000000000" "Learning Rate"} {"start_img.arg" "0000000000000000" "Start Image Index"} {"filename.arg" "current_accuracies.txt" "Output file"}  {"restore.arg" "True" "Restore Weights"} {"sample_rate.arg" "0000000000000000" "Sample Rate"}}
array set opts [::cmdline::getoptions quartus(args) $options]
set LRATE $opts(lrate)
set START_IMG $opts(start_img)
set FILENAME $opts(filename)
set RESTORE $opts(restore)
set SAMPLE_RATE $opts(restore)
puts "LRATE="
puts $LRATE
puts "START_IMG="
puts $START_IMG


# Memory instance indices.
set RST_IDX 1
set LR_IDX 2
set IMG_IDX 3
set ACC_IDX 5
set W0_IDX 6
set W1_IDX 7
set W2_IDX 8

# Connections
set HARDWARE "DE-SoC \[1-4\]"
set DEVICE "@2: 5CSE(BA5|MA5)/5CSTFD5D5/.. (0x02D120DD)"

# File paths
set WEIGHT_FILE_0 "../hw/mem_files/weights0.mif"
set WEIGHT_FILE_1 "../hw/mem_files/weights1.mif"
set WEIGHT_FILE_2 "../hw/mem_files/weights2.mif"

# Settings
set START_MEM 0
set NUM_ACCS 100


puts [get_hardware_names]
puts [get_device_names -hardware_name $HARDWARE]
begin_memory_edit -hardware_name $HARDWARE -device_name $DEVICE

# Initialize empty file
set fp [open $FILENAME "w"]
close $fp

# Toggle soft reset
set wr_out [write_content_to_memory -instance_index $ACC_IDX -start_address 0 -word_count 200 -content "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" -content_in_hex]
set wr_out [update_content_to_memory_from_file -instance_index $W0_IDX -mem_file_path $WEIGHT_FILE_0 -mem_file_type "mif"]
set wr_out [update_content_to_memory_from_file -instance_index $W1_IDX -mem_file_path $WEIGHT_FILE_1 -mem_file_type "mif"]
set wr_out [update_content_to_memory_from_file -instance_index $W2_IDX -mem_file_path $WEIGHT_FILE_2 -mem_file_type "mif"]

# Lrate is 0, start idx is 0.
set wr_out [write_content_to_memory -instance_index $IMG_IDX -start_address 0 -word_count 1 -content $START_IMG]
set wr_out [write_content_to_memory -instance_index $LR_IDX -start_address 0 -word_count 1 -content $LRATE]
set wr_out [write_content_to_memory -instance_index $RST_IDX -start_address 0 -word_count 8 -content "11111111"]
set wr_out [write_content_to_memory -instance_index $RST_IDX -start_address 0 -word_count 8 -content "00000000"]
set currwait 0

set x 0
while {$x < $NUM_ACCS} {
    after 10 set end 1
    vwait end
    set r [expr $x + $START_MEM]
    set fp [open $FILENAME "a"]
    set curr_acc [read_content_from_memory -instance_index $ACC_IDX -content_in_hex -start_address $r -word_count 1]
    puts $fp $curr_acc
    close $fp
    incr x
    puts $curr_acc
}
end_memory_edit

