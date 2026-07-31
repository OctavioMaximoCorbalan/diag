#!/bin/bash

set -u

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Este script requiere root. Ejecútalo con sudo."
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

cleanup_runtime() {
    rm -f errorid.tmp log.txt log.yml MarginResult.csv MarginResult.txt MCU.log shm_testid.log 2>/dev/null || true
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

run_training_check() {
    sync_profile
    print_header
    echo "=== Memory training check ==="
    ./memtune trainingcheck || return $?
}

run_memfa() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== Ejecutando NAVI23_MEMFA ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    # Forzar clocks en modo perf antes de ejecutar UMC/MEMFA
    ./agt -i=0 -ppmode=1 >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=mclk,max >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=soc,max >/dev/null 2>&1 || true
    timeout 600s ./tserver -boardtest=NAVI23_MEMFA
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
    # Forzar clocks en modo perf antes de ejecutar stress
    ./agt -i=0 -ppmode=1 >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=mclk,max >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=soc,max >/dev/null 2>&1 || true
    timeout 600s ./tserver -boardtest=navi23_stress
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

run_chkfp() {
    archive_and_clean_runtime
    sync_profile
    print_header
    echo "=== CHKFP ==="
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
    echo "=== QUICKMFG4 ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
    timeout 600s ./tserver -boardtest=quickmfg4 -nobamaco -noctf
    local rc=$?
    perl "$ENGINE" --parse "$rc"
    return $rc
}

usage() {
    cat <<'EOF'
Uso: ./RX6650XT.sh [info|training|memfa|chkfp|quick|menu]

  info      Muestra perfil activo y datos de hardware
  training  Ejecuta el chequeo de training de memoria
  memfa     Ejecuta el flujo NAVI23_MEMFA con validacion y parser
    stress    Ejecuta el Stress Post-Reparacion (NAVI23_STRESS)
  chkfp     Ejecuta el flujo chkfp del suite_bp
  quick     Ejecuta quickmfg4 sin pasos de CTF/BAMACO
  menu      Abre un menu simple interactivo
EOF
}

menu() {
    while true; do
        print_header
        echo "1) Informacion de hardware"
        echo "2) Training check de memoria"
        echo "3) MEMFA (NAVI23)"
        echo "4) CHKFP"
        echo "5) QUICKMFG4"
        echo "6) Stress Test Post-Reparacion (NAVI23_STRESS)"
        echo "Q) Salir"
        echo
        read -r -p "Opcion: " choice
        case "$choice" in
            1)
                show_hardware
                read -r -p "Enter para continuar..." _
                ;;
            2)
                run_training_check
                read -r -p "Enter para continuar..." _
                ;;
            3)
                run_memfa
                read -r -p "Enter para continuar..." _
                ;;
            4)
                run_chkfp
                read -r -p "Enter para continuar..." _
                ;;
            5)
                run_quick
                read -r -p "Enter para continuar..." _
                ;;
            6)
                run_stress
                read -r -p "Enter para continuar..." _
                ;;
            q|Q)
                exit 0
                ;;
            *)
                echo "Opcion invalida"
                sleep 1
                ;;
        esac
    done
}

case "${1:-menu}" in
    info)
        show_hardware
        ;;
    training)
        run_training_check
        ;;
    memfa)
        run_memfa
        ;;
    stress)
        run_stress
        ;;
    chkfp)
        run_chkfp
        ;;
    quick)
        run_quick
        ;;
    menu)
        menu
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Opcion desconocida: $1"
        usage
        exit 1
        ;;
esac