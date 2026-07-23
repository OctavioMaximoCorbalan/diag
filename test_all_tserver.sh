#!/bin/bash

# Script de prueba de logs de tserver
LOG_DIR="./test_logs"
mkdir -p "$LOG_DIR"

# Lista de tests que quieres probar
TESTS=("memfa" "ak404.001" "quickmfg" "quickmfg4" "chkfp")

echo "=== Directorio actual ==="
pwd
echo

# Verificar permisos de escritura
if [ ! -w "." ]; then
    echo "ERROR: No hay permisos de escritura en el directorio actual."
    exit 1
fi

# Iterar sobre los tests
for test in "${TESTS[@]}"; do
    echo "Ejecutando tserver con test: $test..."
    
    # Crear carpeta para cada test
    TEST_LOG_DIR="$LOG_DIR/$test"
    mkdir -p "$TEST_LOG_DIR"
    
    # Ejecutar tserver y redirigir logs
    ./tserver -boardtest="$test" -logdir="$TEST_LOG_DIR"
    
    sleep 2  # esperar que genere archivos
    
    # Comprobar si se generó algún archivo
    if [ "$(ls -A "$TEST_LOG_DIR" 2>/dev/null)" ]; then
        echo "✅ Log generado para $test en $TEST_LOG_DIR"
    else
        echo "❌ No se generó log para $test"
    fi
    echo
done

echo "=== Prueba finalizada ==="
ls -lh "$LOG_DIR"
