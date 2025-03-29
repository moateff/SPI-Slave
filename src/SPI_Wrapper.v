`timescale 1ns / 1ps

module SPI_Wrapper #(
    parameter MEM_DEPTH = 256,
    parameter ADDR_SIZE = 8,
    parameter FRAME_WIDTH = 8
) (
    input wire clk, 
    input wire rst_n, 
        
    input  wire SS_n,
    input  wire MOSI,
    output wire MISO
);
    
    wire rx_valid;
    wire [FRAME_WIDTH + 1:0] rx_data;
    
    wire tx_valid;
    wire [FRAME_WIDTH - 1:0] tx_data;
    
    SPI_Slave #(
        .FRAME_WIDTH(FRAME_WIDTH)
    ) spi_slave_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .SS_n(SS_n),
        .MOSI(MOSI),
        .MISO(MISO)
    );
    
    RAM #(
        .MEM_DEPTH(MEM_DEPTH),
        .ADDR_SIZE(ADDR_SIZE),
        .WORD_SIZE(FRAME_WIDTH)
    ) ram_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .rx_valid(rx_valid),
        .din(rx_data),
        .tx_valid(tx_valid),
        .dout(tx_data)        
    );
    
endmodule
