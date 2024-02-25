module MemoryOrIOModule1 (CLK, RESET, CS, OE, WR, IOM, Address, Data);

    parameter ADDR_WIDTH = 20;  // Width of the 8088 address bus
    parameter DATA_WIDTH = 8;   // Width of the 8088 data bus
    parameter MEM_SIZE = 512;   // Size of memory in KiB

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire OE; // Output Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire IOM; // I/O or Memory. 0 for memory, 1 for I/O
    input wire [ADDR_WIDTH-1:0] Address;
    inout wire [DATA_WIDTH-1:0] Data;

    typedef enum logic [2:0] {
        IDLE  = 3'b001,
        READ  = 3'b010,
        WRITE = 3'b100
    } State_t;

    State_t State, NextState;

    // Memory or I/O storage
    reg [DATA_WIDTH-1:0] mem[0:(MEM_SIZE*1024)-1];

    // Internal signals for data bus handling
    reg [DATA_WIDTH-1:0] data_out;
    reg data_out_valid;

    // First procedural block to model sequential logic
    always_ff @(posedge CLK) begin
        if (RESET) begin
            State <= IDLE;
        end else begin
            State <= NextState;
        end
    end

    // Second procedural block to model next state and output combinational logic
    always_comb begin
        // Default assignments for combinational logic
        NextState = State;
        data_out_valid = 1'b0;
        data_out = {DATA_WIDTH{1'b0}};

        case (State)
            IDLE: begin
                if (CS) begin
                    if (!OE && WR) begin
                        NextState = READ;
                    end else if (OE && !WR) begin
                        NextState = WRITE;
                    end
                end
            end
            READ: begin
                if (CS && !OE) begin
                    data_out = mem[Address];  // Prepare data to be output on the bus
                    data_out_valid = 1'b1;
                end
                NextState = IDLE;
            end
            WRITE: begin
                if (CS && !WR) begin
                    mem[Address] = Data;  // Capture the data from the bus
                end
                NextState = IDLE;
            end
        endcase
    end

    // Tristate buffer control for bidirectional Data bus
    assign Data = data_out_valid ? data_out : {DATA_WIDTH{1'bz}};

endmodule
