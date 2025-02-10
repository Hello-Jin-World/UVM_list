`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.12.2024 11:55:24
// Design Name: 
// Module Name: tb_uvm_register
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

interface reg_interface ();
    logic        clk;
    logic        resetn;
    logic        en;
    logic [31:0] d;
    logic [31:0] q;
endinterface  //reg_interface

class seq_item extends uvm_sequence_item;
    rand logic [31:0] d;
    logic      [31:0] q;
    rand logic        en;

    function new(input string name = "seq_item");
        super.new(name);
    endfunction  //new()

    `uvm_object_utils_begin(seq_item)  // macro
        `uvm_field_int(d, UVM_DEFAULT)  // There is not ";"
        `uvm_field_int(q, UVM_DEFAULT)
        `uvm_field_int(en, UVM_DEFAULT)
    `uvm_object_utils_end

    task display(string name);
        $display("[%s], en: %d, d: %0d, q: %0d", name, en, d, q);
    endtask  //$display("");

endclass  //seq_item extends uvm_sequence_item

class reg_sequence extends uvm_sequence;
    `uvm_object_utils(reg_sequence)

    seq_item reg_seq_item;  // handler

    function new(input string name = "reg_sequence");
        super.new(name);
    endfunction  //new()

    virtual task body();
        reg_seq_item =
            seq_item::type_id::create("SEQ_ITEM");  // create instance
        repeat (100) begin
            start_item(reg_seq_item);
            reg_seq_item.randomize();
            `uvm_info("SEQ", "Data send to Driver", UVM_NONE);
            finish_item(reg_seq_item);
        end
    endtask
endclass  //reg_sequence extends uvm_sequence

class reg_driver extends uvm_driver #(seq_item);  // receive seq_time
    `uvm_component_utils(reg_driver)

    virtual reg_interface regIntf;
    seq_item              reg_seq_item;


    function new(input string name = "reg_driver", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reg_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual reg_interface)::get(
                this, ",", "regIntf", regIntf
            ))
            `uvm_fatal(get_name(), "Unable to access adder interface");
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        $display("display start of simulation phase!");
    endfunction

    virtual task run_phase(uvm_phase phase);
        $display("display run phase!");
        forever begin
            seq_item_port.get_next_item(reg_seq_item);
            regIntf.en = reg_seq_item.en;
            regIntf.d  = reg_seq_item.d;
            @(posedge regIntf.clk);
            `uvm_info("DRV", "Send data to DUT", UVM_NONE);
            #5;
            seq_item_port.item_done();
        end
    endtask  //run_phase
endclass  //reg_driver extends uvm_driver #(seq_item)

class reg_monitor extends uvm_monitor;
    `uvm_component_utils(reg_monitor)

    uvm_analysis_port #(seq_item) send;
    virtual reg_interface regIntf;
    seq_item reg_seq_item;

    function new(input string name = "reg_monitor", uvm_component c);
        super.new(name, c);
        send = new("WRITE", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        reg_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual reg_interface)::get(
                this, "", "regIntf", regIntf
            )) begin
            `uvm_fatal(get_name(), "Unable to access reg interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge regIntf.clk);
            //When detect Clock Rising Edge 
            #2;
            // Never be changed input data from interface.
            reg_seq_item.en = regIntf.en;
            reg_seq_item.d  = regIntf.d;
            reg_seq_item.q  = regIntf.q;
            `uvm_info("MON", "Send data to Scoreboard", UVM_NONE);
            send.write(reg_seq_item);
        end
    endtask  //run_phase
endclass  //reg_monitor extends uvm_monitor

class reg_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(reg_scoreboard)

    uvm_analysis_imp #(seq_item, reg_scoreboard) recv;



    function new(input string name = "reg_scoreboard", uvm_component c);
        super.new(name, c);
        recv = new("READ", this);
    endfunction  //new()

    virtual function void write(seq_item data);
        `uvm_info("SCB", "Data received from Monitor", UVM_NONE);

        if (data.en == 1'b1) begin
            if (data.d == data.q) begin
                `uvm_info("SCB", $sformatf("PASS!!!, d: %d == q: %d", data.d,
                                           data.q), UVM_NONE);
            end else begin
                `uvm_info("SCB", $sformatf("FAIL!!!, d: %d != q: %d", data.d,
                                           data.q), UVM_NONE);
            end
        end

        data.print(uvm_default_line_printer);
    endfunction
endclass  //reg_scoreboard extends uvm_scoreboard;

class reg_agent extends uvm_agent;
    `uvm_component_utils(reg_agent)

    reg_monitor regMonitor;
    reg_driver regDriver;
    uvm_sequencer #(seq_item) regSequencer;

    function new(input string name = "reg_agent", uvm_component c);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        regMonitor   = reg_monitor::type_id::create("MON", this);
        regDriver    = reg_driver::type_id::create("DRV", this);
        regSequencer = uvm_sequencer#(seq_item)::type_id::create("SQR", this);
        //Create Instance        
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        regDriver.seq_item_port.connect(regSequencer.seq_item_export);
    endfunction
endclass  //reg_agent extends uvm_agent

class reg_env extends uvm_env;
    `uvm_component_utils(reg_env)

    reg_scoreboard regScoreboard;
    reg_agent regAgent;

    function new(input string name = "reg_env", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        regScoreboard = reg_scoreboard::type_id::create("SCB", this);
        regAgent      = reg_agent::type_id::create("AGENT", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        regAgent.regMonitor.send.connect(regScoreboard.recv);
    endfunction
endclass  //reg_env extendsuvm_env;

class reg_test extends uvm_test;
    `uvm_component_utils(reg_test)

    reg_sequence regSequence;
    reg_env regEnv;

    function new(input string name = "reg_test", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        regSequence = reg_sequence::type_id::create("SEQ", this);
        regEnv      = reg_env::type_id::create("ENV", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        regSequence.start(regEnv.regAgent.regSequencer);
        phase.drop_objection(this);
    endtask
endclass  //reg_test extends uvm_test

module tb_uvm_register ();

    reg_interface regIntf ();
    reg_test regTest;

    register dut (
        .clk   (regIntf.clk),
        .resetn(regIntf.resetn),
        .en    (regIntf.en),
        .d     (regIntf.d),
        .q     (regIntf.q)
    );

    always #5 regIntf.clk = ~regIntf.clk;

    initial begin
        // `uvm_info("Test 1", "Hello World", UVM_NONE);
        // uvm_report_info("Test 2", "This is Reporting", UVM_MEDIUM);
        // uvm_report_info("Test 3", "This is Reporting", UVM_FULL);
        regIntf.clk = 0;
        regIntf.resetn = 0;
        #10;
        regIntf.resetn = 1;
    end

    initial begin
        regTest = new("32bit Register UVM Verification", null);
        uvm_config_db#(virtual reg_interface)::set(null, "*", "regIntf",
                                                   regIntf);
        // db -> type : virtual reg_interface ,       key : "regIntf" value : regIntf
        run_test();
    end
endmodule
