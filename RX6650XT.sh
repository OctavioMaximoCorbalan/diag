#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR" || exit 1

PROFILE_SOURCE="XFX6650XT_CONF_MOD.DAT"
PROFILE_ACTIVE="FCT_CONF.DAT"
EXPECTED_DID="73EF"
EXPECTED_CHIP="NAVI23"
EXPECTED_MEM="8192"

sync_profile() {
    cp -f "$PROFILE_SOURCE" "$PROFILE_ACTIVE"
}

print_header() {
    clear
    printf "\33[1;46m   RX6650 XT Navi23 Diagnostic Launcher   \33[0m\n"
    echo
    printf "Perfil activo: %s -> %s\n" "$PROFILE_SOURCE" "$PROFILE_ACTIVE"
    printf "Esperado: Device ID %s, GPU %s, %s MB\n" "$EXPECTED_DID" "$EXPECTED_CHIP" "$EXPECTED_MEM"
    echo
}

show_hardware() {
    sync_profile
    print_header
    echo "=== Perfil de fabrica activo ==="
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
    sync_profile
    print_header
    echo "=== MEMFA ==="
    ./tserver -boardtest=memfa
}

run_chkfp() {
    sync_profile
    print_header
    echo "=== CHKFP ==="
    ./tserver -boardtest=chkfp -rmdriver
}

run_quick() {
    sync_profile
    print_header
    echo "=== QUICKMFG4 ==="
    ./tserver -boardtest=quickmfg4 -nobamaco -noctf
}

usage() {
    cat <<'EOF'
Uso: ./RX6650XT.sh [info|training|memfa|chkfp|quick|menu]

  info      Muestra perfil activo y datos de hardware
  training  Ejecuta el chequeo de training de memoria
  memfa     Ejecuta el flujo MEMFA del suite_bp
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
        echo "3) MEMFA"
        echo "4) CHKFP"
        echo "5) QUICKMFG4"
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