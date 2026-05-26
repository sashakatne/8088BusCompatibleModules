module top;

    // Instantiate the interface with the CLK and RESET signals
    bit clock = '0;
    bit reset = '0;
    logic [19:0] Address;
    wire [7:0]  Data;

    Intel8088Pins bus(.CLK(clock), .RESET(reset));

    // Drive the input pins of the interface
    initial begin
        bus.HOLD = '0;
        bus.READY = '1;
        bus.NMI = '0;
        bus.INTR = '0;
        bus.MNMX = '1;
        bus.TEST = '1;
    end

    Intel8088 P(bus.Processor);

    // 8282 Latch to latch bus address
    always_latch begin
        if (bus.ALE)
            Address <= {bus.A, bus.AD};
    end

    // 8286 transceiver
    assign Data = (bus.DTR & ~bus.DEN) ? bus.AD : 'z;
    assign bus.AD = (~bus.DTR & ~bus.DEN) ? Data : 'z;

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
