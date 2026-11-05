# Conga 3890 · Laboratorio USB

Investigación técnica **no oficial** de la Cecotec Conga 3890 a través de USB (ADB), con especial atención a diagnóstico, comunicación entre procesos y telemetría. Objetivo: desarrollar métodos reproducibles **de solo lectura** antes de considerar operaciones de control.

> Estado: investigación experimental. No existe todavía una API de telemetría validada ni se ha obtenido una lectura en tiempo real de batería o LiDAR.

## Estado verificado (2026-11-05)

| Área | Resultado |
| --- | --- |
| Windows 11 → USB | Dispositivo reconocido por ADB (`device`) |
| Shell Linux | Sesión interactiva de Tina Linux con autenticación; BusyBox `ash` |
| Sistema | Tina Linux Neptune, basado en OpenWrt, kernel Linux 3.4.39, ARMv7 (4 núcleos), 512 MiB RAM |
| Firmware base | `tina.robotix.20200831.194440` / `57513AA3` |
| Software | `RobotApp`, `AuxCtrl`, `everest-server` y `Monitor` identificados |
| USB → TCP del robot | **Verificado**: `adb forward` a TCP/22 entregó `SSH-2.0-dropbear_2015.71` |
| Consola interna | Biblioteca `libcli.so`, socket `/tmp/cliManager.sock`, prompt `Robot>` |
| Consulta de estado | Símbolos y mensajes encontrados; **protocolo todavía sin reconstruir** |
| Batería y sensores en vivo | **No conseguido todavía** |

## Laboratorio Clean Assistant (preparación segura)

- [Guía de instalación y pruebas aisladas](docs/laboratorio-clean-assistant.md).
- [Preparar simulador en Windows](scripts/preparar-clean-assistant-mock.ps1).
- [Arrancar simulador en localhost](scripts/ejecutar-clean-assistant-mock.ps1).
- [Comprobar API simulada](scripts/verificar-clean-assistant-mock.ps1).
- [Lector de batería real (solo cuando exista backend REAL configurado)](scripts/mostrar-bateria-clean-assistant.ps1).

**Importante:** el simulador no obtiene telemetría del robot. No se ha cambiado DNS ni firmware, y todavía no se ha leído el porcentaje real de la Conga 3890. La compatibilidad de Clean Assistant con nuestra unidad se verificará en una fase separada.

## Documentación

- [Bitácora de pruebas](docs/bitacora.md): resultados comprobados, fallos y próximos pasos.
- [Conexión USB con Windows 11](docs/usb-windows.md): procedimientos de diagnóstico y verificación del túnel.
- [Análisis estático](docs/analisis-estatico.md): ejecutables, mensajes, sockets y versiones.
- [Seguridad y publicación](docs/seguridad.md): prácticas de laboratorio y datos que no deben publicarse.

## Principios

1. Mantener el firmware original. No ejecutar herramientas de modificación, actualización o reinicio.
2. No enviar comandos desconocidos a motores, buses serie, sockets de control ni servicios internos.
3. Distinguir **hechos observados** de **hipótesis** y **objetivos pendientes**.
4. No publicar firmware, ejecutables propietarios, contraseñas, tokens, identificadores únicos del equipo, mapas domésticos ni registros sin anonimizar.
5. Mantener primero la vía USB; la investigación Wi-Fi queda para una fase posterior.

## Aviso

Proyecto independiente, sin vinculación ni soporte de Cecotec. Los procedimientos pueden diferir entre versiones de firmware.
