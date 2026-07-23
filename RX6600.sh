#!/bin/bash
#MS-V249 Test Program  caicos-nogb

# Si $barcode no está definido, poner un valor por defecto
: "${barcode:=UNDEF_BARCODE}"

# Limpiar archivos antiguos
rm -f errorid.tmp log.txt

# Ejecutar scripts de diagnóstico
./0.sh
if [ $? -eq 0 ]; then
    ./2.sh
    ./agt -sid >1.txt
else
    echo "diag test fail"
    echo "diag test fail"
fi

# Subir logs / permisos
[ -f "log.txt" ] && chmod 777 log.txt
[ -f "errorid.tmp" ] && chmod 777 errorid.tmp
[ -f "log.txt" ] && cp log.txt "$barcode.txt" -f
[ -f "errorid.tmp" ] && cp errorid.tmp ID.txt
[ -f "$barcode" ] && chmod 777 "$barcode.txt"

# Verificar si pasó el test
if [ -f "errorid.tmp" ]; then
    grep "PASS" errorid.tmp
    if [ $? -eq 0 ]; then
        echo "Test passed!"
        [ -f ID.txt ] && cat ID.txt
    else
        echo "Test failed!!"
        [ -f ID.txt ] && cat ID.txt
    fi
else
    echo "No se encontró errorid.tmp, test no ejecutado."
fi

# Pausa visual antes de volver al menú
sleep 3s

# Volver al menú de RX6600
cd ..
./menu_rx6600.sh
