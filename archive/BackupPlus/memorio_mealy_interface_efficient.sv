module MemoryOrIOModule (Intel8088Pins bus);

    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter BASE_ADDR = 0;
    parameter NUM_UNITS = (1 << ADDR_WIDTH);
    parameter DEVICE_INDEX = 0;
    parameter INIT_FILE = "memory_init.mem";

    // Control signals between ControlSequencer and Datapath
    wire OE, WE, LA;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .BASE_ADDR(BASE_ADDR), .NUM_UNITS(NUM_UNITS), .INIT_FILE(INIT_FILE)) datapath (bus.CLK, bus.RESET, bus.Address[ADDR_WIDTH-1:0], bus.Data, LA, OE, WE);
    ControlSequencer controlSequencer (bus.CLK, bus.RESET, bus.ALE, bus.RD, bus.WR, bus.CS[DEVICE_INDEX], LA, OE, WE);

endmodule

module Datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE);
    
    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter BASE_ADDR = 0;
    parameter NUM_UNITS = (1 << ADDR_WIDTH);
    parameter INIT_FILE = "memory_init.mem";
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    input wire CLK;
    input wire RESET;
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;
    input wire LA; // Load Address. From ControlSequencer
    input wire OE; // Output Enable. From ControlSequencer
    input wire WE; // Write Enable. From ControlSequencer
    
    reg [EFF_ADDR_WIDTH-1:0] ADDR_REG;
    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];

    // Tristate buffer control for bidirectional Data bus
    assign DATA = OE ? MEM[ADDR_REG] : 'z;

    // Load initial memory contents from file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

    always_ff @(posedge CLK) begin
        if (LA)
            ADDR_REG <= ADDRESS - BASE_ADDR;
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
