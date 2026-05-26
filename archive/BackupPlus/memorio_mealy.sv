module MemoryOrIOModule (CLK, RESET, ALE, RD, WR, CS, ADDRESS, DATA);
    
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
    wire LA, OE, WE;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .INIT_FILE(INIT_FILE)) datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE);
    ControlSequencer controlSequencer (CLK, RESET, ALE, RD, WR, CS, LA, OE, WE);

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
    assign DATA = OE ? MEM[ADDR_REG] : 'z;

    // Load initial memory contents from file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

    // Load DOUT with data from memory and capture data from the bus and store in memory
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
    input wire ALE; // Address Latch Enable
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire CS; // Chip Select. Active high
    output reg LA; // Load Address. To Datapath
    output reg OE; // Output Enable. To Datapath
    output reg WE; // Write Enable. To Datapath

    typedef enum logic [2:0] {
        INIT  = 3'b001,
        RD_OR_WR = 3'b010,
        WAIT  = 3'b100
    } State_t;

    State_t State, NextState;

    always_ff @(posedge CLK) begin
        if (RESET)
            State <= INIT;
        else
            State <= NextState;
    end

    always_comb begin
        NextState = State;
        unique0 case (State)
            INIT: begin
                if (CS && ALE) begin
                    LA = '1;
                    NextState = RD_OR_WR;
                end
                else {LA, WE, OE} = '0;
            end
            RD_OR_WR: begin
                if (!RD) begin
                    {LA, OE} = 2'b01;
                    NextState = WAIT;
                end
                else if (!WR) begin
                    {LA, WE} = 2'b01;
                    NextState = WAIT;
                end
            end
            WAIT: begin
                NextState = INIT;
            end
        endcase
    end

endmodule
