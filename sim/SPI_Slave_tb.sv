`timescale 1ns / 1ps

module SPI_Slave_tb;
    integer TEST_CASES  = 250;
    integer pass_count  = 0;
    integer error_count = 0;
    
    parameter CLK_PERIOD = 10;
    
    parameter MEM_DEPTH   = 256;
    parameter ADDR_SIZE   = 8;
    parameter FRAME_WIDTH = 8;
    
    localparam CTRL_WIDTH  = 3; 
    localparam TX_FRAME_WIDTH = FRAME_WIDTH;
    localparam RX_FRAME_WIDTH = FRAME_WIDTH + CTRL_WIDTH;
           
    logic clk; 
    logic rst_n; 
        
    logic SS_n;
    logic MOSI;
    logic MISO;
    
    logic [FRAME_WIDTH - 1:0] master_tx_addr;
    logic [FRAME_WIDTH - 1:0] master_tx_data;
    logic [FRAME_WIDTH - 1:0] master_rx_addr;
    logic [FRAME_WIDTH - 1:0] master_rx_data;
    
    SPI_Wrapper #(
        .MEM_DEPTH(MEM_DEPTH),
        .ADDR_SIZE(ADDR_SIZE),
        .FRAME_WIDTH(FRAME_WIDTH)
    ) DUT (
        .clk(clk), 
        .rst_n(rst_n), 
       
        .SS_n(SS_n),
        .MOSI(MOSI),
        .MISO(MISO)
    );
        
    always #(CLK_PERIOD/2) clk = ~clk;
    
    task parallel_to_serial;
        input [RX_FRAME_WIDTH - 1:0] bus_data;
        begin
            $display("Starting Parallel-to-Serial Conversion. Input Data: %b", bus_data);
            @(negedge clk); 
            for (int i = 0; i < RX_FRAME_WIDTH; i++) begin
                MOSI = bus_data[RX_FRAME_WIDTH - 1 - i]; // Sending MSB first
                $display("Bit %0d/%0d -> MOSI: %b", i + 1, RX_FRAME_WIDTH, MOSI);
                @(negedge clk);
            end
            $display("Parallel-to-Serial Conversion Completed.");
        end
    endtask

    
    task serial_to_parallel;
        output [TX_FRAME_WIDTH - 1:0] bus_data;
        begin
            bus_data = 0;
            $display("Starting Serial-to-Parallel Conversion...");
            @(negedge clk); 
            for (int i = 0; i < TX_FRAME_WIDTH; i++) begin
                @(negedge clk);
                bus_data[TX_FRAME_WIDTH - 1 - i] = MISO; // Storing MSB first
                $display("Bit %0d/%0d Received -> MISO: %b", i + 1, TX_FRAME_WIDTH, MISO);
            end
            $display("Serial-to-Parallel Conversion Completed. Output Data: %b", bus_data);
        end
    endtask

            
    task wait_cycles;
        input integer num_cycles;
        begin
            repeat(num_cycles) @(negedge clk);
        end
    endtask
    
    task assert_reset;
        begin
            @(negedge clk);
            rst_n = 0;
            wait_cycles(1);
            rst_n = 1;
        end
    endtask
    
    task assert_slave_select;
        begin
            SS_n = 0;
        end
    endtask
    
    task deassert_slave_select;
        begin
            SS_n = 1;
        end
    endtask
    
    task master_tx;
        input [CTRL_WIDTH  - 1:0] ctrl_bits;
        input [FRAME_WIDTH - 1:0] tx_data;
        begin
            $display("Master TX Started. Control Bits: %b, Data: %b", ctrl_bits, tx_data);
            assert_slave_select;
            $display("Slave Select Asserted.");
            parallel_to_serial({ctrl_bits, tx_data});
            deassert_slave_select;
            $display("Slave Select Deasserted. Master TX Completed.");
        end
    endtask

    
    task master_rx;
        output [FRAME_WIDTH - 1:0] rx_data;
        begin
            $display("Master RX Started.");
            assert_slave_select;
            $display("Slave Select Asserted. Receiving Data...");
            serial_to_parallel(rx_data);
            deassert_slave_select;
            $display("Slave Select Deasserted. Master RX Completed. Received Data: %b", rx_data);
        end
    endtask
    
    task master;
        input  string operation;
        input  [FRAME_WIDTH - 1:0] tx_data;
        output [FRAME_WIDTH - 1:0] rx_data;
        bit    [CTRL_WIDTH - 1:0] ctrl_bits;

        begin    
            case (operation)
                "write_addr": begin
                    $display("Master Operation: Transmitting Write Address");
                    ctrl_bits = 3'b000;
                    master_tx(ctrl_bits, tx_data);
                end
                "write_data": begin
                    $display("Master Operation: Transmitting Write Data");
                    ctrl_bits = 3'b001;
                    master_tx(ctrl_bits, tx_data);
                end
                "read_addr": begin
                    $display("Master Operation: Transmitting Read Address");
                    ctrl_bits = 3'b110;
                    master_tx(ctrl_bits, tx_data);
                end
                "read_data": begin
                    $display("Master Operation: Receiving Read DATA");
                    $display("Initiating Read Data Request");
                    ctrl_bits = 3'b111;
                    master_tx(ctrl_bits, tx_data);  // Garbage value sent
                    master_rx(rx_data);
                    $display("Received Data: %b", rx_data);
                end
                default: begin
                    $display("ERROR: Invalid operation '%s'", operation);
                    return;
                end
            endcase
            $display("");
            wait_cycles(1);
        end
    endtask
    
    /// Task to check data consistency and update counts
    task check_data;
        input [FRAME_WIDTH - 1:0] recieved_data;
        input [FRAME_WIDTH - 1:0] addr;  // Address to check in DUT memory
    
        begin
            // Read the expected value directly from the DUT RAM at the given address
            logic [FRAME_WIDTH - 1:0] expected_data;
            expected_data = DUT.ram_inst.mem[addr];
    
            if (expected_data === recieved_data) begin
                $display("[Data Match: Addr = %d, Expected = %d, Received = %d", 
                          addr, expected_data, recieved_data);
                pass_count++;
            end else begin
                $display("DATA MISMATCH! Addr = %d, Expected = %d, Received = %d", 
                          addr, expected_data, recieved_data);
                error_count++;
            end
        end
    endtask

    // Test execution
    initial begin
        initialize_spi_slave;
        $display("\nSPI Slave Initialized");
        
        assert_reset;
        $display("Reset Asserted\n");
        
        wait_cycles(1);
        
        for (int i = 1; i <= TEST_CASES; i++) begin
            $display("\n-----------------------------------------------------------------------\n");
            // Generate random values for transactions
            master_tx_addr = $random;
            master_tx_data = $random;
            
            // Perform SPI transactions
            master("write_addr", master_tx_addr, master_rx_data);
            master("write_data", master_tx_data, master_rx_data);  
        end
    
        for (int i = 1; i <= TEST_CASES; i++) begin
            $display("\n-------------------------- Test Case %0d --------------------------\n", i);
    
            // Generate random values for transactions
            master_tx_addr = $random;
            master_tx_data = $random;
            master_rx_addr = $random; 
    
            // Perform SPI transactions
            master("write_addr", master_tx_addr, master_rx_data);
            master("write_data", master_tx_data, master_rx_data);        
            master("read_addr", master_rx_addr, master_rx_data);
            master("read_data", $random, master_rx_data);  // Garbage value for read data request
    
            // Check if received data matches written data
            check_data(master_rx_data, master_rx_addr);
        end
       
        wait_cycles(1);
        $display("\n-----------------------------------------------------------------------\n");
        $display("Simulation Completed: %0d test cases excuted.", TEST_CASES);
        $display("Test Summary:Passed: %0d, Failed: %0d", pass_count, error_count);
           
        $stop;
    end
    
    task initialize_spi_slave;
        begin 
            clk   = 0;
            rst_n = 1;
            SS_n  = 1;
            MOSI  = 0;
        end
    endtask
        
endmodule
