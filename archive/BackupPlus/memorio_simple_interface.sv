module MemoryOrIOModule (Intel8088Pins bus, input wire CS);

    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter BASE_ADDR = 0;
    parameter NUM_UNITS = (1 << ADDR_WIDTH);
    parameter INIT_FILE = "memory_init.mem";
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];
    reg [DATA_WIDTH-1:0] DOUT;
    reg OE; //Output Enable. Active high

    // Calculate the index for the internal memory array
    wire [EFF_ADDR_WIDTH-1:0] MEM_INDEX = bus.Address[ADDR_WIDTH-1:0] - BASE_ADDR;
    // Tristate buffer control for bidirectional Data bus
    assign bus.Data = OE ? DOUT : 'z;

    // State definitions
    typedef enum logic [3:0] {
        IDLE  = 4'b0001,
        READ  = 4'b0010,
        WRITE = 4'b0100,
        TIMEPASS = 4'b1000
    } State_t;

    State_t State, NextState;

    always_ff @(posedge bus.CLK) begin
        if (bus.RESET) State <= IDLE;
        else State <= NextState;
    end

    // Second procedural block to model next state combinational logic
    always_comb begin

        NextState = State;
        case (State)
            IDLE: begin
                if (CS) begin
                    if (!bus.RD) NextState = READ;
                    else if (!bus.WR) NextState = WRITE;
                end
            end
            READ, WRITE:
                NextState = TIMEPASS;
            TIMEPASS:
                NextState = IDLE;
        endcase

    end

    // Third procedural block to model output combinational logic
    always_comb begin
        
        OE = '0;
        DOUT = {DATA_WIDTH{1'b0}};

        case (State)
            READ: begin
                DOUT = MEM[MEM_INDEX];  // Prepare data to be output on the bus
                OE = '1;
            end
            WRITE: begin
                MEM[MEM_INDEX] = bus.Data;  // Capture the data from the bus
            end
        endcase

    end

    // Initial block to load memory contents from a file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

endmodule
