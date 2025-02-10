`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/07 10:35:58
// Design Name: 
// Module Name: UVM_SCCB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


interface sccb_interface ();
    logic       write;
    logic       clk;
    logic       reset;
    logic       start;
    logic [7:0] reg_addr;
    logic [7:0] data;
    logic       scl;
    wire        sda;
    logic       done;
    logic       ack_error;

    assign sda = !write ? 1'b0 : 1'bz;
endinterface  //sccb_interface

class seq_item extends uvm_sequence_item;
    logic      [ 7:0] addr;
    logic      [ 7:0] addr_sccb_addr;
    logic      [ 3:0] addr_sccb_wData;
    rand logic [ 7:0] sccb_addr;
    rand logic [ 7:0] sccb_wData;
    logic      [31:0] rData;
    logic             write;
    logic      [ 7:0] got_addr;
    logic      [ 7:0] got_wData;

    function new(input string name = "seq_item");
        super.new(name);
    endfunction  //new()

    `uvm_object_utils_begin(seq_item)  // macro
        `uvm_field_int(addr, UVM_DEFAULT)  // There is not ";"
        `uvm_field_int(addr_sccb_addr, UVM_DEFAULT)  // There is not ";"
        `uvm_field_int(addr_sccb_wData, UVM_DEFAULT)
        `uvm_field_int(sccb_addr, UVM_DEFAULT)
        `uvm_field_int(sccb_wData, UVM_DEFAULT)
        `uvm_field_int(rData, UVM_DEFAULT)
        `uvm_field_int(write, UVM_DEFAULT)
        `uvm_field_int(got_addr, UVM_DEFAULT)
        `uvm_field_int(got_wData, UVM_DEFAULT)
    `uvm_object_utils_end


endclass  //seq_item extends uvm_sequence_item

class sccb_sequence extends uvm_sequence;
    `uvm_object_utils(sccb_sequence)

    seq_item sccb_seq_item;  // handler

    function new(input string name = "sccb_sequence");
        super.new(name);
    endfunction  //new()

    virtual task body();
        sccb_seq_item =
            seq_item::type_id::create("SEQ_ITEM");  // create instance
        repeat (10000) begin
            start_item(sccb_seq_item);
            sccb_seq_item.randomize();
            `uvm_info("SEQ", "Data send to Driver", UVM_NONE);
            finish_item(sccb_seq_item);
        end
    endtask
endclass  //sccb_sequence extends uvm_sequence

class sccb_driver extends uvm_driver #(seq_item);  // receive seq_time
    `uvm_component_utils(sccb_driver)

    virtual sccb_interface sccbIntf;
    seq_item               sccb_seq_item;

    function new(input string name = "sccb_driver", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sccb_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual sccb_interface)::get(
                this, ",", "sccbIntf", sccbIntf
            ))
            `uvm_fatal(get_name(), "Unable to access adder interface");
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        $display("display start of simulation phase!");
    endfunction

    task reset_sccb();
        sccbIntf.reset <= 0;
        sccbIntf.write <= 1;
        #10;
    endtask  //reset

    virtual task run_phase(uvm_phase phase);
        $display("display run phase!");
        reset_sccb();
        forever begin
            seq_item_port.get_next_item(sccb_seq_item);
            `uvm_info("DRV", "Send data to DUT", UVM_NONE);
            // wait (sccbIntf.SCL == 1);
            // wait (sccbIntf.SDA == 1);

            //////////////////////////      RANDOM ADDRESS       //////////////////////////// 
            sccbIntf.reg_addr = {24'b0, sccb_seq_item.sccb_addr};
            #20;
            ////////////////////////////////////////////////////////////////////////////////

            //////////////////////////    RANDOM WRITE DATA     //////////////////////////// 
            sccbIntf.data = {24'b0, sccb_seq_item.sccb_wData};
            #20;
            ////////////////////////////////////////////////////////////////////////////////

            ////////////////////////    CCR DATA, START BIT     //////////////////////////// 
            sccbIntf.start = 1'b1;
            ////////////////////////////////////////////////////////////////////////////////
            repeat (9) @(posedge sccbIntf.scl);

            /////////////////////////    WAIT DUT RESPONSE     /////////////////////////////
            repeat (9) @(posedge sccbIntf.scl);
            // sccbIntf.PADDR   = 8'h04;
            sccbIntf.write = 0;
            @(negedge sccbIntf.scl);
            sccbIntf.write = 1;
            repeat (9) @(posedge sccbIntf.scl);
            ////////////////////////////////////////////////////////////////////////////////

            /////////////////////////    FOR DUT STABILITY      ////////////////////////////
            wait (sccbIntf.scl == 1);
            wait (sccbIntf.sda == 1);
            ////////////////////////////////////////////////////////////////////////////////
            seq_item_port.item_done();
        end
    endtask  //run_phase
endclass  //sccb_driver extends uvm_driver #(seq_item)

class sccb_monitor extends uvm_monitor;
    `uvm_component_utils(sccb_monitor)

    uvm_analysis_port #(seq_item) send;
    virtual sccb_interface sccbIntf;
    seq_item sccb_seq_item;

    logic [7:0] read_sccb_addr, read_sccb_wData;
    logic [7:0] random_sccb_addr, random_sccb_wData;

    function new(input string name = "sccb_monitor", uvm_component c);
        super.new(name, c);
        send = new("WRITE", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sccb_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual sccb_interface)::get(
                this, "", "sccbIntf", sccbIntf
            )) begin
            `uvm_fatal(get_name(), "Unable to access reg interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            ///////////////////     GETTING SOFTWARE RANDOM DATA      ///////////////////
            // @(posedge sccbIntf.write);
            @(negedge sccbIntf.scl);
            repeat (9) @(posedge sccbIntf.scl);

            random_sccb_addr  = sccbIntf.reg_addr[7:0];
            // @(posedge sccbIntf.PWRITE);
            random_sccb_wData = sccbIntf.data[7:0];
            /////////////////////////////////////////////////////////////////////////////

            ///////////////////      STORE DUT SDA DATA AS 0 OR 1       //////////////////
            for (int i = 0; i < 8; i++) begin
                @(posedge sccbIntf.scl);
                if (sccbIntf.sda) begin
                    read_sccb_addr[7-i] = 1'b1;
                end else begin
                    read_sccb_addr[7-i] = 1'b0;
                end
            end

            @(posedge sccbIntf.scl);

            for (int i = 0; i < 8; i++) begin
                @(posedge sccbIntf.scl);
                if (sccbIntf.sda) begin
                    read_sccb_wData[7-i] = 1'b1;
                end else begin
                    read_sccb_wData[7-i] = 1'b0;
                end
            end

            @(posedge sccbIntf.scl);
            /////////////////////////////////////////////////////////////////////////////
            sccb_seq_item.rData      = sccbIntf.data;
            sccb_seq_item.addr       = sccbIntf.reg_addr;

            ///////////////     TRANSMIT SOFTWARE GOLDEN DATA TO SCB     ////////////////
            sccb_seq_item.sccb_addr  = random_sccb_addr;
            sccb_seq_item.sccb_wData = random_sccb_wData;
            /////////////////////////////////////////////////////////////////////////////

            ///////////////     TRANSMIT HARDWARE RESULT DATA TO SCB     ////////////////
            sccb_seq_item.got_addr   = read_sccb_addr;
            sccb_seq_item.got_wData  = read_sccb_wData;
            /////////////////////////////////////////////////////////////////////////////

            /////////////////////////    FOR DUT STABILITY      ////////////////////////////
            wait (sccbIntf.scl == 1);
            wait (sccbIntf.sda == 1);
            ////////////////////////////////////////////////////////////////////////////////
            `uvm_info("MON", "Send data to Scoreboard", UVM_NONE);
            send.write(sccb_seq_item);
        end
    endtask  //run_phase
endclass  //sccb_monitor extends uvm_monitor

class sccb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(sccb_scoreboard)

    uvm_analysis_imp #(seq_item, sccb_scoreboard) recv;

    int total_cnt, pass_cnt, fail_cnt;
    // logic [31:0] scb_moder, scb_idr, scb_odr;

    function new(input string name = "sccb_scoreboard", uvm_component c);
        super.new(name, c);
        recv = new("READ", this);
        total_cnt   = 0;
        pass_cnt    = 0;
        fail_cnt    = 0;
    endfunction  //new()

    virtual function void write(seq_item data);
        // `uvm_info("SCB", "Data received from Monitor", UVM_NONE);

        if (data.got_addr == data.sccb_addr && data.got_wData == data.sccb_wData) begin
            `uvm_info(
                "SCB",
                $sformatf(
                    "PASS!!!, ADDR -> hw: %8b == sw: %8b  /  DATA-> hw: %8b == sw: %8b",
                    data.got_addr, data.sccb_addr, data.got_wData,
                    data.sccb_wData), UVM_NONE);
            pass_cnt++;
        end else begin
            `uvm_info(
                "SCB",
                $sformatf(
                    "FAIL..., ADDR -> hw: %8b != sw: %8b  /  DATA-> hw: %8b != sw: %8b",
                    data.got_addr, data.sccb_addr, data.got_wData,
                    data.sccb_wData), UVM_NONE);
            fail_cnt++;
        end
        total_cnt++;
        data.print(uvm_default_line_printer);

        $display("====================================");
        $display("Total Test : %d ", total_cnt);
        $display("========     Oper Result    ========");
        $display(" Pass Test : %d ", pass_cnt);
        $display(" Fail Test : %d ", fail_cnt);
        $display("====================================");
    endfunction
endclass  //sccb_scoreboard extends uvm_scoreboard;

class sccb_agent extends uvm_agent;
    `uvm_component_utils(sccb_agent)

    sccb_monitor sccbMonitor;
    sccb_driver sccbDriver;
    uvm_sequencer #(seq_item) sccbSequencer;

    function new(input string name = "sccb_agent", uvm_component c);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sccbMonitor   = sccb_monitor::type_id::create("MON", this);
        sccbDriver    = sccb_driver::type_id::create("DRV", this);
        sccbSequencer = uvm_sequencer#(seq_item)::type_id::create("SQR", this);
        //Create Instance        
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        sccbDriver.seq_item_port.connect(sccbSequencer.seq_item_export);
    endfunction
endclass  //sccb_agent extends uvm_agent

covergroup pkt_cg with function sample (seq_item sccb_seq_item);
    coverpoint sccb_seq_item.sccb_addr;
    coverpoint sccb_seq_item.sccb_wData;
endgroup

class packet_coverage extends uvm_subscriber #(seq_item);
    `uvm_component_utils(packet_coverage)

    pkt_cg tr_cov;
    bit coverage_enable = 1;

    function new(input string name = "packet_coverage", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        if (coverage_enable) begin
            tr_cov = new();
        end
    endfunction

    virtual function void write(seq_item data);
        if (coverage_enable) begin
            tr_cov.sample(data);
            $display("====================================");
            $display("Coverage = %0.2f %%", tr_cov.get_inst_coverage());
            $display("====================================");
        end
    endfunction
endclass

class sccb_env extends uvm_env;
    `uvm_component_utils(sccb_env)

    sccb_scoreboard sccbScoreboard;
    sccb_agent sccbAgent;
    packet_coverage cov_comp;

    function new(input string name = "sccb_env", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sccbScoreboard = sccb_scoreboard::type_id::create("SCB", this);
        sccbAgent      = sccb_agent::type_id::create("AGENT", this);
        cov_comp       = packet_coverage::type_id::create("cov_comp", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        sccbAgent.sccbMonitor.send.connect(sccbScoreboard.recv);
        sccbAgent.sccbMonitor.send.connect(cov_comp.analysis_export);
    endfunction
endclass  //sccb_env extendsuvm_env;

class sccb_test extends uvm_test;
    `uvm_component_utils(sccb_test)

    sccb_sequence sccbSequence;
    sccb_env sccbEnv;

    function new(input string name = "sccb_test", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sccbSequence = sccb_sequence::type_id::create("SEQ", this);
        sccbEnv      = sccb_env::type_id::create("ENV", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        sccbSequence.start(sccbEnv.sccbAgent.sccbSequencer);
        phase.drop_objection(this);
    endtask
endclass  //sccb_test extends uvm_test

module UVM_SCCB ();

    sccb_interface sccbIntf ();
    sccb_test sccbtest;

    SCCB_intf dut (
        .clk      (sccbIntf.clk),
        .reset    (sccbIntf.reset),
        .start    (sccbIntf.start),
        .reg_addr (sccbIntf.reg_addr),
        .data     (sccbIntf.data),
        .scl      (sccbIntf.scl),
        .sda      (sccbIntf.sda),
        .done     (sccbIntf.done),
        .ack_error(sccbIntf.ack_error)
    );


    always #20 sccbIntf.clk = ~sccbIntf.clk;

    initial begin
        sccbIntf.clk   = 0;
        sccbIntf.reset = 1;
        #10;
        sccbIntf.reset = 0;
    end

    initial begin
        sccbtest = new(" UVM Verification", null);
        uvm_config_db#(virtual sccb_interface)::set(null, "*", "sccbIntf",
                                                    sccbIntf);
        // db -> type : virtual sccb_interface ,       key : "sccbIntf" value : sccbIntf
        run_test();
    end
endmodule
