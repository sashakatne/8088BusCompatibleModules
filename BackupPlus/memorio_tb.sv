module top;

    // Clock and reset
    bit CLK = '0;
    bit RESET = '0; 
    bit ALE = '0;
    bit RD = '1;
    bit WR = '1;
    bit IOM = '0;
    bit error_flag = '0;

    reg [19:0] Address;

    reg [7:0] DataIn;
    wire logic [7:0] Data;

    // Chip selects
    wire M0_CS, M1_CS, IO0_CS, IO1_CS;


    // Define address width for memory and I/O devices
    localparam IO_ADDR_WIDTH = 16;
    localparam BASE_ADDR_IO_DEVICE0 = 16'hFF00;
    localparam BASE_ADDR_IO_DEVICE1 = 16'h1C00;
    localparam ADDR_MASK_IO_DEVICE0 = 16'hFFF0; // Mask for ignoring lower 4 bits (0xF)
    localparam ADDR_MASK_IO_DEVICE1 = 16'hFE00; // Mask for ignoring lower 9 bits (0x1FF)

    // Chip select logic for memory modules
    assign M0_CS = ~IOM & ~Address[19];
    assign M1_CS = ~IOM & Address[19];

    // Chip select logic for I/O devices
    assign IO0_CS = IOM & ((Address & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
    assign IO1_CS = IOM & ((Address & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);

    // Memory Modules
    MemoryOrIOModule #(.INIT_FILE("memory0_init.mem")) M0 (CLK, RESET, ALE, RD, WR, M0_CS, Address[18:0], Data); // Lower 512 KiB (0x00000 - 0x7FFFF)
    MemoryOrIOModule #(.INIT_FILE("memory1_init.mem")) M1 (CLK, RESET, ALE, RD, WR, M1_CS, Address[18:0], Data); // Upper 512 KiB (0x80000 - 0xFFFFF)

    // I/O Devices
    MemoryOrIOModule #(.ADDR_WIDTH(IO_ADDR_WIDTH), .INIT_FILE("io_device0_init.mem")) IO0 (CLK, RESET, ALE, RD, WR, IO0_CS, Address[15:0], Data); // 16 Ports (0xFF00 - 0xFF0F)
    MemoryOrIOModule #(.ADDR_WIDTH(IO_ADDR_WIDTH), .INIT_FILE("io_device1_init.mem")) IO1 (CLK, RESET, ALE, RD, WR, IO1_CS, Address[15:0], Data); // 512 Ports (0x1C00 - 0x1DFF)

    // Tristate buffer for bidirectional Data bus
    assign Data = WR ? 'z : DataIn;

    // Clock generation
    always #50 CLK = ~CLK; // 50 MHz clock

    // Test sequence
    initial begin
        // Initialize signals
        DataIn = '0;
        Address = '0;

        // 8088 has a very specific reset sequence
        repeat (2) @(posedge CLK);
        RESET = '1;
        repeat (5) @(posedge CLK);
        RESET = '0;

        // Start test sequence
        // Write to memory0
        // Perform 1024 writes and reads to memory0 from a subset of 0x00000 to 0x7FFFF
        for (int i = 0; i < 1024; i++) begin
            WriteOperation(20'h0F000 + i, 8'h00 + i); // Write 0x00 + i to memory0
        end
        for (int i = 0; i < 1024; i++) begin
            ReadOperation(20'h0F000 + i, 8'h00 + i);  // Read from memory0 and check for 0x00 + i
        end
        // Write to memory1
        // Perform 1024 writes to memory1 from a subset of 0x80000 to 0xFFFFF
        for (int i = 0; i < 1024; i++) begin
            WriteOperation(20'h80000 + i, 8'h00 + i); // Write 0x00 + i to memory1
        end
        // Perform 1024 reads from memory1
        for (int i = 0; i < 1024; i++) begin
            ReadOperation(20'h80000 + i, 8'h00 + i);  // Read from memory1 and check for 0x00 + i
        end

        // Write to IO device0
        IOM = '1; // Set I/O control signal
        // Perform successive writes and reads from IO device0 from 0xFF00 to 0xFF0F (all 16 ports)
        for (int i = 0; i < 16; i++) begin
            WriteOperation(20'h0FF00 + i, 8'h0F + i); // Write 0x0F + i to I/O device 0
        end
        for (int i = 0; i < 16; i++) begin
            ReadOperation(20'h0FF00 + i, 8'h0F + i);  // Read from I/O device 0 and check for 0x0F + i
        end
        // Perform exhaustive writes and reads from IO device1 from 0x1C00 to 0x1DFF (all 512 ports)
        for (int i = 0; i < 512; i++) begin
            WriteOperation(20'h01C00 + i, 8'h0F + i); // Write 0x0F + i to I/O device 1
        end
        for (int i = 0; i < 512; i++) begin
            ReadOperation(20'h01C00 + i, 8'h0F + i);  // Read from I/O device 1 and check for 0x0F + i
        end

        // Finish test sequence
        if (error_flag) $display("*** FAILED ***");
        else $display("*** PASSED ***");
        $finish;
    end

    // Task for performing write operation
    task WriteOperation(input [19:0] addr, input [7:0] data);
        begin
            @(negedge CLK);
            ALE = '1; // Latch address
            Address = addr;
            @(posedge CLK);
            ALE = '0;
            @(negedge CLK);
            DataIn = data;
            WR = '0; // Start write operation
            repeat (3) @(posedge CLK);
            WR = '1; // End write operation
        end
    endtask

    // Task for performing read operation and checking data
    task ReadOperation(input [19:0] addr, input [7:0] expected_data);
        reg [7:0] read_data;
        begin
            @(negedge CLK);
            ALE = '1; // Latch address
            Address = addr;
            @(posedge CLK);
            ALE = '0;
            RD = '0; // Start read operation
            repeat (2) @(posedge CLK);
            read_data = Data; // Capture data from the bus
            RD = '1; // End read operation
            @(posedge CLK);

            // Check if the read data matches expected data
            if(read_data !== expected_data) begin
                $display("Error: Read data %h does not match expected data %h at address %h", read_data, expected_data, addr);
                error_flag = '1;
            end
        end
    endtask

endmodule
