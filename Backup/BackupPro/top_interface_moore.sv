module top;

    bit clock = '0;
    bit reset = '0;
    wire M0_CS, M1_CS, IO0_CS, IO1_CS;

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
    end

    Intel8088 P(bus.Processor);
    MemoryOrIOModule #(.ADDR_WIDTH(19), .INIT_FILE("memory0_init.mem")) M0 (bus.Peripheral, M0_CS); // Lower 512 KiB (0x00000 - 0x7FFFF)
    MemoryOrIOModule #(.ADDR_WIDTH(19), .INIT_FILE("memory1_init.mem")) M1 (bus.Peripheral, M1_CS); // Upper 512 KiB (0x80000 - 0xFFFFF)
    MemoryOrIOModule #(.ADDR_WIDTH(16), .INIT_FILE("io_device0_init.mem")) IO0 (bus.Peripheral, IO0_CS); // 16 Ports (0xFF00 - 0xFF0F)
    MemoryOrIOModule #(.ADDR_WIDTH(16), .INIT_FILE("io_device1_init.mem")) IO1 (bus.Peripheral, IO1_CS); // 512 Ports (0x1C00 - 0x1DFF)

    // 8282 Latch to latch bus address
    always_latch begin
        if (bus.ALE)
            bus.Address <= {bus.A, bus.AD};
    end

    // 8286 transceiver
    assign bus.Data = (bus.DTR & ~bus.DEN) ? bus.AD : 'z;
    assign bus.AD = (~bus.DTR & ~bus.DEN) ? bus.Data : 'z;

    // Chip select logic for memory modules
    assign M0_CS = ~bus.IOM & ~bus.Address[19];
    assign M1_CS = ~bus.IOM & bus.Address[19];

    // Chip select logic for I/O devices
    assign IO0_CS = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
    assign IO1_CS = bus.IOM & ((bus.Address[15:0] & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);

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
