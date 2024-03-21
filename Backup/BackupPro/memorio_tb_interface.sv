module top;

    bit clock = '0;
    bit reset = '0;
    bit error_flag = '0;
    wire M0_CS, M1_CS, IO0_CS, IO1_CS;
    reg [7:0] DataIn;
    reg [19:0] AddressIn;

    localparam BASE_ADDR_IO_DEVICE0 = 16'hFF00;
    localparam BASE_ADDR_IO_DEVICE1 = 16'h1C00;
    localparam ADDR_MASK_IO_DEVICE0 = 16'hFFF0;
    localparam ADDR_MASK_IO_DEVICE1 = 16'hFE00;

    Intel8088Pins bus(.CLK(clock), .RESET(reset));

    initial begin
        bus.HOLD = '0;
        bus.READY = '1;
        bus.NMI = '0;
        bus.INTR = '0;
        bus.MNMX = '1;
        bus.TEST = '1;
        bus.ALE = '0;
        bus.RD = '1;
        bus.WR = '1;
        bus.IOM = '0;
    end

    MemoryOrIOModule #(.ADDR_WIDTH(19), .INIT_FILE("memory0_init.mem")) M0 (bus.Peripheral, M0_CS); // Lower 512 KiB (0x00000 - 0x7FFFF)
    MemoryOrIOModule #(.ADDR_WIDTH(19), .INIT_FILE("memory1_init.mem")) M1 (bus.Peripheral, M1_CS); // Upper 512 KiB (0x80000 - 0xFFFFF)
    MemoryOrIOModule #(.ADDR_WIDTH(16), .INIT_FILE("io_device0_init.mem")) IO0 (bus.Peripheral, IO0_CS); // 16 Ports (0xFF00 - 0xFF0F)
    MemoryOrIOModule #(.ADDR_WIDTH(16), .INIT_FILE("io_device1_init.mem")) IO1 (bus.Peripheral, IO1_CS); // 512 Ports (0x1C00 - 0x1DFF)

    // 8282 Latch to latch bus address
    always_latch begin
        if (bus.ALE)
            bus.Address <= AddressIn;
    end

    // Tristate buffer for bidirectional Data bus
    assign bus.Data = bus.WR ? 'z : DataIn;

    // Chip select logic for memory modules
    assign M0_CS = ~bus.IOM & ~bus.Address[19];
    assign M1_CS = ~bus.IOM & bus.Address[19];

    // Chip select logic for I/O devices
    assign IO0_CS = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
    assign IO1_CS = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);

    // Clock generation
    always #50 clock = ~clock;

    // Test sequence
    initial begin
        // Initialize signals
        DataIn = '0;

        // Reset sequence
        repeat (2) @(posedge clock);
        reset = '1;
        repeat (5) @(posedge clock);
        reset = '0;

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
        bus.IOM = '1; // Set I/O control signal
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
            @(negedge clock);
            bus.ALE = '1; // Latch address
            AddressIn = addr;
            @(posedge clock);
            bus.ALE = '0;
            @(negedge clock);
            DataIn = data;
            bus.WR = '0; // Start write operation
            repeat (3) @(posedge clock);
            bus.WR = '1; // End write operation
        end
    endtask

    // Task for performing read operation and checking data
    task ReadOperation(input [19:0] addr, input [7:0] expected_data);
        reg [7:0] read_data;
        begin
            @(negedge clock);
            bus.ALE = '1; // Latch address
            AddressIn = addr;
            @(posedge clock);
            bus.ALE = '0;
            bus.RD = '0; // Start read operation
            repeat (2) @(posedge clock);
            read_data = bus.Data; // Capture data from the bus
            bus.RD = '1; // End read operation
            @(posedge clock);

            // Check if the read data matches expected data
            if(read_data !== expected_data) begin
                $display("Error: Read data %h does not match expected data %h at address %h", read_data, expected_data, addr);
                error_flag = '1;
            end
        end
    endtask
endmodule
