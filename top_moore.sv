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

logic M0_CS;
logic M1_CS;
logic IO0_CS;
logic IO1_CS;

// Define address width for memory and I/O devices
localparam IO_ADDR_WIDTH = 16;

// Define the base addresses and masks for I/O devices
localparam BASE_ADDR_IO_DEVICE0 = 16'hFF00;
localparam BASE_ADDR_IO_DEVICE1 = 16'h1C00;
localparam ADDR_MASK_IO_DEVICE0 = 16'hFFF0; // Mask for ignoring lower 4 bits (0xF)
localparam ADDR_MASK_IO_DEVICE1 = 16'hFE00; // Mask for ignoring lower 9 bits (0x1FF)

Intel8088 P(CLK, MNMX, TEST, RESET, READY, NMI, INTR, HOLD, AD, A, HLDA, IOM, WR, RD, SSO, INTA, ALE, DTR, DEN);

// Memory Modules
MemoryOrIOModule #(.INIT_FILE("memory0_init.mem")) M0 (CLK, RESET, ALE, M0_CS, RD, WR, Address[18:0], Data); // Lower 512 KiB (0x00000 - 0x7FFFF)
MemoryOrIOModule #(.INIT_FILE("memory1_init.mem")) M1 (CLK, RESET, ALE, M1_CS, RD, WR, Address[18:0], Data); // Upper 512 KiB (0x80000 - 0xFFFFF)

// I/O Devices
MemoryOrIOModule #(.ADDR_WIDTH(IO_ADDR_WIDTH), .INIT_FILE("io_device0_init.mem")) IO0 (CLK, RESET, ALE, IO0_CS, RD, WR, Address[15:0], Data); // 16 Ports (0xFF00 - 0xFF0F)
MemoryOrIOModule #(.ADDR_WIDTH(IO_ADDR_WIDTH), .INIT_FILE("io_device1_init.mem")) IO1 (CLK, RESET, ALE, IO1_CS, RD, WR, Address[15:0], Data); // 512 Ports (0x1C00 - 0x1DFF)

// 8282 Latch to latch bus address
always_latch
begin
    if (ALE)
        Address <= {A, AD};
end

// 8286 transceiver
assign Data =  (DTR & ~DEN) ? AD   : 'z;
assign AD   = (~DTR & ~DEN) ? Data : 'z;

// Chip select logic for memory modules
assign M0_CS = ~IOM & ~Address[19];
assign M1_CS = ~IOM & Address[19];

// Chip select logic for I/O devices
assign IO0_CS = IOM & ((Address & ADDR_MASK_IO_DEVICE0) == BASE_ADDR_IO_DEVICE0);
assign IO1_CS = IOM & ((Address & ADDR_MASK_IO_DEVICE1) == BASE_ADDR_IO_DEVICE1);

always #50 CLK = ~CLK;

initial
begin
    $dumpfile("dump.vcd"); $dumpvars;

    repeat (2) @(posedge CLK);
    RESET = '1;
    repeat (5) @(posedge CLK);
    RESET = '0;

    repeat(1000) @(posedge CLK);
    $finish();
end

endmodule