`timescale 1ns / 1ps
// ============================================================================
// Top-Level Module: arty_s7_neuromorphic_top
// Target: Digilent Arty S7-25 (AMD Xilinx Spartan-7 XC7S25-CSGA324-1)
//
// Neuromorphic Spiking-Residue Processor with Autonomous BIST and Wireless CDC
// Features:
//   - Unconditional Autonomous Hardware Demo Engine (Always actively cycling)
//   - Synchronous Direct-Strobe Architecture (Immune to floating/DC pin lockup)
//   - 2-Stage CDC Synchronizer & 2-Cycle Glitch-Rejection Filter
//   - Dual-Endian Sliding-Window Receptive Field Burst Detector (5'b10110)
//   - Line-Rate Modulo-3 Residue Arithmetic Invariant Engine with Self-Healing
//   - Digital Leaky Integrate-and-Fire (LIF) Spiking Neuron Core
//   - Hardware Built-In Self-Test (BIST) with 16-Bit LFSR & MISR
//
// Physical Interfaces:
//   Arduino / ChipKit Digital Header J1 (Bank 14, LVCMOS33):
//     IO2 (Pin L16): esp_spike_in    (Input from ESP8266 GPIO2 / D4)
//     IO3 (Pin R14): esp_pat_ack     (Output ACK to ESP8266 GPIO4 / D2)
//     IO4 (Pin T14): esp_neuron_fire (Output spike to ESP8266 GPIO5 / D1)
//     IO5 (Pin R16): esp_bist_pass   (Output BIST pass to ESP8266 GPIO12 / D6)
//     GND (Header J1/J3): Board Ground common to ESP8266 GND
//
//   Slide Switches:
//     sw[0] (Pin H14): 0 = Normal / Autonomous Mode, 1 = BIST Hardware Self-Test Mode
//     sw[1] (Pin H18): 0 = Full Auto Demo Cycle, 1 = Heartbeat Only Mode
//
//   Push Buttons:
//     btn[0] (Pin G15): On-Demand Byzantine Mod-3 Fault Injection (Instant LD0 RED)
//     btn[1] (Pin K16): Force Immediate Self-Healing Resynchronization to S0
//     RESET_N (Pin C18): Board Dedicated Red Reset Button (Active-Low)
//
//   Visual Indicators:
//     LD0 (RGB): Vibrant Solid GREEN = Residue Invariant Valid (S0 & S1)
//                Vibrant Solid RED   = Byzantine Mod-3 Desync Anomaly (S2)
//     LD1 (RGB): Brilliant Electric BLUE flash = Action Potential Fired
//                Purple / Cyan                = BIST Mode Active / Pass
//     LD2 (Green): Solid ON on Residue Valid (S0/S1) or BIST Pass
//     LD3 (Green): Remainder Bit 0 Active (S1 state)
//     LD4 (Green): Remainder Bit 1 Active (S2 Byzantine Error)
//     LD5 (Green): Spike Activity Strobe (60 ms flash per arriving spike)
// ============================================================================

module arty_s7_neuromorphic_top (
    input  wire        CLK100MHZ,      // 100 MHz Master System Clock (Pin R2)
    input  wire        RESET_N,        // Red Reset Button (Pin C18, Active-Low)
    input  wire [1:0]  sw,             // sw[0]=BIST Mode, sw[1]=Demo Mode Select
    input  wire [3:0]  btn,            // btn[0]=Fault Inject, btn[1]=Resync
    // PMOD / Arduino Header Interconnect to ESP8266
    input  wire        esp_spike_in,   // IO2 (Pin L16, Pulldown enabled)
    output wire        esp_pat_ack,    // IO3 (Pin R14)
    output wire        esp_neuron_fire,// IO4 (Pin T14)
    output wire        esp_bist_pass,  // IO5 (Pin R16)
    // On-board RGB LEDs
    output wire        led0_r,         // LD0 Red (Residue Error S2)
    output wire        led0_g,         // LD0 Green (Residue Invariant Valid)
    output wire        led0_b,         // LD0 Blue
    output wire        led1_r,         // LD1 Red (BIST Mode)
    output wire        led1_g,         // LD1 Green (BIST Pass)
    output wire        led1_b,         // LD1 Blue (Neuron Action Potential Fire)
    // 4 Standard Green LEDs
    output wire [3:0]  led             // led[0]=LD2, led[1]=LD3, led[2]=LD4, led[3]=LD5
);

    // ------------------------------------------------------------------------
    // Reset Synchronizer: Active-Low (Dedicated Board Red Button C18)
    // ------------------------------------------------------------------------
    reg [2:0] rst_sync = 3'b111;
    always @(posedge CLK100MHZ) begin
        rst_sync <= {rst_sync[1:0], RESET_N};
    end
    wire rst_n = rst_sync[2];

    // ------------------------------------------------------------------------
    // Debouncers for Physical Push Buttons BTN0 and BTN1 (10ms debounce)
    // ------------------------------------------------------------------------
    reg [19:0] db_cnt0 = 20'd0;
    reg btn0_stable = 1'b0, btn0_stable_d = 1'b0;
    reg [1:0] btn0_meta = 2'b00;

    always @(posedge CLK100MHZ) begin
        btn0_meta <= {btn0_meta[0], btn[0]};
        if (btn0_meta[1] != btn0_stable) begin
            db_cnt0 <= db_cnt0 + 1'b1;
            if (db_cnt0 >= 20'd1_000_000) begin
                btn0_stable <= btn0_meta[1];
                db_cnt0     <= 20'd0;
            end
        end else begin
            db_cnt0 <= 20'd0;
        end
        btn0_stable_d <= btn0_stable;
    end
    wire btn0_pulse = btn0_stable & ~btn0_stable_d;

    // Manual on-demand Byzantine fault generator:
    // Emits two synchronous pulses 25 cycles apart (< 100us refractory limit)
    reg [5:0] btn_fault_seq = 6'd0;
    reg       btn_fault_strobe = 1'b0;

    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            btn_fault_seq    <= 6'd0;
            btn_fault_strobe <= 1'b0;
        end else begin
            if (btn0_pulse) begin
                btn_fault_seq <= 6'd1;
            end else if (btn_fault_seq > 0 && btn_fault_seq < 6'd50) begin
                btn_fault_seq <= btn_fault_seq + 1'b1;
            end else begin
                btn_fault_seq <= 6'd0;
            end

            // 1-cycle strobe at cycle 1 and cycle 25 (25 cycles = 250ns apart)
            btn_fault_strobe <= (btn_fault_seq == 6'd1) || (btn_fault_seq == 6'd25);
        end
    end

    // ------------------------------------------------------------------------
    // Autonomous Hardware Demo Engine
    // 4.0-second repeating cycle running synchronously on CLK100MHZ
    // ------------------------------------------------------------------------
    reg [28:0] auto_cnt = 29'd0;
    localparam [28:0] AUTO_PERIOD = 29'd400_000_000; // 4.0 seconds @ 100MHz
    reg auto_spike_strobe = 1'b0;

    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            auto_cnt          <= 29'd0;
            auto_spike_strobe <= 1'b0;
        end else begin
            if (auto_cnt >= AUTO_PERIOD - 1) begin
                auto_cnt <= 29'd0;
            end else begin
                auto_cnt <= auto_cnt + 1'b1;
            end

            // Single-cycle synchronous strobes
            case (auto_cnt)
                // --- Phase 1: Rhythmic Heartbeat Spikes (every 120ms from 0.0s to 1.2s) ---
                29'd12_000_000, 29'd24_000_000, 29'd36_000_000, 29'd48_000_000,
                29'd60_000_000, 29'd72_000_000, 29'd84_000_000, 29'd96_000_000,
                29'd108_000_000, 29'd120_000_000:
                    auto_spike_strobe <= 1'b1;

                // --- Phase 2: 5-Burst Matching (10110) & LIF Threshold Fire (1.3s to 1.6s) ---
                // In 200us epochs:
                29'd130_000_000: auto_spike_strobe <= 1'b1; // Epoch 0: bit 1
                // Epoch 1: bit 0 (silence)
                29'd130_040_000: auto_spike_strobe <= 1'b1; // Epoch 2: bit 1
                29'd130_060_000: auto_spike_strobe <= 1'b1; // Epoch 3: bit 1
                // Epoch 4: bit 0 -> Burst matches at 1.3008s, synaptic weight boosts to +500mV!

                // Follow-up spikes to cross 1000mV threshold -> Fire LD1 BLUE!
                29'd140_000_000: auto_spike_strobe <= 1'b1;
                29'd155_000_000: auto_spike_strobe <= 1'b1;

                // --- Phase 3: Byzantine Mod-3 Fault Injection (2.2s) ---
                // Two spikes 30 cycles apart (300ns < 100us refractory limit) -> Forces S2 RED!
                // (Only active when sw[1] == 0; if sw[1] == 1, fault is manual via BTN0 or ESP8266)
                29'd220_000_000: auto_spike_strobe <= (~sw[1]);
                29'd220_000_030: auto_spike_strobe <= (~sw[1]);

                // --- Phase 4: Self-Healing Resync (3.2s) ---
                // After 1.0s of solid RED display, regular spike self-heals S2 -> S0 (Back to GREEN!)
                29'd320_000_000: auto_spike_strobe <= 1'b1;

                // --- Phase 5: Steady Telemetry Spikes before cycle wrap ---
                29'd350_000_000: auto_spike_strobe <= 1'b1;
                29'd380_000_000: auto_spike_strobe <= 1'b1;

                default: auto_spike_strobe <= 1'b0;
            endcase
        end
    end

    // Combined synchronous spike strobe to core
    wire core_sync_spike = auto_spike_strobe | btn_fault_strobe;

    // ------------------------------------------------------------------------
    // Instantiate Neuromorphic BIST Core
    // ------------------------------------------------------------------------
    wire clean_spike;
    wire pat_found;
    wire div_by_3;
    wire [1:0] rem_state;
    wire neuron_fire;
    wire [15:0] membrane_pot;
    wire bist_done;
    wire bist_pass;
    wire [15:0] misr_signature;

    neuromorphic_bist_core #(
        .LFSR_SEED(16'hACE1),
        .MISR_GOLDEN(16'h4F29),
        .LEAK_FACTOR(8'd2),
        .V_THRESHOLD(16'd1000),
        .REFRACTORY_LIMIT(10_000), // 10,000 cycles = 100us refractory limit
        .EPOCH_TICKS(20_000)       // 200us sliding-window epoch
    ) u_neuro_core (
        .clk(CLK100MHZ),
        .rst_n(rst_n),
        .bist_en(sw[0]),
        .async_spike_in(esp_spike_in),
        .sync_spike_in(core_sync_spike),
        .clean_spike(clean_spike),
        .pat_found(pat_found),
        .div_by_3(div_by_3),
        .rem_state(rem_state),
        .neuron_fire(neuron_fire),
        .membrane_pot(membrane_pot),
        .bist_done(bist_done),
        .bist_pass(bist_pass),
        .misr_signature(misr_signature)
    );

    // ------------------------------------------------------------------------
    // Pulse Stretchers for ESP8266 Interconnect (Human & Microcontroller Latency)
    // ------------------------------------------------------------------------
    // Pattern ACK pulse stretcher (100 ms) to ESP8266 IO3 (Pin R14)
    reg [23:0] pat_ack_timer = 24'd0;
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) pat_ack_timer <= 24'd0;
        else if (pat_found) pat_ack_timer <= 24'd10_000_000;
        else if (pat_ack_timer > 0) pat_ack_timer <= pat_ack_timer - 1'b1;
    end
    assign esp_pat_ack = (pat_ack_timer > 0);

    // Neuron Action Potential pulse stretcher (120 ms) to ESP8266 IO4 (Pin T14)
    reg [23:0] neuron_fire_timer = 24'd0;
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) neuron_fire_timer <= 24'd0;
        else if (neuron_fire) neuron_fire_timer <= 24'd12_000_000;
        else if (neuron_fire_timer > 0) neuron_fire_timer <= neuron_fire_timer - 1'b1;
    end
    assign esp_neuron_fire = (neuron_fire_timer > 0);

    // BIST Pass status to ESP8266 IO5 (Pin R16)
    assign esp_bist_pass = bist_pass;

    // ------------------------------------------------------------------------
    // Pulse Stretchers for On-Board Visual Indicators (Arty S7 LEDs)
    // ------------------------------------------------------------------------
    // LD5 (Green): Spike Activity Flash (60 ms)
    reg [22:0] spike_led_timer = 23'd0;
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) spike_led_timer <= 23'd0;
        else if (clean_spike) spike_led_timer <= 23'd6_000_000;
        else if (spike_led_timer > 0) spike_led_timer <= spike_led_timer - 1'b1;
    end
    wire spike_led_active = (spike_led_timer > 0);

    // LD1 (RGB Blue): Neuron Action Potential Flash (150 ms)
    reg [24:0] fire_led_timer = 25'd0;
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) fire_led_timer <= 25'd0;
        else if (neuron_fire) fire_led_timer <= 25'd15_000_000;
        else if (fire_led_timer > 0) fire_led_timer <= fire_led_timer - 1'b1;
    end
    wire fire_led_active = (fire_led_timer > 0);

    // Remainder State & Byzantine Error Display Stretcher (800 ms hold on fault)
    reg [26:0] err_led_timer = 27'd0;
    reg [23:0] rem1_led_timer = 24'd0;

    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            err_led_timer  <= 27'd0;
            rem1_led_timer <= 24'd0;
        end else begin
            // Byzantine Mod-3 Desync Error (S2): latch for 1.2s so RED glow is unmistakable!
            if (rem_state == 2'b10) begin
                err_led_timer <= 27'd120_000_000;
            end else if (err_led_timer > 0) begin
                err_led_timer <= err_led_timer - 1'b1;
            end

            // Remainder 1 (S1): latch for 80ms for visible LD3 toggle
            if (rem_state == 2'b01) begin
                rem1_led_timer <= 24'd8_000_000;
            end else if (rem1_led_timer > 0) begin
                rem1_led_timer <= rem1_led_timer - 1'b1;
            end
        end
    end

    // Visual Error Active: either currently in S2 or within the 1.2s error display window
    wire error_visual_active = (rem_state == 2'b10) || (err_led_timer > 0);
    wire rem1_visual_active  = (rem_state[0])       || (rem1_led_timer > 0);

    // ------------------------------------------------------------------------
    // Physical LED Output Assignments
    // ------------------------------------------------------------------------
    // LD2 (Green, led[0]): Valid Invariant (Solid ON when S0/S1; OFF on S2 error; BIST pass in BIST)
    assign led[0] = sw[0] ? bist_pass : ~error_visual_active;

    // LD3 (Green, led[1]): Remainder Bit 0 / MISR Signature Bit 0
    assign led[1] = sw[0] ? misr_signature[0] : (rem1_visual_active & ~error_visual_active);

    // LD4 (Green, led[2]): Remainder Bit 1 / MISR Signature Bit 1 (Turns ON during Byzantine Error!)
    assign led[2] = sw[0] ? misr_signature[1] : error_visual_active;

    // LD5 (Green, led[3]): Spike Activity Strobe (60 ms flash per arriving spike)
    assign led[3] = spike_led_active;

    // RGB LED LD0: Modulo-3 Residue Status
    // Vibrant Solid GREEN during normal operation (S0 & S1);
    // Vibrant Solid RED when Byzantine Mod-3 Desync error (S2) occurs!
    assign led0_g = ~error_visual_active;
    assign led0_r = error_visual_active;
    assign led0_b = 1'b0;

    // RGB LED LD1: Neuromorphic Action Potential & BIST Mode Status
    // Brilliant Electric BLUE when neuron fires action potential (150 ms flash)
    // High visual priority: always flashes pure BLUE on action potential
    assign led1_r = fire_led_active ? 1'b0 : sw[0];
    assign led1_g = fire_led_active ? 1'b0 : (sw[0] & bist_pass);
    assign led1_b = fire_led_active | (sw[0] & ~bist_pass);

endmodule
