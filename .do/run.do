vlog SPI_Wrapper.v SPI_Slave.sv RAM.v SPI_Slave_tb.sv
vsim -voptargs=+acc work.SPI_Slave_tb
add wave *
run -all
# quit -sim