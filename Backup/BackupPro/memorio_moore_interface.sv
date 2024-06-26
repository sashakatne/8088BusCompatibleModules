module MemoryOrIOModule (Intel8088Pins bus, input wire CS);

    parameter ADDR_WIDTH = 20;
    parameter DATA_WIDTH = 8;
    parameter INIT_FILE = "memory_init.mem";
    wire OE, WE, LA;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .INIT_FILE(INIT_FILE)) datapath (bus.CLK, bus.RESET, bus.Address[ADDR_WIDTH-1:0], bus.Data, LA, OE, WE);
    ControlSequencer controlSequencer (bus.CLK, bus.RESET, bus.ALE, bus.RD, bus.WR, CS, LA, OE, WE);

endmodule

module Datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE);
    
    parameter ADDR_WIDTH = 20;
    parameter DATA_WIDTH = 8;
    parameter INIT_FILE = "memory_init.mem";
    localparam NUM_UNITS = (1 << ADDR_WIDTH);

    input wire CLK;
    input wire RESET;
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;
    input wire LA; // Load Address. From ControlSequencer
    input wire OE; // Output Enable. From ControlSequencer
    input wire WE; // Write Enable. From ControlSequencer
    
    reg [ADDR_WIDTH-1:0] ADDR_REG;
    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];

    // Tristate buffer control for bidirectional Data bus
    assign DATA = OE ? MEM[ADDR_REG] : 'z;

    // Load initial memory contents from file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

    always_ff @(posedge CLK) begin
        if (LA)
            ADDR_REG <= ADDRESS;
        if (WE)
            MEM[ADDR_REG] <= DATA; // Capture the data from the bus
    end

endmodule

module ControlSequencer (CLK, RESET, ALE, RD, WR, CS, LA, OE, WE);

    input wire CLK;
    input wire RESET;
    input wire ALE; // Address Latch Enable. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire CS; // Chip Select. Active high
    output reg LA; // Load Address. To Datapath
    output reg OE; // Output Enable. To Datapath
    output reg WE; // Write Enable. To Datapath

    typedef enum logic [4:0] {
        INIT  = 5'b00001,
        LOAD_ADDR = 5'b00010,
        READ  = 5'b00100,
        WRITE = 5'b01000,
        WAIT  = 5'b10000
    } State_t;

    State_t State, NextState;

    always_ff @(posedge CLK) begin
        if (RESET)
            State <= INIT;
        else
            State <= NextState;
    end

    always_comb begin
        unique0 case (State)
            INIT: {LA, OE, WE} = '0;
            LOAD_ADDR: LA = '1;
            READ: {LA, OE} = 2'b01;
            WRITE: {LA, WE} = 2'b01;
        endcase
    end

    always_comb begin
        NextState = State;
        unique0 case (State)
            INIT: if (CS && ALE) NextState = LOAD_ADDR;
            LOAD_ADDR: begin
                if (!RD) NextState = READ;
                else if (!WR) NextState = WRITE;
            end
            READ, WRITE: NextState = WAIT;
            WAIT: NextState = INIT;
        endcase
    end

endmodule
