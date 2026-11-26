#!/bin/bash

set -u
export LC_ALL=C

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
    if [ ! -f "$PROFILE_SOURCE" ]; then
        echo "Error: falta el perfil '$PROFILE_SOURCE'." >&2
        return 1
    fi
    cp -f -- "$PROFILE_SOURCE" "$PROFILE_ACTIVE"
}

archive_and_clean_runtime() {
    local ts archive_dir files moved f
    ts=$(date +%Y%m%d_%H%M%S)
    archive_dir="test_logs/archive/raw_${ts}"
    mkdir -p "$archive_dir" || {
        echo "Error: no se pudo crear el directorio de archivado '$archive_dir'."
        return 1
    }
    files=(log.txt log.yml errorid.tmp MarginResult.csv MarginResult.txt MCU.log shm_testid.log fan_status.tmp)

    moved=0
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            mv "$f" "$archive_dir/"
            moved=1
        fi
    done
    if [ "$moved" -eq 1 ]; then
        echo "Archived runtime files to $archive_dir"
    fi
}

archive_existing_logs() {
    ts=$(date +%Y%m%d_%H%M%S)
    archive_dir="test_logs/archive/run_full_${ts}"
    mkdir -p "$archive_dir" || {
        echo "Error: no se pudo crear el directorio de archivado '$archive_dir'."
        return 1
    }
    shopt -s nullglob
    logs=(test_logs/*.log)
    shopt -u nullglob
    moved=0
    for f in "${logs[@]}"; do
        if [ -e "$f" ]; then
            mv "$f" "$archive_dir/"
            moved=1
        fi
    done
    if [ "$moved" -eq 1 ]; then
        echo "Archived previous logs to $archive_dir"
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

CLOCKS_DIRTY=0   # 1 = la GPU pudo quedar con ppmode/DPM alterados
TEST_TIMEOUT="${TEST_TIMEOUT:-600}"

force_clocks_max() {
    CLOCKS_DIRTY=1
    ./agt -i=0 -ppmode=1 >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=mclk,max >/dev/null 2>&1 || true
    ./agt -i=0 -ppdpmforce=soc,max  >/dev/null 2>&1 || true
}

# Idempotente: errores de dominios que no estaban forzados son esperables.
restore_clocks_safe() {
    [ -x ./agt ] || { echo "[WARN] ./agt no encontrado: NO se pudo restaurar DPM." >&2; return 1; }
    local a
    for a in -ppdpmrestore=mclk -ppdpmrestore=soc -ppdpmrestore=vcn \
             -ppdpmstatus=mclk,on -ppdpmstatus=pcie,on -ppmode=0; do
        ./agt -i=0 "$a" >/dev/null 2>&1 || true
    done
    CLOCKS_DIRTY=0
}

on_exit_restore() {
    local rc=$?
    trap '' INT TERM HUP          # no interrumpir la limpieza
    trap - EXIT
    if [ "$CLOCKS_DIRTY" -eq 1 ]; then
        echo "[CLEANUP] Restaurando DPM/ppmode de la GPU..." >&2
        restore_clocks_safe
    fi
    exit "$rc"
}
trap on_exit_restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Ejecuta un binario de test y SIEMPRE restaura DPM al terminar (ok, fallo, timeout o Ctrl+C).
# --foreground: sin esto Ctrl+C no llega a tserver.
run_guarded() {
    CLOCKS_DIRTY=1
    timeout --foreground -k 15s "${TEST_TIMEOUT}s" "$@"
    local rc=$?
    restore_clocks_safe
    return "$rc"
}

prepare_run() {                       # prepare_run "<titulo>"
    archive_and_clean_runtime || return 1
    sync_profile              || return 1
    print_header
    echo "=== $1 ==="
    perl "$ENGINE" --validate || { echo "Validation failed, aborting."; return 1; }
}

finish_run() {                        # finish_run <rc_de_la_herramienta>
    local rc=$1 prc
    perl "$ENGINE" --parse "$rc"
    prc=$?
    [ "$rc" -eq 0 ] && rc=$prc        # el veredicto FAIL del parser también cuenta
    return "$rc"
}

run_training() {
    prepare_run "Memory Training Check" || return 1
    run_guarded ./memtune trainingcheck
    finish_run $?
}
run_memfa() {
    prepare_run "Diagnostico VRAM (NAVI23_MEMFA)" || return 1
    force_clocks_max
    run_guarded ./tserver -boardtest=NAVI23_MEMFA
    finish_run $?
}
run_channels() {
    prepare_run "Aislamiento de Canales (NAVI23_CHANNELS)" || return 1
    force_clocks_max
    run_guarded ./tserver -boardtest=navi23_channels
    finish_run $?
}
run_margintest() {
    prepare_run "Prueba de Margen GDDR6 (Margintest / 2dx.sh)" || return 1
    run_guarded ./margintest.sh
    finish_run $?
}
run_ak404() {
    prepare_run "Test de Estres Grafico (AK404.001)" || return 1
    run_guarded ./tserver '-d=gpu.*' -test=ak404.001      # comillas: evita glob
    finish_run $?
}
run_stress() {
    prepare_run "Stress Test Post-Reparacion (NAVI23_STRESS)" || return 1
    force_clocks_max
    run_guarded ./tserver -boardtest=navi23_stress
    finish_run $?
}
run_chkfp() {
    prepare_run "Check FP (CHKFP)" || return 1
    run_guarded ./tserver -boardtest=chkfp -rmdriver
    finish_run $?
}
run_quick() {
    prepare_run "Quick Manufacturing (QUICKMFG4)" || return 1
    run_guarded ./tserver -boardtest=quickmfg4 -nobamaco -noctf
    finish_run $?
}

# full_stage "<etiqueta>" <force 0|1> <cmd...>   -> rc final en STAGE_RC
full_stage() {
    local tag="$1" force="$2" rc prc
    shift 2
    echo "$tag"
    archive_and_clean_runtime || return 1          # log.txt/errorid.tmp frescos por etapa
    perl "$ENGINE" --validate || { echo "[CRÍTICO] Validación fallida en $tag. Abortando suite."; return 1; }
    if [ "$force" -eq 1 ]; then force_clocks_max; fi
    run_guarded "$@"
    rc=$?
    perl "$ENGINE" --parse "$rc"
    prc=$?
    [ "$rc" -eq 0 ] && rc=$prc
    STAGE_RC=$rc
}

run_full() {
    local rc_train=0 rc_memfa=0 rc_chan=0 rc_stress=0
    STAGE_RC=0
    archive_existing_logs || return 1
    sync_profile || return 1
    print_header
    echo "=== SUITE COMPLETA AUTOMATICA ==="
    full_stage "[1/4] Training" 0 ./memtune trainingcheck              || return 1; rc_train=$STAGE_RC
    full_stage "[2/4] MEMFA"    1 ./tserver -boardtest=NAVI23_MEMFA    || return 1; rc_memfa=$STAGE_RC
    full_stage "[3/4] CHANNELS" 1 ./tserver -boardtest=navi23_channels || return 1; rc_chan=$STAGE_RC
    full_stage "[4/4] STRESS"   1 ./tserver -boardtest=navi23_stress   || return 1; rc_stress=$STAGE_RC
    perl "$ENGINE" --master-summary "$rc_train,$rc_memfa,$rc_chan,$rc_stress"
    echo "=== SUITE FINALIZADA. Revisa test_logs/ y el informe maestro consolidado. ==="
}

view_logs() {
    local logs sorted_logs opt PS3
    clear
    echo "=== Ultimos Reportes en test_logs/ ==="
    shopt -s nullglob
    logs=(test_logs/*.log)
    shopt -u nullglob
    if [ ${#logs[@]} -eq 0 ]; then
        echo "No hay reportes disponibles aun."
        return
    fi
    mapfile -t sorted_logs < <(ls -t -- "${logs[@]}")
    PS3="Selecciona un log para abrir (presiona Enter para ver lista, 0 para salir): "
    select opt in "${sorted_logs[@]}"; do
        if [ -n "$opt" ]; then
            less -- "$opt"
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
  restore     Restaura DPM/ppmode de la GPU (usar tras un kill -9 / corte del host)
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
    restore) restore_clocks_safe ;;
    menu) menu ;;
    -h|--help|help) usage ;;
    *) echo "Opcion desconocida: $1"; usage; exit 1 ;;
esac
