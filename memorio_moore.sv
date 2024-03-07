module MemoryOrIOModule (CLK, RESET, ALE, CS, RD, WR, ADDRESS, DATA);
    
    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire ALE; // Address Latch Enable
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;

    // Control signals between ControlSequencer and Datapath
    wire OE, WE, LA;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .INIT_FILE(INIT_FILE)) datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE);
    ControlSequencer controlSequencer (CLK, RESET, ALE, CS, RD, WR, LA, OE, WE);

endmodule

module Datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE);
    
    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    localparam NUM_UNITS = (1 << ADDR_WIDTH);
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

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
    assign DATA = OE ? MEM[ADDR_REG] : {DATA_WIDTH{1'bz}};

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

module ControlSequencer (CLK, RESET, ALE, CS, RD, WR, LA, OE, WE);

    input wire CLK;
    input wire RESET;
    input wire ALE; // Address Latch Enable. Active high
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    output reg LA; // Load Address. To Datapath
    output reg OE; // Output Enable. To Datapath
    output reg WE; // Write Enable. To Datapath

    typedef enum logic [4:0] {
        IDLE  = 5'b00001,
        LOAD_ADDR = 5'b00010,
        READ  = 5'b00100,
        WRITE = 5'b01000,
        WAIT  = 5'b10000
    } State_t;

    State_t State, NextState;

    always_ff @(posedge CLK) begin
        if (RESET)
            State <= IDLE;
        else
            State <= NextState;
    end

    always_comb begin
        {LA, OE, WE} = '0;
        unique case (State)
            LOAD_ADDR: LA = '1;
            READ: OE = '1;
            WRITE: WE = '1;
        endcase
    end

    always_comb begin
        NextState = State;
        unique case (State)
            IDLE: if (CS && ALE) NextState = LOAD_ADDR;
            LOAD_ADDR: begin
                if (!RD) NextState = READ;
                else if (!WR) NextState = WRITE;
            end
            READ, WAIT: NextState = IDLE;
            WRITE: NextState = WAIT;
        endcase
    end

endmodule
