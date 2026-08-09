
# ================================================================
# Static RO placement-exclusion Pblock
# ================================================================

create_pblock puf_ro_region

add_cells_to_pblock  [get_pblocks puf_ro_region]  [get_cells -hier -quiet -filter {
        IS_PRIMITIVE && NAME =~ */OSC_COMP/*
    }]

resize_pblock [get_pblocks puf_ro_region] -add {
    SLICE_X41Y68:SLICE_X41Y71
    SLICE_X44Y68:SLICE_X44Y71
    SLICE_X46Y68:SLICE_X46Y71
    SLICE_X47Y68:SLICE_X47Y71
}

set_property EXCLUDE_PLACEMENT TRUE  [get_pblocks puf_ro_region]

