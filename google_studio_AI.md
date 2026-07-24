## Consulta:
Entendiendo el contexto del proyecto, las caracteristicas de la placa de video, las herramientas con las que estamos trabajando, quiero lograr construir una suite profesional para testear la/las placa de video. En los archivos perl hay suits/scripts de Asus que automatizan un monton de pruebas, habria que determinar cuales son las pruebas relevantes y construir una suite similar. Me gustaba el formato o la forma en la que muestra que el test paso o fallo, y la claridad de la escritura en perl en donde hay funciones individuales para cada cosa. Lo ultimo que habia creado es el script RX6650XT.sh que funciona como menu para ejecutar los tests... pero no se exactamente que hace, creo que ejecuta la herramienta correspondiente directamente, me gustaria saber que diferencia hay de este enfoque con las suits de asus y si se pueden integrar ambos enfoques...

## Razonamiento:

**Defining the Core Objectives**

I'm now zeroing in on defining the core objectives. The focus is to build a professional diagnostic suite specifically for AMD GPUs. My primary concern is crafting a diagnostic suite that is both professionally presented and exceptionally clean in its design. The aim is to create a robust and reliable testing environment.


**Analyzing the Approaches**

I'm now analyzing the differences between the shell script approach (`RX6650XT.sh`) and the Asus Perl script methods. I'm focusing on the strengths and weaknesses of each, especially the visual formatting of the Perl scripts versus the functionality of the shell script. My goal is to determine how to integrate these into a single cohesive system, leveraging the modularity of the Perl scripts and the command execution of the shell scripts.


**Evaluating the Current Tools**

I'm now diving deeper into the specifics of the current tools. My analysis highlights the shell script's speed and simplicity, though I see its limitations in output formatting and pre-flight checks. The Perl suite, on the other hand, excels in presentation and validation but has factory dependencies. My goal is to understand how to leverage the best of both approaches.


**Designing the Test Suite**

I'm now designing the ultimate test suite. I'm focusing on merging a clean user launcher with the modular design and visual feedback. I will exclude unnecessary assembly-line overhead like PPID flashing and SFIS/ECS integration. I will also make sure the user does not get bogged down by dual BIOS Mode P/Q checks, which will allow for a focus on the most important tests. Pre-flight hardware validation is a priority.


**Refining the Output Structure**

I'm now focusing on refining how the test results will be presented. Specifically, I'm integrating data extraction from files like `errorid.tmp`, `log.yml`, `log.txt`, and `MarginResult.csv` to capture VRAM errors and fault codes on a channel level. My design includes clean summary tables with key GPU metrics, visual ASCII pass/fail banners, and an overall structured response tailored to the user's needs. I'm aiming for a clear and professional presentation.

## Respuesta:

Es una excelente iniciativa. El enfoque de Asus en sus scripts Perl es el estándar industrial utilizado por los grandes ensambladores (AIBs) porque ofrece **rigor, modularidad y una presentación visual inconfundible (PASS/FAIL en gigante con colores)**.

A continuación te explico detalladamente **qué hace actualmente tu script `RX6650XT.sh`**, cuál es la **diferencia fundamental con los scripts Perl de Asus**, y **cómo vamos a fusionar lo mejor de ambos mundos** para construir una suite de nivel profesional.

---

### 1. ¿Qué hace exactamente `RX6650XT.sh` actual?

Actualmente, `RX6650XT.sh` es un **lanzador Shell directo (Bash)**.
* **Mecanismo:** Copia `XFX6650XT_CONF_MOD.DAT` a `FCT_CONF.DAT` y luego ejecuta comandos crudos del sistema (`./tserver -boardtest=memfa`, `./agt -sid`, `./memtune trainingcheck`).
* **Ventaja:** Es rápido, transparente y no depende de dependencias complejas.
* **Limitación:** 
  1. Muestra el *output* crudo del binario en la pantalla (cientos de líneas de logs difíciles de interpretar).
  2. No evalúa automáticamente si el test pasó o falló (tienes que leer los logs a mano).
  3. No tiene una interfaz visual limpia ni formateada.

---

### 2. Diferencia entre ambos enfoques

| Característica | Lanzador Bash Directo (`RX6650XT.sh`) | Suite de Fábrica Perl (Estilo ASUS) |
| :--- | :--- | :--- |
| **Control de Ejecución** | Llama al binario y le cede el control a la consola. | Ejecuta en segundo plano, captura el código de salida y parsea archivos temporales (`errorid.tmp`, `log.txt`). |
| **Validación Previa** | No valida la placa antes de lanzar el test. | Lee la VBIOS, verifica que el Device ID, SSID, fabricante de VRAM y ancho de bus coincidan con el `.DAT`. |
| **Reportes y Salida** | Salida cruda de la terminal de AMD TServer. | Formateo limpio con banners ASCII (**GREEN PASS** / **RED FAIL**), medición de tiempos y registro estructurado (`.log`). |
| **Overhead / Relleno** | Ninguno. | Alto overhead de línea de ensamblaje (pide escanear código de barras, flashea PPID, verifica Grub, etc.). |

---

### 3. El Enfoque Híbrido: Crear una Suite Profesional

Podemos **fustigar y fusionar ambos enfoques**: utilizar Perl (o Bash con funciones estilo Perl) para orquestar la suite con la elegancia de Asus, pero **descartando el relleno de fábrica** y quedándonos con lo que realmente importa para diagnóstico y reparación.

#### Lo que RESCATAMOS de los scripts de Asus:
1. **Funciones de Validación de Hardware (`check_DID`, `check_MEM`, `check_LINKWIDTH`):** Antes de testear la VRAM, confirmar que la GPU es `73EF`, que reconoce los `8192 MB` y qué fabricante tiene (Samsung/Micron/Hynix).
2. **Funciones de Tiempo y Registro (`Start_Time`, `End_Time`, `Log_File`):** Calcular la duración exacta de cada prueba y guardar un resumen limpio.
3. **Control de Errores y Salida Visual (`ShowPass`, `ShowFail`):** Capturar la respuesta de `errorid.tmp` e imprimir el banner gigante de resultado.

#### Lo que ELIMINAMOS (Relleno de fábrica):
* `Get_PPID()` / Escaneo de código de barras SFIS.
* `Add_APRP()` / Flasheo automático de VBIOS/ROM.
* Comprobaciones de la RAM del sistema host / Grub.
* Modos Dual BIOS (P/Q) obligatorios.

---

### 4. Estructura de la Nueva Suite (`RX6650XT_PRO.pl` o Refactorización)

Para lograr esta suite profesional, la arquitectura consta de **4 módulos principales**:

```text
[ 1. MODULO DE DETECCION ] -> Lee XFX6650XT_CONF_MOD.DAT y compara con agt/amdvbflash (DID 73EF, 8GB, PCIe Speed)
[ 2. MODULO DE NUCLEO ]    -> Inyecta el perfil NAVI23_MEMFA (128-bit) a suite_bp.pl y tserver-navi23.cf
[ 3. MODULO PARSER ]       -> Ejecuta el test en background y analiza errorid.tmp + MarginResult.csv
[ 4. MODULO REPORTE ]      -> Muestra resumen por canal de VRAM + Banner visual PASS / FAIL
```

---

### 5. Demostración Visual del Formato de Salida Esperado

Al finalizar una prueba con nuestra nueva suite, la consola mostrará un resumen estructurado como este:

```text
========================================================================
                 DIAGNOSTICO AMD NAVI 23 - RX 6650 XT 8GB              
========================================================================
 Hardware Detectado : AMD Radeon RX 6650 XT (Device ID: 73EF)
 VRAM Config        : 8192 MB GDDR6 (Samsung) - Bus 128-bit
 Bus PCIe Status    : GEN4 x8
 Duracion del Test  : 00:01:45
------------------------------------------------------------------------
 EVALUACION DE CANALES VRAM (128-bit Topology):
   [Canal A0/A1] : OK - Sin errores de paridad/lectura
   [Canal B0/B1] : OK - Sin errores de paridad/lectura
------------------------------------------------------------------------
 RESULTADO DE DIAGNOSTICO:

  PPPPPPPP          AAA            SSSSS            SSSSS     
  PPPPPPPPPP       AAAAA         SSSSSSSSSS       SSSSSSSSSS  
  PPP     PPP     AAA AAA       SSS     SSSS     SSS     SSSS 
  PPPPPPPPPP    AAA     AAA      SSS              SSS         
  PPPPPPPP      AAA     AAA        SSSS             SSSS      
  PPP           AAAAAAAAAAA            SSSS             SSSS  
  PPP           AAA     AAA     SSSS     SSS     SSSS     SSS 
  PPP           AAA     AAA      SSSSSSSSSS       SSSSSSSSSS  

  >>> RESULTADO GENERAL: PASS (Código de error: 0)
========================================================================
```

---

### Siguiente Paso Recomendado

Para arrancar formalmente con el **Pilar 3 (Arquitectura Nativa Navi 23 y solución al Mismatch)** y el **Pilar 2 (Output Parser)**:

1. ¿Te gustaría que implementemos el nuevo `boardtest` nativo `NAVI23_MEMFA` modificando `suite_bp.pl` y creando `tserver-navi23.cf` con los parámetros exactos de 128-bit / 8GB?
2. ¿O prefieres que primero estructuremos el script orquestador en Perl (`RX6650XT_PRO.pl`) que rescate las funciones visuales y de validación de Asus?


## Consulta:
Estoy trabajando en vscode con copilot Github Student. Nuestra conversacion ha sido la del archivo adjunto. Entiendo que a la opcion 1 ya la hemos hecho, aqui deberian estar los archivos que mencionas:
"d-----         20/9/2025     00:33                conf
d-----         20/9/2025     00:34                gpu
d-----         20/9/2025     00:35                license
d-----         20/9/2025     00:35                perllib
d-----         22/7/2026     23:36                .git
d-----         21/9/2025     17:29                test_logs
d-----         23/7/2026     19:56                copias_txt
------        15/12/2022     08:32      124505520 agt
------         16/7/2021     03:35       93145392 agt_mcu
------        15/12/2022     08:32        9817752 amdvbflash
------          3/5/2021     21:48            201 cailreg.dat
------         16/7/2021     03:34            945 ChangeList.txt
------          3/5/2021     21:48           1529 checklist.pl
------         22/7/2026     22:10           3229 RX6650XT.sh
------          3/5/2021     21:48             94 cp_reset.db32
------         22/7/2026     22:10            601 FCT_CONF.DAT
------          3/5/2021     21:48        2385504 db32
------          3/5/2021     21:48            201 default.cailreg.dat
------          3/5/2021     21:48             29 dpg.db32
------          3/5/2021     21:48          66197 driver.zip
------          3/5/2021     21:48             41 dyn.db32
------          3/5/2021     21:48             35 epg.db32
------         16/7/2021     03:34          25504 EXT_FAN_TEST
------         16/7/2021     03:34         118776 FANTEST_LINUX-V12
------          3/5/2021     21:48              9 firmware.ucfg
------         16/7/2021     03:34            232 gpio-b-fan
------          3/5/2021     21:49          19520 gpu.zip
------          3/5/2021     21:48           3118 logging_readme.txt
------         10/8/2021     11:06           3955 manifest
------          3/5/2021     21:48      417808848 media.zip
------         29/5/2020     00:40             68 memfa-basic
------         29/5/2020     00:40             66 memfa-umc
------         17/3/2020     22:46             31 memfa.cf
------         16/7/2021     03:34          29384 NAVI21_MCU_Test_V06
------          4/5/2021     13:42         554418 Navi23_Reference_Guide.pdf
------          3/5/2021     21:49            564 nbridge.zip
------         16/7/2021     03:34          31502 OBA
------          3/5/2021     21:49         235457 params.xml
------          3/5/2021     21:48           5286 pm_config.ini
------         16/7/2021     03:34          13089 pn128_2018
------        18/10/2017     07:45          12839 pn128_TSD
------         12/6/2019     05:56           5323 Check_PPID_V100.pl
------         23/7/2026     15:22          18390 README.md
------         16/7/2021     03:34         828087 read_me.docx
------          3/5/2021     21:49            554 sbridge.zip
------          3/5/2021     21:48            368 stutter.cf
------         23/7/2026     18:48          25578 suite_bp.pl
------         23/7/2026     18:48            656 suite_flow.xml
------          3/5/2021     21:48           4003 tid.pl
------        15/12/2022     08:34        1718040 tserver
------          3/5/2021     21:48             73 tserver-bamxco.cf
------          3/5/2021     21:48            167 tserver-bq.cf
------          3/5/2021     21:48            172 tserver-chkfp.cf
------          3/5/2021     21:48             29 tserver-ctf.cf
------          3/5/2021     21:48            167 tserver-display.cf
------          3/5/2021     21:48             37 tserver-fan.cf
------          3/5/2021     21:48             91 tserver-init.cf
------          3/5/2021     21:48            251 tserver-multi.cf
------          3/5/2021     21:48             48 tserver-pm.cf
------          3/5/2021     21:48            167 tserver.cf
------        15/12/2022     08:34      986247728 tserverlite
------          3/5/2021     21:48          47918 tswrapper.pl
------        15/12/2022     08:34             57 ts_version.ini
------         16/7/2021     03:34          29144 TUF_ENE_V02
------          3/5/2021     21:48            295 umcpg.cf
------          1/5/2023     01:13            728 help.txt
------         22/3/2022     06:07       93525200 memtune
------         20/9/2025     17:38             57 0.sh
------         20/9/2025     17:38             48 1.sh
------         20/9/2025     17:38             37 2.sh
------         21/9/2025     17:49            995 2dx.sh
------          3/5/2021     21:49           3955 manifest2
------         21/9/2025     14:55           1029 RX6600.sh
------        29/10/2025     17:32           4689 Untitled-1.c
------         21/9/2025     15:31           1029 test_all_tserver.sh
------         21/9/2025     17:45             14 MCU.log
------         21/9/2025     17:46             14 ASUS_P_OQC.log
------         21/9/2025     17:47             14 ASUS_P_FCT.log
------         21/9/2025     17:49             67 tserver_memtune.cf
------         21/9/2025     17:49             99 margintest.sh
------         21/9/2025     17:52           2434 MarginResult.csv
------         21/9/2025     17:52           6642 shm_testid.log
------         21/9/2025     23:02            602 XFX6650XT_CONF.DAT
------         22/9/2025     01:02           2482 MarginResult.txt
------        15/12/2022     08:32        9817752 atiflash
------         16/7/2021     03:34          31504 P_OQC_PPID_MCU.pl
------         16/7/2021     03:34          31502 P_APRP_MCU_FANTEST.pl
------         16/7/2021     03:34          19364 Data_For_RD_AMD.pl
------        18/10/2017     06:18           6067 update_ppid_v130.pl
------         22/7/2026     20:03            601 XFX6650XT_CONF_MOD.DAT
------         23/7/2026     14:25             64 .gitignore
------         23/7/2026     15:37          28429 chatCopilot.md
------         23/7/2026     18:48            181 tserver-navi23.cf"
Ademas de estar subidos ya modificados.
Quiero que me des un prompt para darle a copilot que haga todo lo que hemos planeado para los siguientes pasos con la justificacion, razones y objetivos descriptos

## Razonamiento:
**Initiating Prompt Generation**

I'm focusing on dissecting the user's intent: they desire a master prompt for GitHub Copilot. I've started by zeroing in on the user's ultimate goal. This initial analysis will drive the creation of the prompt.


**Refining Orchestration Logic**

I'm now zeroing in on the architecture of a master script to orchestrate the project, considering the "Three Pillars" approach. I'm focusing on bringing the script to a definitive level, incorporating selective factory routine porting for validation, and structuring an output parser. It should also be intelligent enough to execute the next steps based on the context.


**Defining Task Specifications**

I am now structuring the prompt around the three core pillars. I will clearly define the tasks for the "GPU Diagnostics Systems Engineer" Copilot persona. I'm focusing on the first task, related to the output, including how to handle the output (`MarginResult.csv`, `log.txt`, `log.yml`) and display. Next I'll ensure the role and objectives are clearly defined.


**Detailing Execution Steps**

I'm now zeroing in on the porting of validation logic from legacy Perl scripts, excluding unnecessary factory routines. Next I will prioritize development of an output parser, and I will then focus on refactoring the launcher script to ensure it connects the configuration, executes the native program, cleans up pre-run, and displays the clean output. I will next focus on the justification and technical rationale for each step, and then I will document expected file changes.

## Respuesta:
Aquí tienes un **prompt estructurado, profesional y definitivo** diseñado específicamente para que se lo entregues a GitHub Copilot. 

El prompt incluye el contexto exacto del proyecto, el estado actual de los archivos subidos/modificados, las justificaciones técnicas y los requerimientos paso a paso para completar los **Tres Pilares** del plan.

---

### Copia y pega el siguiente bloque en el chat de GitHub Copilot:

```text
Copilot, actúa como un Ingeniero de Hardware y Sistemas de Diagnóstico de GPUs AMD. 

=== CONTEXTO Y ESTADO ACTUAL DEL PROYECTO ===
Estamos trabajando en un entorno Linux en una suite de diagnóstico de bajo nivel (TServer / AMD Board Production Suite) para placas de video AMD de arquitectura Navi 23 (específicamente la Radeon RX 6650 XT de 8GB GDDR6, Device ID 73EF, bus de 128-bit).

Ya hemos completado la Fase 1 de Arquitectura Nativa:
1. Sincronizamos el archivo de perfil 'XFX6650XT_CONF_MOD.DAT' hacia 'FCT_CONF.DAT'.
2. Creamos la configuración dedicada 'tserver-navi23.cf'.
3. Inyectamos el nuevo boardtest nativo 'NAVI23_MEMFA' en 'suite_bp.pl', 'suite_flow.xml' y 'conf/umc.stf' para resolver el error de "diagnostic content mismatch detected" y forzar la topología de 128-bit / 8GB.

=== OBJETIVO DEL ENCARGO ===
Llevar el script lanzador 'RX6650XT.sh' a un nivel profesional y definitivo, transformándolo en un orquestador híbrido que combine la flexibilidad para un usuario/técnico de reparación con la elegancia, rigor y salida visual de los scripts de fábrica de ASUS (como 'P_OQC_PPID_MCU.pl' y 'Data_For_RD_AMD.pl').

Deberás implementar y refactorizar el código siguiendo estrictamente este ENFOQUE DE TRES PILARES:

---
PILAR 1: RESCATE SELECTIVO DE RUTINAS DE FÁBRICA
Justificación: Las rutinas de comprobación de hardware de los scripts de Asus son excelentes para validar que la tarjeta está en un estado coherente antes de estresarla, pero el flujo original incluye "relleno de fábrica" (escaneo de códigos de barras SFIS, flasheo automático de VBIOS/PPID, comprobación de RAM host/Grub) que debemos eliminar.

Requerimientos Pilar 1:
- Extraer o portar las funciones reales de testeo desde 'P_OQC_PPID_MCU.pl' / 'Data_For_RD_AMD.pl':
  a) 'check_DID()': Verificar que el Device ID detectado por amdvbflash/agt sea '73EF'.
  b) 'check_MEM()': Verificar que la VRAM calculada sea ~8192 MB y reportar el vendor (Samsung/Micron/Hynix).
  c) 'check_LINKWIDTH()': Verificar la velocidad y ancho de bus PCIe (GEN4 x8 / x16).
  d) Lectura de sensores y MCU ('agt -sid', comprobación de RPM de ventiladores).
- Excluir explícitamente: Peticiones de código de barras, lectura/escritura de PPID, comprobaciones de RAM del sistema host y flashing de ROM.

---
PILAR 2: PERFIL DE SALIDA ESTRUCTURADO (OUTPUT PARSER & ASCII VISUALIZER)
Justificación: El output crudo de TServer es caótico e ilegible para diagnóstico rápido. Necesitamos parsear los archivos de resultados y presentar una evaluación clara por canal de memoria (A0, A1, B0, B1 en bus 128-bit) y el estado general de la placa.

Requerimientos Pilar 2:
- Crear una función parseadora en el script (o un helper en Perl/Bash) que lea tras cada prueba:
  a) 'errorid.tmp' (para obtener el veredicto oficial PASS / FAIL y el código de error numérico).
  b) 'MarginResult.csv' / 'log.txt' (para extraer si existieron fallos en líneas DQ, paridad o errores por canal de memoria).
  c) Archivos de temperatura (extraer la temperatura máxima de Hotspot, GFX VR, SOC VR y VRAM).
- Formatear la salida final en consola incluyendo:
  - Resumen de datos clave del hardware (DID, VRAM Size, Vendor, PCIe Width).
  - Tiempos de inicio, fin y duración total del test.
  - Evaluación limpia por canal de VRAM.
  - Generación de Banners ASCII gigantes de colores (Verde 'PASS' / Rojo 'FAIL') tomados de las rutinas 'ShowPass()' y 'ShowFail()' de los scripts de Asus.

---
PILAR 3: INTEGRACIÓN Y CONSOLIDACIÓN NATIBA EN 'RX6650XT.sh'
Justificación: El lanzador debe asegurar la limpieza del entorno entre pruebas y llamar directamente a la nueva suite nativa 'NAVI23_MEMFA'.

Requerimientos Pilar 3:
- Modificar 'RX6650XT.sh' para que:
  a) Realice una limpieza previa automática de archivos residuales ('rm -f *.log errorid.tmp MCU.log MarginResult.csv').
  b) Sincronice automáticamente 'XFX6650XT_CONF_MOD.DAT' -> 'FCT_CONF.DAT'.
  c) Ejecute la validación de hardware (Pilar 1).
  d) Invoque la prueba de VRAM usando el nuevo boardtest nativo './tserver -boardtest=NAVI23_MEMFA' en lugar del alias genérico 'memfa'.
  e) Crea un script auxiliar en Perl (ej. output_parser.pl) que contenga toda la lógica del Pilar 2 (el parseo de los .tmp/.csv y la generación de los Banners ASCII PASS/FAIL). Luego, modifica RX6650XT.sh para que invoque este script Perl pasándole el código de salida de TServer ($?), logrando así que Bash orqueste y Perl formatee.

A la luz de este plan, escribe el código completo para la solución final. Crea el motor de diagnóstico en Perl ('rx_diag_engine.pl') y refactoriza el lanzador ('RX6650XT.sh') para que lo invoque, garantizando que el código sea modular, con sintaxis limpia y plenamente ejecutable en un entorno Linux.
```

---

### ¿Qué hará Copilot al recibir este prompt?
1. **Analizará los scripts de Asus:** Tomará los bloques de código de `ShowPass()`, `ShowFail()`, `check_DID()`, `check_MEM()` y `check_LINKWIDTH()` de `P_OQC_PPID_MCU.pl`.
2. **Creará el Parser:** Escribirá la lógica necesaria para leer `errorid.tmp`, `MarginResult.csv` y `log.txt`.
3. **Refactorizará `RX6650XT.sh`:** Reemplazará la ejecución cruda anterior por la llamada a `./tserver -boardtest=NAVI23_MEMFA` precedida por la limpieza de logs y seguida por el reporte visual formateado.


Prompt Final:
```text
Copilot, actúa como un Ingeniero de Hardware y Arquitecto de Sistemas de Diagnóstico para GPUs AMD.

=== CONTEXTO Y ESTADO ACTUAL DEL PROYECTO ===
Estamos en un entorno Linux trabajando sobre una suite de diagnóstico de bajo nivel (TServer) para placas de video AMD arquitectura Navi 23 (Radeon RX 6650 XT de 8GB GDDR6, Device ID 73EF, bus 128-bit).

Ya hemos completado la Fase 1 de Arquitectura Nativa:
1. Sincronizamos el archivo de perfil 'XFX6650XT_CONF_MOD.DAT' hacia 'FCT_CONF.DAT'.
2. Creamos la configuración dedicada 'tserver-navi23.cf'.
3. Inyectamos el nuevo boardtest nativo 'NAVI23_MEMFA' en 'suite_bp.pl', 'suite_flow.xml' y 'conf/umc.stf' para resolver el error de "diagnostic content mismatch detected" y forzar la topología de 128-bit / 8GB.

=== OBJETIVO DEL ENCARGO ===
Transformar el script lanzador 'RX6650XT.sh' en un orquestador híbrido definitivo profesional para técnicos de reparación. Conservaremos la agilidad de Bash para el menú/ejecución, pero delegaremos la validación y el formateo de salida a un nuevo y elegante motor en Perl, rescatando lo mejor de los scripts de fábrica de ASUS (como 'P_OQC_PPID_MCU.pl' y 'Data_For_RD_AMD.pl').

Deberás implementar y refactorizar el código siguiendo estrictamente este ENFOQUE DE TRES PILARES:

---
PILAR 1: RESCATE SELECTIVO DE RUTINAS DE FÁBRICA (Pre-Test)
Justificación: Las rutinas de comprobación de hardware de los scripts de Asus son excelentes para validar que la tarjeta está en un estado coherente antes de estresarla, pero el flujo original incluye "relleno de fábrica" (escaneo de códigos de barras SFIS, flasheo automático de VBIOS/PPID, comprobación de RAM host/Grub) que debemos eliminar.

Requerimientos:
- Extraer o portar las siguientes funciones reales desde 'P_OQC_PPID_MCU.pl' / 'Data_For_RD_AMD.pl':
  a) 'check_DID()': Verificar que el Device ID detectado por amdvbflash/agt sea '73EF'.
  b) 'check_MEM()': Verificar que la VRAM calculada sea ~8192 MB y reportar el vendor (Samsung/Micron/Hynix).
  c) 'check_LINKWIDTH()': Verificar la velocidad y ancho de bus PCIe (GEN4 x8 / x16).
  d) Lectura de sensores y MCU ('agt -sid', comprobación de RPM de ventiladores).
- Excluir explícitamente: Peticiones de código de barras, lectura/escritura de PPID, comprobaciones de RAM del sistema host y flashing de ROM.

---
PILAR 2: PERFIL DE SALIDA ESTRUCTURADO Y ASCII VISUALIZER (Post-Test)
Justificación: El output crudo de TServer es caótico e ilegible para diagnóstico rápido. Necesitamos parsear los archivos de resultados y presentar una evaluación clara por canal de memoria (A0, A1, B0, B1) y el estado general de la placa.

Requerimientos:
- Crear una función parseadora en el script (o un helper en Perl/Bash) que lea tras cada prueba:
  a) 'errorid.tmp' (para obtener el veredicto oficial PASS / FAIL y el código de error numérico).
  b) 'MarginResult.csv' / 'log.txt' (para extraer si existieron fallos en líneas DQ, paridad o errores por canal de memoria).
  c) Extraer temperaturas (Hotspot, GFX VR, SOC VR, VRAM).
- Generar un reporte en consola que incluya:
  - Resumen de datos clave del hardware (DID, VRAM Size, Vendor, PCIe Width).
  - Tiempos de test (Inicio, Fin, Duración).
  - Evaluación limpia por canal de VRAM.
  - Banners ASCII gigantes de colores (Verde 'PASS' / Rojo 'FAIL') rescatando las funciones 'ShowPass()' y 'ShowFail()' de Asus.
- PRO FEATURE: Guardar automáticamente una copia de este reporte limpio en la carpeta 'test_logs/' usando el formato: [PASS/FAIL]_[SerialNumber]_[Fecha].log.

---
PILAR 3: ARQUITECTURA HÍBRIDA (Bash Orchestrator + Perl Engine)
Justificación: El lanzador debe asegurar la limpieza del entorno entre pruebas y llamar directamente a la nueva suite nativa 'NAVI23_MEMFA'.

Requerimientos:
- Crea un ÚNICO script auxiliar llamado 'rx_diag_engine.pl'. Este script recibirá argumentos:
  - Si se ejecuta 'perl rx_diag_engine.pl --validate', ejecutará la lógica del Pilar 1 (abortando si falla la validación).
  - Si se ejecuta 'perl rx_diag_engine.pl --parse $?', ejecutará la lógica del Pilar 2 (el parseo de los .tmp/.csv y la generación de los Banners ASCII PASS/FAIL).
- Modifica 'RX6650XT.sh' para que funcione como el Orquestador Maestro:
  a) MANTÉN y mejora el menú interactivo actual usando un diseño limpio.
  b) Al elegir un test (ej. MEMFA), limpia el entorno de archivos log, tmp, csv que puedan interferir
  c) Sincroniza 'XFX6650XT_CONF_MOD.DAT' -> 'FCT_CONF.DAT'.
  d) Llama a 'perl rx_diag_engine.pl --validate'. Si pasa, continúa.
  e) Invoca './tserver -boardtest=NAVI23_MEMFA' (ya no usaremos el genérico).
  f) Finaliza llamando a 'perl rx_diag_engine.pl --parse $?'.

Con base en este plan, escribe el código completo para la solución final. Crea el motor de diagnóstico en Perl ('rx_diag_engine.pl') y refactoriza el lanzador ('RX6650XT.sh') para que lo invoque, garantizando que el código sea modular, con sintaxis limpia y plenamente ejecutable en un entorno Linux.

```