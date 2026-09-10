# week6.sdc - Timing Constraints for 50MHz System with UART

# 50MHz clock
create_clock -name clk_50 -period 20.000 [get_ports {clk}]

# UART RX input delay
set_input_delay -clock clk_50 -max 5.000 [get_ports {rx}]
set_input_delay -clock clk_50 -min 1.000 [get_ports {rx}]

# Switch inputs
set_input_delay -clock clk_50 -max 5.000 [get_ports {sw[*]}]
set_input_delay -clock clk_50 -min 1.000 [get_ports {sw[*]}]

# Reset button
set_input_delay -clock clk_50 -max 5.000 [get_ports {reset_n}]
set_input_delay -clock clk_50 -min 1.000 [get_ports {reset_n}]

# UART TX output delay
set_output_delay -clock clk_50 -max 5.000 [get_ports {tx}]
set_output_delay -clock clk_50 -min 1.000 [get_ports {tx}]

# LED outputs
set_output_delay -clock clk_50 -max 5.000 [get_ports {led[*]}]
set_output_delay -clock clk_50 -min 1.000 [get_ports {led[*]}]

# False path on async reset
set_false_path -to [get_ports {reset_n}]