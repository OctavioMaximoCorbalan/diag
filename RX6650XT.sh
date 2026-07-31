#!/bin/bash

set -u

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Error: Este script requiere privilegios de superusuario. Ejecútalo con sudo."
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR" || exit 1

PROFILE_SOURCE="XFX6650XT_CONF_MOD.DAT"
PROFILE_ACTIVE="FCT_CONF.DAT"
ENGINE="rx_diag_engine.pl"

sync_profile() {
    cp -f "$PROFILE_SOURCE" "$PROFILE_ACTIVE"
}

archive_and_clean_runtime() {
    ts=$(date +%Y%m%d_%H%M%S)
    archive_dir="test_logs/archive/raw_${ts}"
    mkdir -p "$archive_dir"
    shopt -s nullglob
    files=(log.txt log.yml errorid.tmp MarginResult.csv MarginResult.txt MCU.log shm_testid.log fan_status.tmp *.tmp)
    moved=0
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            mv "$f" "$archive_dir/"
            moved=1
        fi
    done
    shopt -u nullglob
    if [ "$moved" -eq 1 ]; then
        echo "Archived runtime files to $archive_dir"
    fi
}

print_header() {
    clear
    printf "\33[1;46m   RX6650 XT Navi23 Diagnostic Launcher   \33[0m\n"
    echo
    printf "Perfil activo: %s -> %s\n" "$PROFILE_SOURCE" "$PROFILE_ACTIVE"
    echo
}

show_hardware() {
    sync_profile
    print_header
    echo "=== Perfil activo ==="
    cat "$PROFILE_ACTIVE"
    echo
    echo "=== ASIC / memoria ==="
    ./agt -sid || true
    echo
    ./agt -mccfg || true
    echo
    ./agt -biosbuildnum || true
}

force_clocks_max() {
    ./agt -i=0 -ppmode=1 >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=mclk,max >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=soc,max >/dev/null 2>&1 || true
}

run_training() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Memory Training Check ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./memtune trainingcheck
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_memfa() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Diagnostico VRAM (NAVI23_MEMFA) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    force_clocks_max
    timeout 600s ./tserver -boardtest=NAVI23_MEMFA
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_channels() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Aislamiento de Canales (NAVI23_CHANNELS) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    force_clocks_max
    timeout 600s ./tserver -boardtest=navi23_channels
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_margintest() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Prueba de Margen GDDR6 (Margintest / 2dx.sh) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./margintest.sh
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_ak404() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Test de Estres Grafico (AK404.001) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./tserver -d=gpu.* -test=ak404.001
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_stress() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Stress Test Post-Reparacion (NAVI23_STRESS) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    force_clocks_max
    timeout 600s ./tserver -boardtest=navi23_stress
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_chkfp() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Check FP (CHKFP) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./tserver -boardtest=chkfp -rmdriver
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_quick() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Quick Manufacturing (QUICKMFG4) ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./tserver -boardtest=quickmfg4 -nobamaco -noctf
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_full() {
    print_header
    echo "=== SUITE COMPLETA AUTOMATICA ==="
    echo "Iniciando secuencia de diagnostico total..."
    sleep 2
    run_training
    echo "Presiona Enter para continuar con MEMFA..." && read -r
    run_memfa
    echo "Presiona Enter para continuar con Analisis de Canales..." && read -r
    run_channels
    echo "Presiona Enter para continuar con Stress Post-Reparacion..." && read -r
    run_stress
    echo "=== SUITE FINALIZADA. Revisa test_logs/ para el historial. ==="
}

view_logs() {
    clear
    echo "=== Ultimos Reportes en test_logs/ ==="
    shopt -s nullglob
    logs=(test_logs/*.log)
    shopt -u nullglob
    if [ ${#logs[@]} -eq 0 ]; then
        echo "No hay reportes disponibles aun."
        return
    fi
    IFS=$'\n' sorted_logs=($(ls -t "${logs[@]}"))
    PS3="Selecciona un log para abrir (presiona Enter para ver lista, 0 para salir): "
    select opt in "${sorted_logs[@]}"; do
        if [ -n "$opt" ]; then
            less "$opt"
            break
        else
            break
        fi
    done
}

usage() {
    cat <<'EOF'
Uso: ./RX6650XT.sh [opcion]

Opciones disponibles:
  info        Muestra el perfil activo y los datos de hardware (ASIC/Memoria)
  training    Ejecuta el chequeo de training de memoria (memtune)
  memfa       Ejecuta el flujo NAVI23_MEMFA con validacion y parser
  channels    Ejecuta el diagnostico aislado por canales (NAVI23_CHANNELS)
  margintest  Ejecuta la prueba de margen GDDR6 (margintest.sh / 2dx.sh)
  ak404       Ejecuta el test de estres grafico directo (ak404.001)
  stress      Ejecuta el Stress Post-Reparacion (NAVI23_STRESS)
  chkfp       Ejecuta el flujo chkfp del suite_bp
  quick       Ejecuta quickmfg4 sin pasos de CTF/BAMACO
  full        Ejecuta la SUITE COMPLETA AUTOMATICA en secuencia
  logs        Abre el visor interactivo de los ultimos reportes
  menu        Abre el menu interactivo principal (opcion por defecto)
EOF
}

menu() {
    while true; do
        print_header
        echo " 1) Informacion y Validacion de Hardware"
        echo " 2) Training Check de Memoria"
        echo " 3) Diagnostico VRAM (NAVI23_MEMFA)"
        echo " 4) Diagnostico Fino por Canales (NAVI23_CHANNELS)"
        echo " 5) Prueba de Margen GDDR6 (Margintest / 2dx.sh)"
        echo " 6) Test de Estres Grafico (AK404.001)"
        echo " 7) Test de Estres Post-Reparacion (NAVI23_STRESS)"
        echo " 8) Check FP (CHKFP)"
        echo " 9) Quick Manufacturing (QUICKMFG4)"
        echo " 10) SUITE COMPLETA AUTOMATICA (Full Sequence)"
        echo " 11) Ver Ultimos Reportes en 'test_logs/'"
        echo " Q) Salir"
        echo
        read -r -p "Opcion: " choice
        case "$choice" in
            1) show_hardware; read -r -p "Enter para continuar..." _ ;;
            2) run_training; read -r -p "Enter para continuar..." _ ;;
            3) run_memfa; read -r -p "Enter para continuar..." _ ;;
            4) run_channels; read -r -p "Enter para continuar..." _ ;;
            5) run_margintest; read -r -p "Enter para continuar..." _ ;;
            6) run_ak404; read -r -p "Enter para continuar..." _ ;;
            7) run_stress; read -r -p "Enter para continuar..." _ ;;
            8) run_chkfp; read -r -p "Enter para continuar..." _ ;;
            9) run_quick; read -r -p "Enter para continuar..." _ ;;
            10) run_full; read -r -p "Enter para continuar..." _ ;;
            11) view_logs; read -r -p "Enter para continuar..." _ ;;
            q|Q) exit 0 ;;
            *) echo "Opcion invalida"; sleep 1 ;;
        esac
    done
}

case "${1:-menu}" in
    info) show_hardware ;;
    training) run_training ;;
    memfa) run_memfa ;;
    channels) run_channels ;;
    margintest) run_margintest ;;
    ak404) run_ak404 ;;
    stress) run_stress ;;
    chkfp) run_chkfp ;;
    quick) run_quick ;;
    full) run_full ;;
    logs) view_logs ;;
    menu) menu ;;
    -h|--help|help) usage ;;
    *) echo "Opcion desconocida: $1"; usage; exit 1 ;;
esac