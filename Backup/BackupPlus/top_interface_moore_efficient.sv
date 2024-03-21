module top;

    bit clock = '0;
    bit reset = '0;

    localparam BASE_ADDR_IO_DEVICE0 = 16'hFF00;
    localparam BASE_ADDR_IO_DEVICE1 = 16'h1C00;
    localparam ADDR_MASK_IO_DEVICE0 = 16'hFFF0;
    localparam ADDR_MASK_IO_DEVICE1 = 16'hFE00;
    localparam NUM_UNITS_IO_DEVICE0 = 16;
    localparam NUM_UNITS_IO_DEVICE1 = 512;

    Intel8088Pins bus(.CLK(clock), .RESET(reset));

    initial begin
        bus.HOLD = '0;
        bus.READY = '1;
        bus.NMI = '0;
        bus.INTR = '0;
        bus.MNMX = '1;
        bus.TEST = '1;
    end

    Intel8088 P(bus.Processor);
    MemoryOrIOModule #(.DEVICE_INDEX(0), .ADDR_WIDTH(19), .INIT_FILE("memory0_init.mem")) M0 (bus.Peripheral); // Lower 512 KiB (0x00000 - 0x7FFFF)
    MemoryOrIOModule #(.DEVICE_INDEX(1), .ADDR_WIDTH(19), .INIT_FILE("memory1_init.mem")) M1 (bus.Peripheral); // Upper 512 KiB (0x80000 - 0xFFFFF)
    MemoryOrIOModule #(.DEVICE_INDEX(2), .ADDR_WIDTH(16), .BASE_ADDR(BASE_ADDR_IO_DEVICE0), .NUM_UNITS(NUM_UNITS_IO_DEVICE0), .INIT_FILE("io_device0_init.mem")) IO0 (bus.Peripheral); // 16 Ports (0xFF00 - 0xFF0F)
    MemoryOrIOModule #(.DEVICE_INDEX(3), .ADDR_WIDTH(16), .BASE_ADDR(BASE_ADDR_IO_DEVICE1), .NUM_UNITS(NUM_UNITS_IO_DEVICE1), .INIT_FILE("io_device1_init.mem")) IO1 (bus.Peripheral); // 512 Ports (0x1C00 - 0x1DFF)

    // 8282 Latch to latch bus address
    always_latch begin
        if (bus.ALE)
            bus.Address <= {bus.A, bus.AD};
    end

    // 8286 transceiver
    assign bus.Data = (bus.DTR & ~bus.DEN) ? bus.AD : 'z;
    assign bus.AD = (~bus.DTR & ~bus.DEN) ? bus.Data : 'z;

    // Chip select logic for memory modules
    assign bus.CS[0] = ~bus.IOM & ~bus.Address[19];
    assign bus.CS[1] = ~bus.IOM & bus.Address[19];

    // Chip select logic for I/O devices
    assign bus.CS[2] = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
    assign bus.CS[3] = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);

    // Clock generation
    always #50 clock = ~clock;

    // Simulation control
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        // Reset sequence
        repeat (2) @(posedge clock);
        reset = '1;
        repeat (5) @(posedge clock);
        reset = '0;

        // Run the simulation for a specified number of clock cycles
        repeat (300) @(posedge clock);
        $finish();
    end

endmodule
