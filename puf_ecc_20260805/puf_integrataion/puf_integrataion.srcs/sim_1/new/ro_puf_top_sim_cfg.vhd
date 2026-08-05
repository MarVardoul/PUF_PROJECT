configuration ro_puf_top_sim_cfg of ro_puf_top is

    for Structural

        for CORE_COMP : ro_puf_core
            use configuration work.ro_puf_core_sim_cfg;
        end for;

    end for;

end configuration;