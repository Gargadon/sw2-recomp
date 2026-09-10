![SS2 Recompiled Logo](sw2-recomp-logo.png)

# Samurai Warriors 2 — ReXGlue

Proyecto de recompilación de **Samurai Warriors 2 (USA, Europe)** para Windows AMD64 con ReXGlue SDK **0.10.0**. Estado documentado al **9 de septiembre de 2026**.

El juego inicia y permite jugar stages. El usuario confirmó que los cierres durante el combate dejaron de ocurrir después de la corrección de eventos. Sigue pendiente un problema de respuesta de los controles, especialmente al correr y con muchos enemigos.

**No se ha parcheado el SDK de ReXGlue ni sus DLL originales.** Las correcciones y los diagnósticos están en este proyecto y se integran en el ejecutable recompilado mediante hooks. Los archivos extraídos del juego se utilizan como entrada.

## Compilar y ejecutar

La estructura esperada es:

```text
rexglue-sdk-win-amd64/
├── bin/
├── include/
├── lib/
├── Samurai Warriors 2 (USA, Europe)/
│   ├── default.xex
│   └── ...
└── sw2-recomp/
```

El entorno utilizado tiene Visual Studio 2026 Community con herramientas C++, LLVM/Clang, CMake y Ninja. Aunque se instaló clang-cl, el preset actual compila con `clang++`. `build.ps1` configura el entorno de Visual Studio desde `C:\Program Files\Microsoft Visual Studio\18\Community`; hay que ajustar esa ruta si la instalación es distinta.

Desde la carpeta raíz del SDK:

```powershell
.\sw2-recomp\build.ps1
.\sw2-recomp\run.ps1 --input_backend xinput
```

La compilación usa el preset `win-amd64-release`, optimización Release y cuatro trabajos paralelos. El ejecutable queda en `out/build/win-amd64-release/samurai_warriors_2.exe` dentro del proyecto. `run.ps1` configura la ruta de las DLL, la carpeta de datos del juego y el plugin `xenos`, y transmite los argumentos adicionales al ejecutable.

El arranque ahora solicita por defecto **ventana de 1280 × 720** mediante `--no-fullscreen`, **XInput** y nivel de registro **warn** (advertencias y errores). Para solicitar ventana explícitamente: `.\sw2-recomp\run.ps1 --no-fullscreen` desde la raíz del SDK. Las opciones explícitas sustituyen esos valores, por ejemplo `--fullscreen` o `--input_backend sdl`. Los booleanos se pasan como flags: `--fullscreen false` no es la forma de desactivar pantalla completa. XInput produjo una mejora parcial de respuesta según el usuario, pero el problema persiste. El tamaño de ventana no implica una reducción de la resolución interna ni una mejora de FPS comprobada.

El diagnóstico de controles está desactivado por defecto para evitar sus lecturas adicionales de memoria, mediciones de tiempo y mensajes durante cada actualización. Para reactivarlo temporalmente desde la raíz del SDK:

```powershell
$env:SW2_INPUT_DIAGNOSTICS = '1'
.\sw2-recomp\run.ps1 --log_level info
```

Para volver al modo normal, cerrar el juego y ejecutar `Remove-Item Env:SW2_INPUT_DIAGNOSTICS -ErrorAction SilentlyContinue` antes del siguiente arranque. El diagnóstico de memoria continúa siendo opcional mediante su variable independiente. La corrección de eventos sigue activa. Estos ajustes reducen el trabajo de diagnóstico; no son una corrección del Musou ni tienen todavía una ganancia de rendimiento medida.

## Cambios realizados

### Arranque y plugin gráfico

- Se añadieron `build.ps1` y `run.ps1` para preparar la compilación y el arranque local.
- `CMakeLists.txt` utiliza `rexglue_setup_target(... GPU_PLUGINS xenos)` para colocar el plugin junto al ejecutable. Esto corrigió el error `failed to load gpu plugin xenos`; añadir solamente el directorio del SDK al PATH no bastaba.
- Se registraron las entradas `0x82351E20`, `0x82468758` y `0x8235B7F0` en `samurai_warriors_2_config.toml`, tras observar llamadas indirectas a funciones no registradas durante el arranque. Se regeneró el código a partir del juego.
- Se habilitó la generación del archivo `.map` del ejecutable en Windows para relacionar direcciones de los volcados de error con funciones recompiladas.

### Corrección del cierre durante los stages

El juego se cerraba pocos segundos después de iniciar un stage, con Yukimura y otros personajes. Los registros y un volcado de Windows situaron el fallo en operaciones de liberación de memoria ejecutadas desde un hilo de limpieza de audio.

La función del juego `sub_82349710` limpia un evento escribiendo cero en el `SignalState` de memoria invitada. ReXGlue mantiene además un evento del sistema anfitrión; esa escritura por sí sola lo deja señalado. Esto permitía repetir la limpieza del objeto de audio y acceder a memoria ya liberada.

Se añadió un hook en `0x82349714`, después de la escritura original, que llama a `sw2_clear_host_event` en `src/event_fix.cpp`. La función obtiene el `XEvent` correspondiente y llama a `Clear()` para sincronizar el evento anfitrión. Se conservan las instrucciones originales; no se omiten liberaciones de memoria.

Validación realizada:

- Compilación Release completada.
- `tests/event_reset_test.cpp`, enlazado con el SDK instalado, reprodujo el evento anfitrión todavía señalado después de limpiar únicamente la memoria invitada, comprobó la corrección mediante `Clear()` y pasó 100 ciclos de señalización y limpieza.
- El usuario confirmó posteriormente que el juego ya no se cerraba. También se observaron sesiones prolongadas terminadas con un cierre normal de ventana. Esto no garantiza que estén descartados todos los posibles fallos del juego.

La investigación original está en [crash-investigation.md](crash-investigation.md). Su apartado de validación refleja un momento anterior a la confirmación del usuario; el estado actualizado se recoge aquí.

### Diagnósticos de memoria

`src/heap_diagnostics.cpp` observa inserciones en listas libres y operaciones de asignación/liberación mediante hooks en `0x8231D22C`, `0x8231D328`, `0x8231AFC8` y `0x8231AFD8`.

El seguimiento permitió identificar una liberación de un puntero interior perteneciente a una asignación ya liberada. Se conserva para futuras investigaciones, pero **está desactivado por defecto** para evitar el coste de seguimiento con mutex y mapas durante el juego.

Para activarlo temporalmente desde la raíz del SDK:

```powershell
$env:SW2_HEAP_DIAGNOSTICS = '1'
.\sw2-recomp\run.ps1 --input_backend xinput
```

Para desactivarlo en esa consola antes del siguiente arranque:

```powershell
Remove-Item Env:SW2_HEAP_DIAGNOSTICS -ErrorAction SilentlyContinue
```

Los archivos `heap-diagnostics.txt` y `allocation-diagnostics.txt` se escriben al detectar las condiciones anómalas contempladas por el diagnóstico.

### Diagnóstico de controles

`src/input_diagnostics.cpp` observa el estado del jugador cero mediante un hook en `0x820FC38C`, después de que el juego almacene el estado actual de botones. Registra cambios de LB/B, nuevas pulsaciones, intervalos entre lecturas, errores y un resumen cada cinco segundos. **No remapea, inyecta ni almacena pulsaciones para ejecutarlas más tarde.**

En `out/build/win-amd64-release/logs/samurai_warriors_2_014.log` se observaron:

- 203 pulsaciones nuevas de LB y 73 de B registradas por el diagnóstico.
- Cero errores de lectura en los resúmenes registrados.
- Tramos de aproximadamente 40–45 lecturas por segundo frente a otros de 60.
- Tres intervalos sin lecturas de aproximadamente un segundo. No se ha establecido si coincidieron con combate o transiciones.

Estas medidas describen la frecuencia con la que el juego lee el mando, **no los FPS ni el tiempo desde la pulsación física hasta la acción**. Tampoco permiten asegurar que se hayan capturado todas las pulsaciones físicas.

## Problema pendiente: LB y Musou

El usuario reporta que, especialmente con muchos enemigos, LB no permite recuperarse rápidamente y B requiere varias pulsaciones para ejecutar Musou, aunque la imagen parece fluida.

La pista más reciente es reproducible: **B no ejecuta Musou mientras se mantiene el stick para correr; al soltar el stick y pulsar B de nuevo, Musou sale inmediatamente.**

La rutina de lectura revisada guarda los ejes del stick y los botones por separado y no elimina B por mover el stick. Todavía no se ha rastreado la entrada hasta la decisión del personaje de ejecutar Musou. Las pausas de lectura encontradas no explican por sí solas la dependencia del movimiento.

No se ha aplicado una corrección para este problema ni un búfer de botones. El siguiente diagnóstico propuesto consiste en comparar B estando quieto y corriendo, con la barra de Musou llena, y seguir la pulsación hasta su consumo para comprobar si se pierde, se sobrescribe o una condición de la lógica del juego impide la acción. También queda pendiente identificar los cuellos de botella de rendimiento; aún no hay una mejora de FPS medida.

## Archivos principales

| Archivo o directorio | Función |
| --- | --- |
| `CMakeLists.txt` | Integra las fuentes adicionales, Xenos y el mapa del ejecutable. |
| `CMakePresets.json` | Presets de compilación; se ha utilizado Windows AMD64 Release. |
| `samurai_warriors_2_manifest.toml` | Rutas del juego, versión del SDK y configuración de generación. |
| `samurai_warriors_2_config.toml` | Entradas de funciones y hooks del proyecto. |
| `src/event_fix.cpp` | Corrección de sincronización de eventos. |
| `src/heap_diagnostics.cpp` | Seguimiento opcional de memoria. |
| `src/input_diagnostics.cpp` | Observación de lectura de controles. |
| `src/main.cpp`, `src/samurai_warriors_2_app.h` | Base de la aplicación generada. |
| `tests/` | Proyecto CMake independiente para la prueba de eventos. |
| `generated/` | Código generado y regenerado al incorporar entradas y hooks. |
| `out/` | Compilaciones, ejecutable, dependencias copiadas y registros locales. |

Este documento registra los cambios conocidos durante la preparación y depuración local. No constituye una comparación exhaustiva contra una revisión inicial de Git.
