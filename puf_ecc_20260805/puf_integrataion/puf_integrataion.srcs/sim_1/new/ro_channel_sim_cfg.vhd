configuration ro_channel_sim_cfg of ro_channel is

    for Structural

        for OSC_COMP : osc
            use entity work.osc(Simulation);
        end for;

    end for;

end configuration ro_channel_sim_cfg;