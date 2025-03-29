`define DATA_BITS 32
`define CACHE_TYPE_BITS 3
`define CACHE_BYTE `CACHE_TYPE_BITS'b000
`define CACHE_HWORD `CACHE_TYPE_BITS'b001
`define CACHE_WORD `CACHE_TYPE_BITS'b010
`define CACHE_INDEX_BITS 6
`define CACHE_TAG_BITS 22
`define CACHE_DATA_BITS 128
`define CACHE_LINES 2**(`CACHE_INDEX_BITS)
`define CACHE_WRITE_BITS 16

`include "./data_array_rtl.sv"
`include "./tag_array_rtl.sv"
`include "./data_array_wrapper.sv"
`include "./tag_array_wrapper.sv"
`include "./L1C_data.sv"

module cache_tb;

    logic clk, rst;
    logic core_req;
    logic core_write;
    logic core_wait;
    logic D_wait;
    logic [`CACHE_TYPE_BITS-1:0] core_type;
    logic [`DATA_BITS-1:0] core_addr, core_in, core_out, D_out;
    
    bit           valid   [64];
    bit [21: 0]   tag     [64];
    bit [ 5: 0]   index   [64];
    bit [127:0]   memory  [64];

    L1C_data L1C_data_(
        .clk        (clk        ),
        .rst        (rst        ),

        .core_addr  (core_addr  ), // read or write cache address
        .core_req   (core_req   ), // read or write req
        .core_write (core_write ), // read or write cache
        .core_in    (core_in    ), // write data to cache
        .core_type  (core_type  ), // write type byte, half word, word

        .D_out      (D_out      ), // MEM -> cache
        .D_wait     (D_wait     ), // MEM OK or not

        .core_out   (core_out   ), // cache -> Core
        .core_wait  (core_wait  )  // cache not enable
    );

    initial begin
        clk = 0;
        forever #2 clk = ~clk;
    end

    initial begin
        rst = 1;
        @(posedge clk);
        rst = 0;
    end

    task read();
        logic [`DATA_BITS-1:0] data;
        @(posedge clk);
        core_req   <= 1;
        core_write <= 0;
        wait(L1C_data_.state == 2'd1);

        if (L1C_data_.r_hit == (valid[core_addr[9:4]] && (core_addr[31:20] == tag[core_addr[9:4]]))) begin
            if (L1C_data_.r_hit == 1'b0) begin
                $display("READ ADDR[%0d] MISS", core_addr);
                $display("REFILL");
                for (int i = 0; i < 4; i++) begin
                    
                    @(posedge clk);
                    if ($random % 2 == 1) begin
                        D_wait<= 1;
                        i--;
                    end else begin
                        data = $random;
                        D_wait <= 0;
                        D_out  <= data;
                        memory[core_addr[9:4]][32*i+:32] = data;
                    end
                end
                tag[core_addr[9:4]] = core_addr[31:20];
                valid[core_addr[9:4]] = 1'b1;
            end else begin
                $display("READ ADDR[%0d] HIT", core_addr);
            end
        end else begin
            $display("r hit %0d, %0d, ", L1C_data_.TA_out, tag[core_addr[9:4]], valid[core_addr[9:4]]);
            $fatal("cache miss hit fail");
        end

        @(negedge L1C_data_.core_wait == 'd0);
        // Compare
        if (memory[core_addr[9:4]][32*core_addr[3:2]+:32] == core_out) begin
            $display("READ ADDR[%0d] = %0d PASS\n", core_addr, memory[core_addr[9:4]][32*core_addr[3:2]+:32]);
        end else begin
            $fatal("READ ADDR[%0d] = %0d, FAIL, your is %0d\n", core_addr, memory[core_addr[9:4]][32*core_addr[3:2]+:32], core_out);
        end
        core_req <= 1'b0;
    endtask

    task write();
        @(posedge clk);
        core_req   <= 1'b1;
        core_write <= 1'b1;
        core_in    <= $random;
        core_type  <= $urandom_range(0, 2);
        wait(L1C_data_.state == 2'b1);

        if (L1C_data_.w_hit == (valid[core_addr[9:4]] && (core_addr[31:20] == tag[core_addr[9:4]]))) begin
            case (core_type)
                `CACHE_BYTE: begin
                    case (core_addr[3:0]) 
                        4'd0  : memory[core_addr[9:4]][7 : 0 ]  = core_in[7:0];
                        4'd1  : memory[core_addr[9:4]][15: 8 ]  = core_in[7:0];
                        4'd2  : memory[core_addr[9:4]][23:16 ]  = core_in[7:0];
                        4'd3  : memory[core_addr[9:4]][31:24 ]  = core_in[7:0];
                        4'd4  : memory[core_addr[9:4]][39:32 ]  = core_in[7:0];
                        4'd5  : memory[core_addr[9:4]][47:40 ]  = core_in[7:0];
                        4'd6  : memory[core_addr[9:4]][55:48 ]  = core_in[7:0];
                        4'd7  : memory[core_addr[9:4]][63:56 ]  = core_in[7:0];
                        4'd8  : memory[core_addr[9:4]][71:64 ]  = core_in[7:0];
                        4'd9  : memory[core_addr[9:4]][79:72 ]  = core_in[7:0];
                        4'd10 : memory[core_addr[9:4]][87:80 ]  = core_in[7:0];
                        4'd11 : memory[core_addr[9:4]][95:88 ]  = core_in[7:0];
                        4'd12 : memory[core_addr[9:4]][103:96]  = core_in[7:0];
                        4'd13 : memory[core_addr[9:4]][111:104] = core_in[7:0];
                        4'd14 : memory[core_addr[9:4]][119:112] = core_in[7:0];
                        4'd15 : memory[core_addr[9:4]][127:120] = core_in[7:0];
                    endcase
                end
                `CACHE_HWORD: begin
                    case (core_addr[3:1]) 
                        3'd0: memory[core_addr[9:4]][15 : 0 ]  = core_in[15:0];
                        3'd1: memory[core_addr[9:4]][31 : 16]  = core_in[15:0];
                        3'd2: memory[core_addr[9:4]][47 : 32]  = core_in[15:0];
                        3'd3: memory[core_addr[9:4]][63 : 48]  = core_in[15:0];
                        3'd4: memory[core_addr[9:4]][79 : 64]  = core_in[15:0];
                        3'd5: memory[core_addr[9:4]][95 : 80]  = core_in[15:0];
                        3'd6: memory[core_addr[9:4]][111: 96]  = core_in[15:0];
                        3'd7: memory[core_addr[9:4]][127:112]  = core_in[15:0];
                    endcase
                end

                `CACHE_WORD: begin
                    case (core_addr[3:2])
                        2'd0: memory[core_addr[9:4]][31 : 0 ]  = core_in;
                        2'd1: memory[core_addr[9:4]][63 : 32]  = core_in;
                        2'd2: memory[core_addr[9:4]][95 : 64]  = core_in;
                        2'd3: memory[core_addr[9:4]][127: 96]  = core_in;
                    endcase
                end
            endcase
        end else begin
            $fatal("cache miss hit fail");
        end

        @(negedge L1C_data_.core_wait == 'd0);
        core_req <= 1'b0;
    endtask

    initial begin
        core_req    <= 0;
        core_write  <= 0;
        core_addr   <= 0;
        core_in     <= 0;
        D_wait      <= 1;
        D_out       <= 0;
        core_type   <= 0;

        // read 0 ~ 64 block
        @(posedge clk);
        for (int i = 0; i < 64; i++) begin
            core_addr <= 16 * i;
            read();
        end
        core_addr = 0;
        // write 0 ~ 64 block
        for (int i = 0; i < 64; i++) begin
            core_addr <= 16 * i;
            write();
        end
        // random
        repeat (50) begin
            core_addr = $random % (64 * 16);
            read();
        end

        // random
        repeat (50) begin
            core_addr = $random % (64 * 16);
            write();
        end

        $finish;
    end

    valid_bit_p: assert property (
        @(posedge clk)
            (rst == 1) |-> L1C_data_.valid == 64'b0
    );

    hit_miss_r: assert property (
        @(posedge clk)
            (core_req && !core_write && L1C_data_.state == 0 &&
            valid[core_addr[9:4]] && tag[core_addr[9:4]] == core_addr[31:10])
            |=> (L1C_data_.r_hit && !L1C_data_.w_hit)
    );

    hit_miss_w: assert property (
        @(posedge clk)
            (core_req && core_write && L1C_data_.state == 0 &&
            valid[core_addr[9:4]] && tag[core_addr[9:4]] == core_addr[31:10])
            |=> (!L1C_data_.r_hit && L1C_data_.w_hit)
    );

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, cache_tb);
    end
endmodule