
#Pasta do RTL
set PROJECT_DIR /prj/ci/workarea/aluno25/mppt_core/mppt_core
#Pasta da Biblioteca de timing
set LIB_DIR /pdk/gpdk045/gsclib045_svt_v4.7/gsclib045/timing
#Pasta da Biblioteca fisica
set LEF_DIR /pdk/gpdk045/gsclib045_svt_v4.7/gsclib045/lef


set HDL_LIB /pdk/gpdk045/gsclib045_svt_v4.7/gsclib045/verilog/slow_vdd1v2_basicCells.v

#Modulo principal (top)
set HDL_NAME "mppt_core"
#Arquivos HDL - verilog
set HDL_FILES ${PROJECT_DIR}/mppt_core.sv 

#Biblioteca pessimista
set WORST_LIST {slow_vdd1v0_basicCells.lib} 
#Biblioteca otimista
set BEST_LIST {fast_vdd1v2_basicCells.lib} 
#Biblioteca fisica
set LEF_LIST {gsclib045_tech.lef gsclib045_macro.lef}


#Set the search paths to the libraries and the HDL files
set_db hdl_search_path "${PROJECT_DIR}"

#set_db lib_search_path "${LIB_DIR} ${LEF_DIR}"
set_db lib_search_path "${LIB_DIR}"

set_db library "${BEST_LIST}"

read_hdl ${HDL_FILES}

elaborate ${HDL_NAME}

set_top_module ${HDL_NAME}

check_design -unresolved 

read_sdc ${PROJECT_DIR}/constraints/${HDL_NAME}.sdc

syn_generic ${HDL_NAME}

syn_map ${HDL_NAME} 

syn_opt ${HDL_NAME}

report_timing > ${PROJECT_DIR}/reports/${HDL_NAME}_timing.rpt

report_power > ${PROJECT_DIR}/reports/${HDL_NAME}_power.rpt

report_qor > ${PROJECT_DIR}/reports/${HDL_NAME}_qor.rpt

report_area > ${PROJECT_DIR}/reports/${HDL_NAME}_area.rpt

write_hdl ${HDL_NAME} > ${PROJECT_DIR}/netlist/${HDL_NAME}.v

