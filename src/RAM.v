`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2025 05:30:41 PM
// Design Name: 
// Module Name: RAM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RAM #(
    parameter MEM_DEPTH = 256,
    parameter ADDR_SIZE = 8,
    parameter WORD_SIZE = 8
) (
    input wire clk, 
    input wire rst_n, 
    
    input wire rx_valid, 
    input wire [WORD_SIZE + 1:0] din, 
    
    output reg tx_valid,      
    output reg [WORD_SIZE - 1:0] dout           
);

    reg [WORD_SIZE - 1:0] mem [0:MEM_DEPTH - 1];

    reg [ADDR_SIZE - 1:0] addr;

    always @(posedge clk) begin
        if (~rst_n) begin
            tx_valid <= 1'b0;
            dout <= {WORD_SIZE{1'b0}};            
            addr <= {ADDR_SIZE{1'b0}};
        end else begin
            if (rx_valid) begin
                case (din[WORD_SIZE + 1:WORD_SIZE])
                    2'b00: begin
                        tx_valid <= 1'b0;
                        addr <= din[WORD_SIZE-1:0];
                    end
                    2'b01: begin
                        tx_valid <= 1'b0;
                        mem[addr] <= din[WORD_SIZE - 1:0];
                    end
                    2'b10: begin
                        tx_valid <= 1'b0;
                        addr <= din[WORD_SIZE - 1:0];
                    end
                    2'b11: begin
                        tx_valid <= 1'b1;
                        dout <= mem[addr];
                    end
                endcase
            end
        end
    end

endmodule
