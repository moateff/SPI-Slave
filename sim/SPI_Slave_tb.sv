`timescale 1ns / 1ps

module SPI_Slave_tb;
    int TEST_CASES  = 10;
    int pass_count  = 0;
    int error_count = 0;
    
    parameter VERBOSITY = "MEDIUM"; // "MEDIUM" or "DEBUG" or "NONE"
    
    parameter CLK_PERIOD = 10;
    
    parameter MEM_DEPTH   = 256;
    parameter ADDR_SIZE   = 8;
    parameter FRAME_WIDTH = 8;
    
    localparam CTRL_WIDTH  = 3; 
    localparam RX_FRAME_WIDTH = FRAME_WIDTH;
    localparam TX_FRAME_WIDTH = FRAME_WIDTH + CTRL_WIDTH;
           
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
    
    task wait_cycles;
        input integer num_cycles;
        begin
            repeat(num_cycles) @(negedge clk);
        end
    endtask
        
    task parallel_to_serial;
        input [TX_FRAME_WIDTH - 1:0] bus_data;
        begin
            msg($sformatf("Starting Parallel-to-Serial Conversion. Input Data: %b", bus_data), "DEBUG");
            for (int i = 0; i < TX_FRAME_WIDTH; i++) begin
                MOSI = bus_data[TX_FRAME_WIDTH - 1 - i]; // Sending MSB first
                msg($sformatf("Bit %0d/%0d -> MOSI: %b", i + 1, TX_FRAME_WIDTH, MOSI), "DEBUG");
                wait_cycles(1);
            end
            msg("Parallel-to-Serial Conversion Completed.", "DEBUG");
        end
    endtask

    
    task serial_to_parallel;
        output [RX_FRAME_WIDTH - 1:0] bus_data;
        begin
            bus_data = 0;
            msg("Starting Serial-to-Parallel Conversion...", "DEBUG");
            for (int i = 0; i < RX_FRAME_WIDTH; i++) begin
                bus_data[RX_FRAME_WIDTH - 1 - i] = MISO; // Storing MSB first
                msg($sformatf("Bit %0d/%0d Received -> MISO: %b", i + 1, RX_FRAME_WIDTH, MISO), "DEBUG");
                wait_cycles(1);
            end
            msg($sformatf("Serial-to-Parallel Conversion Completed. Output Data: %b", bus_data), "DEBUG");
        end
    endtask
    
    task assert_reset;
        begin
            wait_cycles(1);
            rst_n = 0;
            wait_cycles(1);
            rst_n = 1;
        end
    endtask
    
    task assert_slave_select;
        begin
            SS_n = 0;
            wait_cycles(1);
        end
    endtask
    
    task deassert_slave_select;
        begin
            SS_n = 1;
            wait_cycles(1);
        end
    endtask
    
    task master_tx;
        input [CTRL_WIDTH  - 1:0] ctrl_bits;
        input [FRAME_WIDTH - 1:0] tx_data;
        begin
            msg($sformatf("Master TX Started. Control Bits: %b, Transmitted Data: %b", ctrl_bits, tx_data), "MEDIUM");
            assert_slave_select;
            msg("Slave Select Asserted.", "DEBUG");
            parallel_to_serial({ctrl_bits, tx_data});
            deassert_slave_select;
            msg("Slave Select Deasserted.", "DEBUG");
            msg("Master TX Completed.\n", "MEDIUM");
        end
    endtask

    task master_rx;
        input [CTRL_WIDTH  - 1:0] ctrl_bits;
        input [FRAME_WIDTH - 1:0] tx_data;
        output [FRAME_WIDTH - 1:0] rx_data;
        begin
            msg($sformatf("Master RX Started. Control Bits: %b", ctrl_bits), "MEDIUM");
            assert_slave_select;
            msg("Slave Select Asserted.", "DEBUG");
            msg($sformatf("Initiating Read Data Request. Control Bits: %b, Data: %b", ctrl_bits, tx_data), "DEBUG");
            parallel_to_serial({ctrl_bits, tx_data});
            wait_cycles(2);
            msg("Receiving Data...", "DEBUG");
            serial_to_parallel(rx_data);
            deassert_slave_select;
            msg("Slave Select Deasserted.", "DEBUG");
            msg($sformatf("Master RX Completed. Received Data: %d\n", rx_data), "MEDIUM");
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
                    msg($sformatf("Master Operation: Transmitting Write Address: %d", tx_data), "MEDIUM");
                    ctrl_bits = 3'b000;
                    master_tx(ctrl_bits, tx_data);
                end
                "write_data": begin
                    msg($sformatf("Master Operation: Transmitting Write Data: %d", tx_data), "MEDIUM");
                    ctrl_bits = 3'b001;
                    master_tx(ctrl_bits, tx_data);
                end
                "read_addr": begin
                    msg($sformatf("Master Operation: Transmitting Read Address: %d", tx_data), "MEDIUM");
                    ctrl_bits = 3'b110;
                    master_tx(ctrl_bits, tx_data);
                end
                "read_data": begin
                    msg("Master Operation: Receiving Read data", "MEDIUM");
                    ctrl_bits = 3'b111;
                    master_rx(ctrl_bits, tx_data, rx_data); // tx_data: Garbage value sent
                end
                default: begin
                    msg($sformatf("[ERROR] Invalid operation '%s'", operation), "NONE");
                    return;
                end
            endcase
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
                msg($sformatf("[MATCH] Addr = %d, Expected = %d, Received = %d", 
                          addr, expected_data, recieved_data), "NONE");
                pass_count++;
            end else begin
                msg($sformatf("[MISMATCH] Addr = %d, Expected = %d, Received = %d", 
                          addr, expected_data, recieved_data), "NONE");
                error_count++;
            end
        end
    endtask

    // Test execution
    initial begin
        initialize_spi_slave;
        msg("SPI Slave Initialized", "MEDIUM");
        
        assert_reset;
        msg("Reset Asserted", "MEDIUM");
        
        wait_cycles(1);
    
        for (int i = 1; i <= TEST_CASES; i++) begin
            msg($sformatf("\n-------------------------- Test Case %0d --------------------------\n", i), "NONE");
    
            // Generate random values for transactions
            master_tx_addr = $random;
            master_tx_data = $random;
            master_rx_addr = master_tx_addr; 
    
            // Perform SPI transactions
            master("write_addr", master_tx_addr, master_rx_data);
            master("write_data", master_tx_data, master_rx_data);        
            master("read_addr", master_rx_addr, master_rx_data);
            master("read_data", {TX_FRAME_WIDTH{1'bx}}, master_rx_data);  // Garbage value for read data request
    
            // Check if received data matches written data
            check_data(master_rx_data, master_rx_addr);
        end
       
        wait_cycles(1);
        msg("\n-----------------------------------------------------------------\n", "NONE");
        msg($sformatf("Simulation Completed: %0d test cases excuted.", TEST_CASES), "NONE");
        msg($sformatf("Test Summary: Passed: %0d, Failed: %0d", pass_count, error_count), "NONE");
           
        $stop;
    end
    
    task initialize_spi_slave;
        begin 
            // Initialize SPI signals
            clk   = 0;   // Start clock as low
            rst_n = 1;   // Deassert reset
            SS_n  = 1;   // Slave Select inactive (high)
            MOSI  = 0;   // Ensure MOSI starts at 0
    
            // Load RAM with predefined values from an external file
            $readmemh("random_data.mem", DUT.ram_inst.mem);  
        end
    endtask

    function void msg(input string msg, input string msg_verbosity);
        if (VERBOSITY == "DEBUG") begin
            if (msg_verbosity == "DEBUG" | msg_verbosity == "MEDIUM" | msg_verbosity == "NONE") begin
                $display("%s", msg);
                // $display("        Time: %0t", $time);
            end
        end else if (VERBOSITY == "MEDIUM") begin
            if (msg_verbosity == "MEDIUM" | msg_verbosity == "NONE") begin
                $display("%s", msg);
                // $display("         Time: %0t", $time);
            end
        end else if (VERBOSITY == "NONE") begin
            if (msg_verbosity == "NONE") begin
                $display("%s", msg);
                // $display("       Time: %0t", $time);
            end
        end else begin
            $display("[UNKNOWN VERBOSITY \"%s\"]", VERBOSITY);
        end
    endfunction

endmodule
