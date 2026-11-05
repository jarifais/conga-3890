# Seguridad, alcance y publicación

Este repositorio es público. **La investigación no autoriza publicar datos privados del equipo ni distribuir software de terceros.**

## Publicable

- Procedimientos reproducibles de diagnóstico **no destructivos**.
- Versiones de sistema, arquitectura y nombres genéricos de servicios.
- Tamaños y hashes criptográficos de ejecutables, como identificadores de las muestras analizadas.
- Observaciones de protocolos con datos personales eliminados.
- Código original de diagnóstico de lectura, revisado para evitar efectos secundarios.

## No publicar

- Firmware, binarios y bibliotecas extraídos del robot (`RobotApp`, `AuxCtrl`, `everest-server`, `Monitor`, `libcli.so`).
- Contraseñas, claves, tokens, cuentas, configuración Wi-Fi ni certificados.
- Número de serie USB/SoC, MAC, ID de dispositivo, identificadores de nube o direcciones privadas vinculadas al equipo.
- Mapas, trayectorias, nombres de habitaciones ni registros completos que puedan revelar el domicilio o hábitos de uso.
- Dumps de memoria, `/etc/shadow` u otros archivos de autenticación.
- Comandos de escritura/desbloqueo de controladores ensayados sin evaluación.

## Reglas de ensayo

1. **Primero offline:** analizar símbolos, cadenas, bibliotecas y protocolos antes de conectarse a un servicio interno.
2. **Primero lectura:** observar el estado sin enviar mensajes cuyo efecto desconozcamos.
3. No alterar firmware, particiones, parámetros de motores ni configuración persistente.
4. No lanzar manualmente servicios supervisados por `Monitor` (riesgo de instancias duplicadas y reinicios).
5. No interpretar las conexiones TCP/UNIX exitosas como prueba de una API operativa.
6. En PowerShell, usar bloques autocontenidos `& { ... }`. Nunca pegarlos dentro de `ash` del robot.
7. Documentar fecha, versión, condiciones, resultado y alcance de cada experimento.
8. Cualquier futuro cambio activo debe tener mecanismo de parada, condiciones seguras y autorización específica.

## Archivos locales

Mantener las muestras fuera del repositorio. `.gitignore` evita adiciones accidentales de nombres habituales, pero **no sustituye** una revisión manual de los cambios antes de publicarlos.
