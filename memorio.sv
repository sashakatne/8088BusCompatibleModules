module MemoryOrIOModule (CLK, RESET, CS, RD, WR, ADDRESS, DATA);
    
    parameter ADDR_WIDTH = 20;
    parameter DATA_WIDTH = 8;
    parameter NUM_UNITS = 512 * 1024; // Adjust based on memory or I/O size
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;

    // Control signals between ControlSequencer and Datapath
    wire OE;
    wire WE;
    wire RE;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .NUM_UNITS(NUM_UNITS), .INIT_FILE(INIT_FILE)) datapath (CLK, RESET, ADDRESS, DATA, OE, WE, RE);
    ControlSequencer controlSequencer (CLK, RESET, CS, RD, WR, OE, WE, RE);

endmodule

module Datapath (CLK, RESET, ADDRESS, DATA, OE, WE, RE);
    
    parameter ADDR_WIDTH = 20;
    parameter DATA_WIDTH = 8;
    parameter NUM_UNITS = 512 * 1024;
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    input wire CLK;
    input wire RESET;
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;
    input wire OE; // From ControlSequencer
    input wire WE; // From ControlSequencer
    input wire RE; // From ControlSequencer
    
    // Adjust the memory array size based on the number of addressable units
    reg [EFF_ADDR_WIDTH-1:0] MEM_INDEX;
    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];
    reg [DATA_WIDTH-1:0] DOUT;

    // Tristate buffer control for bidirectional Data bus
    assign DATA = OE ? DOUT : {DATA_WIDTH{1'bz}};

    // Address from the bus loaded into memory index
    always_comb begin
        MEM_INDEX = ADDRESS;
    end

    // Load initial memory contents from file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

    // Load DOUT with data from memory and capture data from the bus and store in memory
    always_ff @(posedge CLK) begin
        if (RESET)
            DOUT <= {DATA_WIDTH{1'b0}};
        else if (RE)
            DOUT <= MEM[MEM_INDEX]; // Prepare data to be output on the bus
        if (WE)
            MEM[MEM_INDEX] <= DATA; // Capture the data from the bus
    end

endmodule

module ControlSequencer (CLK, RESET, CS, RD, WR, OE, WE, RE);

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    output reg OE; // To Datapath
    output reg WE; // To Datapath
    output reg RE; // To Datapath

    // State definitions using one-hot encoding.
    typedef enum logic [2:0] {
        IDLE  = 3'b001,
        READ  = 3'b010,
        WRITE = 3'b100
    } State_t;

    State_t State, NextState;

    // First procedural block to model sequential logic
    always_ff @(posedge CLK) begin
        if (RESET)
            State <= IDLE;
        else
            State <= NextState;
    end

    // Second procedural block to model output combinational logic
    always_comb begin
        case (State)
            IDLE: begin
                {WE, RE, OE} = '0;
                if (CS) begin
                    if (!RD && WR)
                        RE = '1;
                    else if (RD && !WR)
                        WE = '1;
                end
            end
            READ: begin
                OE = '1;
            end
        endcase
    end

    // Third procedural block to model next state combinational logic
    always_comb begin
        NextState = State;
        case (State)
            IDLE: begin
                if (CS) begin
                    if (!RD && WR)
                        NextState = READ;
                    else if (RD && !WR)
                        NextState = WRITE;
                end
            end
            READ: begin
                NextState = IDLE;
            end
            WRITE: begin
                NextState = IDLE;
            end
        endcase
    end

endmodule
