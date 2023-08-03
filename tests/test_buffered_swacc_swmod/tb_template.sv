{% extends "lib/tb_base.sv" %}

{% block seq %}
    {% sv_line_anchor %}
    logic [15:0] counter;
    logic [7:0] rd_data_l;
    logic [7:0] rd_data_h;
    logic [15:0] latched_data;
    int event_count;
    latched_data = 'x;

    ##1;
    cb.rst <= '0;
    ##1;

    // Verify that hwif gets sampled at the same cycle as swacc strobe
    counter = 'h10;
    cb.hwif_in.r1.f.next <= counter;
    @cb;
    event_count = 0;
    fork
        begin
            ##0;
            forever begin
                counter++;
                cb.hwif_in.r1.f.next <= counter;
                @cb;
                if(cb.hwif_out.r1.f.swacc) begin
                    latched_data = counter;
                    event_count++;
                end
            end
        end

        begin
            cpuif.read('h0, rd_data_l);
            cpuif.read('h1, rd_data_h);
            @cb;
        end
    join_any
    disable fork;
    assert({rd_data_h, rd_data_l} == latched_data) else $error("Read returned 0x%0x but swacc strobed during 0x%0x", {rd_data_h, rd_data_l}, latched_data);
    assert(event_count == 1) else $error("Observed excess swacc events: %0d", event_count);


    // Verify that hwif changes 1 cycle after swmod
    fork
        begin
            ##0;
            forever begin
                assert(cb.hwif_out.r2.f.value == 'h4020);
                if(cb.hwif_out.r2.f.swmod) break;
                @cb;
            end
            @cb;
            forever begin
                assert(cb.hwif_out.r2.f.value == 'h4221);
                assert(cb.hwif_out.r2.f.swmod == 0);
                @cb;
            end
        end

        begin
            cpuif.write('h2, 'h21);
            cpuif.write('h3, 'h42);
            @cb;
        end
    join_any
    disable fork;

    // Verify that hwif changes 1 cycle after swmod
    fork
        begin
            ##0;
            forever begin
                assert(cb.hwif_out.r3.f.value == 'h1030);
                if(cb.hwif_out.r3.f.swmod) break;
                @cb;
            end
            @cb;
            forever begin
                assert(cb.hwif_out.r3.f.value == 0);
                assert(cb.hwif_out.r3.f.swmod == 0);
                @cb;
            end
        end

        begin
            cpuif.assert_read('h4, 'h30);
            cpuif.assert_read('h5, 'h10);
            @cb;
        end
    join_any
    disable fork;

{% endblock %}
