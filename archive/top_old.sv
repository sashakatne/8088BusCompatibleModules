module top;

bit CLK = '0;
bit MNMX = '1;
bit TEST = '1;
bit RESET = '0;
bit READY = '1;
bit NMI = '0;
bit INTR = '0;
bit HOLD = '0;

wire logic [7:0] AD;
logic [19:8] A;
logic HLDA;
logic IOM;
logic WR;
logic RD;
logic SSO;
logic INTA;
logic ALE;
logic DTR;
logic DEN;

logic [19:0] Address;
wire logic [7:0]  Data;

logic memory0_cs;
logic memory1_cs;
logic io_device0_cs;
logic io_device1_cs;

// Define the number of addressable units for memory modules
localparam NUM_UNITS_MEMORY = 512 * 1024;

// Define the base addresses and masks for I/O devices
localparam BASE_ADDR_IO_DEVICE0 = 16'hFF00;
localparam BASE_ADDR_IO_DEVICE1 = 16'h1C00;
localparam ADDR_MASK_IO_DEVICE0 = 16'hFFF0; // Mask for ignoring lower 4 bits (0xF)
localparam ADDR_MASK_IO_DEVICE1 = 16'hFE00; // Mask for ignoring lower 9 bits (0x1FF)

// Define the number of addressable units for I/O devices
localparam NUM_UNITS_IO_DEVICE0 = 16;  // 16 ports for I/O device 0 (0xFF00 - 0xFF0F)
localparam NUM_UNITS_IO_DEVICE1 = 257; // 257 ports for I/O device 1 (0x1C00 - 0x1D00)


Intel8088 P(CLK, MNMX, TEST, RESET, READY, NMI, INTR, HOLD, AD, A, HLDA, IOM, WR, RD, SSO, INTA, ALE, DTR, DEN);

// Memory Modules
MemoryOrIOModule #(.NUM_UNITS(NUM_UNITS_MEMORY)) memory0 (CLK, RESET, memory0_cs, RD, WR, {1'b0,Address[18:0]}, Data); // Lower 512 KiB
MemoryOrIOModule #(.NUM_UNITS(NUM_UNITS_MEMORY)) memory1 (CLK, RESET, memory1_cs, RD, WR, {1'b0,Address[18:0]}, Data); // Upper 512 KiB

// I/O Devices
MemoryOrIOModule #(.BASE_ADDR(BASE_ADDR_IO_DEVICE0), .NUM_UNITS(NUM_UNITS_IO_DEVICE0)) io_device0 (CLK, RESET, io_device0_cs, RD, WR, {4'b0,Address[15:0]}, Data); // 16 Ports (0xFF00 - 0xFF0F)
MemoryOrIOModule #(.BASE_ADDR(BASE_ADDR_IO_DEVICE1), .NUM_UNITS(NUM_UNITS_IO_DEVICE1)) io_device1 (CLK, RESET, io_device1_cs, RD, WR, {4'b0,Address[15:0]}, Data); // 257 Ports (0x1C00 - 0x1D00)

// 8282 Latch to latch bus address
always_latch
begin
    if (ALE)
        Address <= {A, AD};
end

// 8286 transceiver
assign Data =  (DTR & ~DEN) ? AD   : 'z;
assign AD   = (~DTR & ~DEN) ? Data : 'z;

always_comb begin
    // CS for memory modules
    memory0_cs = ~IOM && (Address[19] == 0);
    memory1_cs = ~IOM && (Address[19] == 1);

    // CS logic for I/O devices using base address and mask
    io_device0_cs = IOM && ((Address & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
    io_device1_cs = IOM && ((Address & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);
end

always #50 CLK = ~CLK;

initial
begin
    $dumpfile("dump.vcd"); $dumpvars;

    repeat (2) @(posedge CLK);
    RESET = '1;
    repeat (5) @(posedge CLK);
    RESET = '0;

    repeat(10000) @(posedge CLK);
    $finish();
end

endmodule
