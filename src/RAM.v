`timescale 1ns / 1ps

module RAM #(
    parameter MEM_DEPTH = 256,
    parameter ADDR_SIZE = 8,
    parameter WORD_SIZE = 8,
    
    parameter CTRL_WIDTH = 2,                         
    parameter DOUT_WIDTH = WORD_SIZE,            
    parameter DIN_WIDTH  = WORD_SIZE + CTRL_WIDTH
) (
    input wire clk, 
    input wire rst_n, 
    
    input wire rx_valid, 
    input wire [DIN_WIDTH - 1:0] din, 
    
    output reg tx_valid,      
    output reg [DOUT_WIDTH - 1:0] dout           
);

    reg [WORD_SIZE - 1:0] mem [0:MEM_DEPTH - 1];

    reg [ADDR_SIZE - 1:0] addr;

    always @(posedge clk) begin
        if (~rst_n) begin
            tx_valid <= 1'b0;
            dout <= {DOUT_WIDTH{1'b0}};            
            addr <= {ADDR_SIZE{1'b0}};
        end else begin
            if (rx_valid) begin
                case (din[DIN_WIDTH - 1:DIN_WIDTH - 2])
                    2'b00: begin
                        tx_valid <= 1'b0;
                        addr <= din[ADDR_SIZE - 1:0];
                        dout <= {DOUT_WIDTH{1'b0}};
                    end
                    2'b01: begin
                        tx_valid <= 1'b0;
                        mem[addr] <= din[WORD_SIZE - 1:0];
                        dout <= {DOUT_WIDTH{1'b0}};
                    end
                    2'b10: begin
                        tx_valid <= 1'b0;
                        addr <= din[ADDR_SIZE - 1:0];
                        dout <= {DOUT_WIDTH{1'b0}};
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
