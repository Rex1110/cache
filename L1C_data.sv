module L1C_data(
    input                                   clk,
    input                                   rst,
    
    input           [`DATA_BITS-1:0      ]  core_addr,
    input                                   core_req,
    input                                   core_write,
    input           [`DATA_BITS-1:0      ]  core_in,
    input           [`CACHE_TYPE_BITS-1:0]  core_type,
    
    input           [`DATA_BITS-1:0      ]  D_out,
    input                                   D_wait,
    
    output logic    [`DATA_BITS-1:0      ]  core_out,
    output logic                            core_wait
);

    logic [`CACHE_INDEX_BITS-1:0] index;
    logic [`CACHE_DATA_BITS-1:0 ] DA_out;
    logic [`CACHE_DATA_BITS-1:0 ] DA_in;
    logic [`CACHE_WRITE_BITS-1:0] DA_write;
    logic [`CACHE_TAG_BITS-1:0  ] TA_out;
    logic [`CACHE_TAG_BITS-1:0  ] tag;
    logic                         TA_write;
    logic [`CACHE_LINES-1:0     ] valid;
    logic [3:0                  ] offset;
    logic [1:0                  ] state;
    logic                         r_hit, w_hit;
    logic [1:0                  ] word_cnt;
    logic [95:0                 ] DA_in_buffer;

    // | 31     10 | 9     4 | 3      0
    // |    tag    |  index  |  offset
    assign {tag, index, offset} = core_addr;

    //cache status
    //status 0: IDLE
    //status 1: Look up decide hit or miss
    //status 2: refill
    //status 3: write hit update or miss bypass

    localparam  IDLE   = 0,
                LOOKUP = 1,
                REFILL = 2,
                WRITE  = 3;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: state <= core_req ? LOOKUP : state;
                LOOKUP: begin
                    if (core_write) begin
                        state <= 2'd3;
                    end else if (r_hit == 1'b0) begin
                        state <= REFILL;
                    end else begin
                        state <= IDLE;
                    end
                end
                default: state <= core_wait ? state : IDLE;
            endcase 
        end
    end

    always_comb begin
        case (state)
            LOOKUP : core_wait = r_hit ? 1'b0 : 1'b1;
            REFILL : core_wait = (word_cnt == 2'd3 && ~D_wait) ? 1'b0 : 1'b1;
            WRITE  : core_wait = D_wait;
            default: core_wait = 1'b1;
        endcase
    end

    always_comb begin
        if (core_req && state != IDLE) begin
            if (valid[index]) begin
                if (tag == TA_out) begin
                    w_hit = core_write ? 1'b1 : 1'b0;
                    r_hit = ~w_hit;
                end else begin
                    w_hit = 1'b0;
                    r_hit = 1'b0;
                end
            end else begin
                r_hit = 1'b0;
                w_hit = 1'b0;
            end
        end else begin
            r_hit  = 1'b0;
            w_hit  = 1'b0;
        end
    end


    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            valid <= 64'd0;
        end else begin
            valid[index] <= (state == REFILL && ~core_wait) ? 1'b1 : valid[index];
        end
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            word_cnt <= 2'b0;
        end else begin
            if (state == REFILL) begin
                word_cnt <= D_wait ? word_cnt : word_cnt + 2'd1;
            end else begin
                word_cnt <= 2'd0;
            end
        end
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            DA_in_buffer <= 96'b0;
        end else begin
            if (state == REFILL) begin
                if (D_wait) begin
                    DA_in_buffer <= DA_in_buffer;
                end else begin
                    case (word_cnt)
                        2'b00  : DA_in_buffer[ 31: 0] <= D_out;
                        2'b01  : DA_in_buffer[ 63:32] <= D_out;
                        2'b10  : DA_in_buffer[ 95:64] <= D_out;
                        default: DA_in_buffer         <= DA_in_buffer;
                    endcase
                end
            end else begin
                DA_in_buffer <= 96'b0;
            end
        end
    end

    always_comb begin
        case (offset[3:2])
            2'b00: core_out = r_hit ? DA_out[ 31: 0] : DA_in_buffer[31: 0];
            2'b01: core_out = r_hit ? DA_out[ 63:32] : DA_in_buffer[63:32];
            2'b10: core_out = r_hit ? DA_out[ 95:64] : DA_in_buffer[95:64];
            2'b11: core_out = r_hit ? DA_out[127:96] : D_out              ;
        endcase
    end

    assign DA_in = core_write ? {4{core_in}} : {D_out, DA_in_buffer};

    always_comb begin
        case (state)
            2'd2: begin
                DA_write = ~core_wait ? 16'b0 : 16'b1111_1111_1111_1111;
                TA_write = ~core_wait ? 1'b0 : 1'b1;
            end
            2'd3: begin
                TA_write = 1'b1;
                if (w_hit && ~core_wait) begin //last cycle of write hit
                    case (core_type)
                        `CACHE_BYTE:
                            case (offset[3:2])
                                2'b00: begin
                                    DA_write[15:4] = 12'b1111_1111_1111;
                                    case (offset[1:0])
                                        2'b00:   DA_write[3:0] = 4'b1110;
                                        2'b01:   DA_write[3:0] = 4'b1101;
                                        2'b10:   DA_write[3:0] = 4'b1011;
                                        default: DA_write[3:0] = 4'b0111;
                                    endcase
                                end
                                2'b01: begin
                                    DA_write[15:8] = 8'b1111_1111;
                                    DA_write[3:0] = 4'b1111;
                                    case (offset[1:0])
                                        2'b00:   DA_write[7:4] = 4'b1110;
                                        2'b01:   DA_write[7:4] = 4'b1101;
                                        2'b10:   DA_write[7:4] = 4'b1011;
                                        default: DA_write[7:4] = 4'b0111;
                                    endcase
                                end
                                2'b10: begin
                                    DA_write[15:12] = 4'b1111;
                                    DA_write[7:0] = 8'b1111_1111;
                                    case (offset[1:0])
                                        2'b00:   DA_write[11:8] = 4'b1110;
                                        2'b01:   DA_write[11:8] = 4'b1101;
                                        2'b10:   DA_write[11:8] = 4'b1011;
                                        default: DA_write[11:8] = 4'b0111;
                                    endcase
                                end
                                default: begin
                                    DA_write[11:0] = 12'b1111_1111_1111;
                                    case (offset[1:0])
                                        2'b00:   DA_write[15:12] = 4'b1110;
                                        2'b01:   DA_write[15:12] = 4'b1101;
                                        2'b10:   DA_write[15:12] = 4'b1011;
                                        default: DA_write[15:12] = 4'b0111;
                                    endcase
                                end
                            endcase
                        `CACHE_HWORD:
                            case (offset[3:2])
                                2'b00: begin
                                    DA_write[15:4] = 12'b1111_1111_1111;
                                    DA_write[3 :2] = (offset[1:0] == 2'b00) ? 2'b11 : 2'b00;
                                    DA_write[1 :0] = (offset[1:0] == 2'b00) ? 2'b00 : 2'b11;
                                end
                                2'b01: begin
                                    DA_write[15:8] = 8'b1111_1111;
                                    DA_write[3 :0] = 4'b1111;
                                    DA_write[7 :6] = (offset[1:0] == 2'b00) ? 2'b11 : 2'b00;
                                    DA_write[5 :4] = (offset[1:0] == 2'b00) ? 2'b00 : 2'b11;
                                end
                                2'b10: begin
                                    DA_write[15:12] = 4'b1111;
                                    DA_write[7 : 0] = 8'b1111_1111;
                                    DA_write[11:10] = (offset[1:0] == 2'b00) ? 2'b11 : 2'b00;
                                    DA_write[9 : 8] = (offset[1:0] == 2'b00) ? 2'b00 : 2'b11;
                                end
                                default: begin
                                    DA_write[11: 0] = 12'b1111_1111_1111;
                                    DA_write[15:14] = (offset[1:0] == 2'b00) ? 2'b11 : 2'b00;
                                    DA_write[13:12] = (offset[1:0] == 2'b00) ? 2'b00 : 2'b11;
                                end
                            endcase
                        `CACHE_WORD:
                            case (offset[3:2])
                                2'b00: begin
                                    DA_write[15:4] = 12'b1111_1111_1111;
                                    DA_write[3 :0] = 4'b0000;
                                end
                                2'b01: begin
                                    DA_write[15:8] = 8'b1111_1111;
                                    DA_write[ 3:0] = 4'b1111;
                                    DA_write[ 7:4] = 4'b0000;
                                end
                                2'b10: begin
                                    DA_write[15:12] = 4'b1111;
                                    DA_write[ 7: 0] = 8'b1111_1111;
                                    DA_write[11: 8] = 4'b0000;
                                end
                                default: begin
                                    DA_write[11: 0] = 12'b1111_1111_1111;
                                    DA_write[15:12] = 4'b0000;
                                end
                            endcase
                        default: DA_write = 16'b1111_1111_1111_1111;
                    endcase
                end else begin
                    DA_write = 16'b1111_1111_1111_1111;
                end
            end
            default: begin
                DA_write = 16'b1111_1111_1111_1111;
                TA_write = 1'b1;
            end
        endcase
    end

    data_array_wrapper DA(
        .A  (index      ),
        .DO (DA_out     ),
        .DI (DA_in      ),
        .CK (clk        ),
        .WEB(DA_write   ),
        .OE (1'b1       ),
        .CS (1'b1       )
    );
    
    tag_array_wrapper TA(
        .A  (index      ),
        .DO (TA_out     ),
        .DI (tag        ),
        .CK (clk        ),
        .WEB(TA_write   ),
        .OE (1'b1       ),
        .CS (1'b1       )
    );

endmodule