# week5.sdc - Timing Constraints for 50MHz System

# Define the 50MHz clock
create_clock -name clk_50 -period 20.000 [get_ports {clk}]

# Set input delay for switches (conservative)
set_input_delay -clock clk_50 -max 5.000 [get_ports {sw[*]}]
set_input_delay -clock clk_50 -min 1.000 [get_ports {sw[*]}]

# Set input delay for reset button
set_input_delay -clock clk_50 -max 5.000 [get_ports {reset_n}]
set_input_delay -clock clk_50 -min 1.000 [get_ports {reset_n}]

# Set output delay for LEDs
set_output_delay -clock clk_50 -max 5.000 [get_ports {led[*]}]
set_output_delay -clock clk_50 -min 1.000 [get_ports {led[*]}]

# False path: reset is asynchronous
set_false_path -to [get_ports {reset_n}]

derive_clock_uncertainty