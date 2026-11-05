# Precedentes y hoja de ruta — Cecotec Conga 3890

Revisión de fuentes públicas realizada el **2026-11-05**. Distinguir **demostrado en otro modelo**, **declarado compatible con 3890 por terceros** y **pendiente de validar en nuestra unidad**. No confundir interfaces sustitutas con mejoras físicas de rendimiento.

## 1. Precedentes contrastados

| Proyecto | Dispositivos / ámbito | Logros documentados | Estado para nuestra 3890 |
| --- | --- | --- | --- |
| [Valetudo](https://valetudo.cloud/pages/general/supported-robots/) | Conga 3290 y 3790 | Con una conversión de firmware a Viomi V6 sobre hardware CRL-200S se permite control local y mapas; lista oficial restrictiva | **No soportada**; no flashear firmware de otros modelos |
| [Congatudo](https://github.com/congatudo/Congatudo) | Familias 3XXX/4XXX y algunas 5XXX | Sustitución de la nube por servidor propio, web local e integraciones; no cambia los algoritmos internos de limpieza | **3890 excluida** de compatibilidad probada |
| [Agnoc](https://github.com/congatudo/agnoc) | 3090, 3490, 4090 | Driver de ingeniería inversa para leer estado y controlar modelos ensayados | 3890 **no incluida** entre modelos probados |
| [Clean Assistant](https://github.com/miguelsg29/clean-assistant) | Validación integral en 8090 Ultra; otros modelos según usuarios | Sustitución local de servicios de nube; web con mapa, habitaciones, zonas, horarios, MQTT / Home Assistant | El mantenedor declara **3890 confirmada por un usuario**; alcance y compatibilidad con nuestro firmware **sin validar** |
| [OpenDoñita](https://gitlab.com/rastersoft/opendonita) | Conga 1490/1590 | Servidor alternativo, aplicación de control y, tras ingeniería inversa, desplazamiento manual | Otra plataforma/protocolo: solo evidencia del enfoque |
| [Personalización de voz](https://congatudo.cloud/misc/empower-your-conga-voice/) | Guía probada en Conga 4090 | Cambio de audio / locuciones mediante archivos y configuración | **No demostrada en 3890**; no escribir sin respaldo/restauración |
| [Incidencia Congatudo/Agnoc #40](https://github.com/congatudo/agnoc/issues/40) | Conga 3890 (2022) | Acceso SSH y análisis de conectividad; la integración dio error de longitud de paquete, sugerente de protocolo diferente | Antecedente **directo**, pero la implementación allí no quedó demostrada funcional |

### Matices

- **Control local ≠ firmware personalizado ≠ mejora de navegación.** Un frontal alternativo sustituye la interfaz y la nube; no hace automáticamente que el robot limpie mejor.
- La compatibilidad declarada de 3890 con Clean Assistant **no equivale** a afirmar que cada función funciona con este firmware. Debe medirse funcionalidad por funcionalidad.
- No trasladar métodos de flasheo para Conga 3290/3790 a 3890: un error puede inutilizar el equipo.

## 2. Capacidades confirmadas en nuestro equipo

- ADB USB funcional, shell Tina Linux autenticada, acceso administrativo y firmware identificado.
- Ejecutables `RobotApp`, `AuxCtrl`, `everest-server`, `Monitor` y `libcli.so` extraídos **solo como muestras locales**, analizados offline.
- Existencia de rutinas de batería, LiDAR, IMU y odometría; sockets UNIX locales y mensajes `DEVICE_STATUS_GETTING_REQ/RSP` identificados en binarios.
- Túnel `adb forward tcp:16691 tcp:22` probado: banner real `SSH-2.0-dropbear_2015.71`.
- Conexión a `/tmp/cliManager.sock` cerrada sin banner: protocolo y negociación sin determinar.
- **Ninguna lectura de batería, datos LiDAR o movimiento controlado por nuestra herramienta validado aún.**

## 3. Hoja de ruta propuesta (valor / riesgo)

| Prioridad | Mejora propuesta | Viabilidad preliminar | Riesgo | Criterio de aceptación |
| --- | --- | --- | --- | --- |
| P0 | Procedimientos de comunicación USB y registro reproducible | **Confirmada parcialmente** | Bajo | Diagnóstico y conexiones instrumentados sin efectos secundarios |
| P1 | Telemetría (batería, carga, modo, errores) en vivo por USB | **Probable**, protocolo pendiente | Bajo/medio | Valores contrastados con estado que muestra la app/robot |
| P2 | Extraer y visualizar mapas y posición | **Plausible**, formatos pendientes | Bajo/medio | Decodificación correcta y sin datos personales en repositorio |
| P3 | Panel propio Windows / web, diagnóstico de sensores, informes y logs | **Plausible** sobre telemetría disponible | Bajo/medio | Dashboard mostrando estados reales de una Conga sin alterar firmware |
| P4 | Integración MQTT / Home Assistant y programación avanzada | **Precedente probado en otras Congas; 3890 declarada en Clean Assistant** | Medio | Ordenes validadas, control de errores y parada segura |
| P5 | Funcionamiento local sin nube oficial | **Precedente 3890 declarado por tercero; sin validar aquí** | Medio/alto | Funciones cruciales probadas y plan reversible |
| P6 | Optimización de rutas o reglas de limpieza externas | **Investigación**, requiere control seguro, datos y medición | Alto | Mejora de cobertura/tiempo medible en recorridos repetibles |
| P7 | Cambiar voz y sonidos | **Precedente en 4090**, no 3890 | Medio | Backup, prueba reversible y restauración |
| P8 | Modificar algoritmos internos, motores, sensores físicos o batería | **No demostrado** para 3890 | Muy alto | No abordar sin laboratorio de hardware y pruebas de seguridad |

## 4. Próxima investigación técnica

**Primero por USB**, sin modificar firmware:
1. Reconstruir offline inicio de sesión y formato de mensajes de `cliManager.sock`, y/o peticiones `DEVICE_STATUS_GETTING_REQ/RSP`.
2. Buscar rutas pasivas de telemetría: registros no sensibles y consultas ya existentes, sin inyectar órdenes arbitrarias.
3. Validar lectura de batería contra otro indicador observable.
4. Investigar formatos de mapa/posición y delimitar qué datos son privados.
5. **Solo después** estudiar compatibilidad específica con Clean Assistant y migración local por Wi-Fi.

## 5. Fuentes primarias y documentación

- Valetudo, lista exhaustiva de modelos soportados: https://valetudo.cloud/pages/general/supported-robots/
- Anuncio de conversión de 3290/3790: https://github.com/Hypfer/Valetudo/discussions/1681
- Herramientas de conversión CRL-200S y advertencias de bloqueo: https://github.com/Hypfer/valetudo-crl200s-root
- Congatudo: https://github.com/congatudo/Congatudo
- Agnoc y discusión directa 3890: https://github.com/congatudo/agnoc ; https://github.com/congatudo/agnoc/issues/40
- Clean Assistant: https://github.com/miguelsg29/clean-assistant
- OpenDoñita: https://gitlab.com/rastersoft/opendonita ; https://blog.rastersoft.com/?p=2642
- Documentación voz 4090: https://congatudo.cloud/misc/empower-your-conga-voice/

**Política:** no incluir en este repositorio público binarios de firmware, credenciales, claves, seriales, tokens, mapas personales ni logs sin anonimizar.
