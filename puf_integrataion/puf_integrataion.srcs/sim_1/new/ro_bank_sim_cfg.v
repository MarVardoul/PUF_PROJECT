configuration ro_bank_sim_cfg of ro_bank is
    for Structural

        for GEN_CHANNELS(0 to 15)

            for CHANNEL_COMP : ro_channel
                use configuration work.ro_channel_sim_cfg;
            end for;

        end for;

    end for;
end configuration;