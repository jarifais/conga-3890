# Análisis estático del firmware — 2026-11-05

**Método:** archivos copiados por `adb pull` desde el robot, inspeccionados fuera del dispositivo. No se han ejecutado esos binarios en Windows ni se ha modificado el firmware. Se publican **metadatos e inferencias delimitadas**, no los binarios propietarios.

## Inventario comprobado

| Fichero | Bytes | SHA-256 |
| --- | ---: | --- |
| `AuxCtrl` | 400454 | `c41c4747250375ed7fca2e198d0d94bce03f507f43ab07210518aef51a75f089` |
| `RobotApp` | 6041085 | `5ea9e8164dd31deacfe2c1e2084ede15aaa3fc2bde1c3e35f66cb77c0d5ba472` |
| `everest-server` | 11859897 | `8ca2e3d866dc8a900cf2616eb0bf6f3afa198a1d0b41878fc177d019d73e80a4` |
| `Monitor` | 607451 | `8fa3a1067435c50b63dc98eddf6dcdd9ec5aa084fdfb9c8a36a4e0f662a4c09a` |
| `libcli.so` | 33618 | `2dc61f9b49dd3fc315ecf949c2b8561faa5e83395dbfc8b39ace6db8ca35a724` |

Los cuatro ejecutables son ELF32 ARM EABI5 enlazados dinámicamente, con intérprete `/lib/ld-musl-armhf.so.1`; `libcli.so` es una biblioteca ARM ELF32. Los archivos carecen de tabla de secciones, pero conservan símbolos dinámicos útiles.

## Procesos observados

- `/usr/sbin/Monitor` supervisa el resto; su servicio se inicia desde `/etc/init.d/robotManager`.
- `/usr/sbin/RobotApp`: software principal y solicitudes de estado.
- `/usr/sbin/AuxCtrl`: procesamiento de mensajes serie y sensores.
- `/usr/sbin/everest-server`: rutinas de sensores, navegación y mapas.

Estas descripciones se apoyan en nombres de clases y símbolos; **no prueban por sí solas** la topología completa ni el protocolo de control.

## Interfaces observadas

- Sockets UNIX que escuchaban: `/tmp/everest_sock`, `/tmp/AuxEverest_Sock` y `/tmp/cliManager.sock`.
- `RobotApp` tenía un descriptor al socket de `everest_sock` y al de `cliManager.sock`.
- `AuxCtrl` tenía un descriptor al socket `AuxEverest_Sock`.
- Puertos TCP locales observados: 22, 6000, 5037 (este último en loopback); UDP 8899.
- Nodos serie presentes: `/dev/ttyS0`, `/dev/ttyS1` y `/dev/ttyS3`. **No atribuimos** función definitiva a ninguno.

## Símbolos y mensajes que orientan la investigación

### En `AuxCtrl`

- `CSerialMessageHandle::handleSensorMessage`
- `CSerialMessageHandle::updateBatterySensor`
- `CSerialMessageHandle::getBatteryVoltage`
- `CRobotPacketReceiver::readSerialPacket` y estados de sincronización
- Clases `C3iroboticsLidar`, `CLidarPacketReceiver` y `CLidarUnpacket`

### En `RobotApp`

- `DEVICE_STATUS_GETTING_REQ` y `DEVICE_STATUS_GETTING_RSP`
- `DEVICE_WORKSTATUS_REPORT_REQ` y `DEVICE_WORK_STATUS_PUSH_NEW_REQ`
- `CParseBuf::parseDeviceStatusGetReq`
- `CSerializeBuf::serializeDeviceStatusGetRsp`
- `CManagerAppSocket::handleGetStatusReq`
- Tipos Protocol Buffers: `DeviceStatus` y `DeviceStatusGettingResult`; nombres de campos encontrados `battary` (grafía original), `charge_state` y `working_mode`.
- Otros identificadores: `battery_percent`, `lidar_status`, `stm_status`.

### En `everest-server`

- `CSensorUpdate::updateBatteryObservation`, `updateIMUObservation`, `updateLidarSensor` y `updateOdometryObservation`.
- `CBatteryCapacity3200::batteryCapacity` y `CRobotApp::getBatteryPercent`.
- Dependencias y símbolos de navegación/SLAM y Protocol Buffers.

### En `libcli.so`

- API CLI `ast_cli_register`, `ast_cli_command_full`, `ast_cli_complete`, `cliClientStart`.
- Socket `/tmp/cliManager.sock` y prompt `Robot>`.
- Comandos de administración genéricos como `module list`, `module load` y `module remove`. **No ejecutarlos durante el diagnóstico.**
- `RobotApp` informó en un registro que cargó `/usr/lib/libcli.so`.

## Firmwares y hardware informados por el propio equipo

- Tina Linux Neptune / revisión `57513AA3`, firmware `tina.robotix.20200831.194440`.
- Kernel `Linux 3.4.39`; 4 núcleos ARMv7, 512 MiB RAM.
- Configuración `ctrl_version=V5.0`, `deviceFirmsID=1003` y `deviceType=4` (su significado exhaustivo no está documentado).
- Fichero de versión STM32: `2.0.1_19082728`.
- Fichero de LiDAR: `LDS3_NOR_1805041536`.
- El archivo `hwdrivers.ini` habilita opciones de batería, IMU, odometría, carga y otros sensores, y fija `lidar_max_distance=6.0`. **Parámetros de configuración, no mediciones en vivo.**

## Lo que falta por demostrar

1. Tramas, identificadores numéricos, codificación y requisitos de sesión de las peticiones de estado.
2. Existencia y seguridad de comandos de solo lectura en la CLI.
3. Consulta real y actual del porcentaje de batería.
4. Acceso no invasivo a telemetría de sensores y datos del LiDAR.

No emitir mensajes a sockets, UART ni motores hasta resolver esos puntos.
