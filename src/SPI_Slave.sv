`timescale 1ns / 1ps

module SPI_Slave #(
    parameter  FRAME_WIDTH = 8,
    localparam CTRL_WIDTH  = 2,
    localparam TX_FRAME_WIDTH = FRAME_WIDTH,
    localparam RX_FRAME_WIDTH = FRAME_WIDTH + CTRL_WIDTH
) (
    input wire clk, 
    input wire rst_n, 
    
    output reg rx_valid,
    output reg [RX_FRAME_WIDTH - 1:0] rx_data,
            
    input wire tx_valid,
    input wire [TX_FRAME_WIDTH - 1:0] tx_data,

    input wire SS_n,
    input wire MOSI,
    output reg MISO
);
    localparam COUNT_WIDTH = $clog2(RX_FRAME_WIDTH);
    reg [COUNT_WIDTH - 1:0] counter;
    
    reg read_addr;
    
    (* fsm_encoding = "gray" *)
    typedef enum logic [2:0] {IDLE, CHK_CMD, WRITE, READ_ADD, READ_DATA} state_t;
    
    state_t state_nxt, state_crnt;
    
    always_ff @(posedge clk)
    begin
        if (~rst_n) begin
            state_crnt <= IDLE;
        end else begin
            state_crnt <= state_nxt;
        end
    end
    
    always_comb
    begin
        case(state_crnt)
            IDLE:
            begin
                if (SS_n) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = CHK_CMD;
                end
            end
            CHK_CMD:
            begin
                if (SS_n) begin
                    state_nxt = IDLE;
                end else begin
                    if (~MOSI) begin
                        state_nxt = WRITE;
                    end else begin
                        if (read_addr) begin
                            state_nxt = READ_DATA;
                        end else begin
                            state_nxt = READ_ADD;
                        end
                    end
                end
            end
            WRITE:
            begin
                if (SS_n) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = WRITE;
                end
            end
            READ_ADD:
            begin
                if (SS_n) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = READ_ADD;
                end
            end
            READ_DATA:
            begin
                if (SS_n) begin
                    state_nxt = IDLE;
                end else begin
                    state_nxt = READ_DATA;
                end
            end
            default:
            begin 
                state_nxt = IDLE;
            end
        endcase
    end
    
    always_ff @(posedge clk)
    begin
        if(~rst_n)begin
            counter   <= {COUNT_WIDTH{1'b0}};
            read_addr <= 1'b0;
            rx_valid  <= 1'b0;
            rx_data   <= {RX_FRAME_WIDTH{1'b0}};
            MISO      <= 1'b0;
        end else begin
            case(state_crnt)
            IDLE:
            begin
                counter  <= {COUNT_WIDTH{1'b0}};
                rx_valid <= 1'b0;
                rx_data  <= {RX_FRAME_WIDTH{1'b0}};
                MISO     <= 1'b0;
            end
            WRITE:
            begin
                if (~rx_valid) begin
                    rx_data <= {rx_data[RX_FRAME_WIDTH - 2:0], MOSI};
                    if (counter == RX_FRAME_WIDTH - 1) begin
                        rx_valid  <= 1'b1;
                        read_addr <= 1'b0;
                        counter   <= {COUNT_WIDTH{1'b0}};
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end
            READ_ADD:
            begin
                if (~rx_valid) begin
                    rx_data <= {rx_data[RX_FRAME_WIDTH - 2:0], MOSI};
                    if (counter == RX_FRAME_WIDTH - 1) begin
                        rx_valid  <= 1'b1;
                        read_addr <= 1'b1;
                        counter   <= {COUNT_WIDTH{1'b0}};
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end
            READ_DATA:
            begin
                if (~tx_valid) begin
                    if (~rx_valid) begin
                        rx_data <= {rx_data[RX_FRAME_WIDTH - 2:0], MOSI};
                        if (counter == RX_FRAME_WIDTH - 1) begin
                            rx_valid <= 1'b1;
                            counter  <= {COUNT_WIDTH{1'b0}};
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end else begin
                    if (read_addr) begin
                        MISO <= tx_data[TX_FRAME_WIDTH - 1 - counter];
                        if (counter == TX_FRAME_WIDTH - 1) begin 
                            read_addr <= 1'b0;
                            counter   <= {COUNT_WIDTH{1'b0}};
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end
            end
            endcase
        end
    end
        
endmodule
