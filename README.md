# Plasma 6 Monitor Widgets

Conjunto de widgets de monitorización para KDE Plasma 6, con backend compartido vía D-Bus.

## Widgets

| Widget | Panel | Expandido |
|--------|-------|-----------|
| **RAM & Swap** | `3.2G / 8.0G` + color | Barras + gráfico Canvas + Top 5 procesos |
| **CPU** | `15.3%` + círculo | Gráfico + por núcleo + Top 5 procesos |
| **Uptime & Reboot** | `2d 5h` + color | Historial reinicios + botón reboot |

## Arquitectura

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  RAM & Swap │  │     CPU     │  │   Uptime    │
│   widget    │  │   widget    │  │   widget    │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────┬───────┴────────┬───────┘
                │   D-Bus        │
         ┌──────▼────────────────▼──────┐
         │  com.github.fullmetal.monitor│
         │       monitor-service.py     │
         └──────────────┬───────────────┘
                        │
                   /proc/* + ps
```

## Requisitos

- KDE Plasma 6 (KF6, Qt 6)
- Python 3 + `dbus-python` + `PyGObject`
- systemd user services

## Instalación

```bash
chmod +x install.sh
./install.sh
```

Esto:
1. Instala el servicio D-Bus (`monitor-service.py`)
2. Habilita la systemd user unit
3. Instala los 3 widgets via `kpackagetool6`

## Agregar al panel

Click derecho en el panel → **Añadir widgets** → buscar:
- "RAM & Swap"
- "CPU Monitor"  
- "Uptime & Reboot"

## Configuración

Cada widget tiene opciones accesibles desde el icono de configuración:
- **Intervalo de actualización** (1-30s en panel, 10-30s expandido)
- **Mostrar/ocultar** swap, gráfico, procesos, per-core

## Estructura

```
plasma6-monitor-widgets/
├── monitor-service.py          # Backend D-Bus compartido
├── com.github.fullmetal.monitor.service  # systemd user unit
├── install.sh                  # Script de instalación
├── ram-swap-widget/            # Widget RAM & Swap
│   ├── metadata.json
│   └── contents/
│       ├── ui/main.qml
│       └── config/
├── cpu-widget/                 # Widget CPU
│   ├── metadata.json
│   └── contents/
│       ├── ui/main.qml
│       └── config/
└── uptime-widget/              # Widget Uptime
    ├── metadata.json
    └── contents/
        ├── ui/main.qml
        └── config/
```

## Servicio D-Bus

El servicio expose 3 métodos:

| Método | Retorna | Descripción |
|--------|---------|-------------|
| `GetRamInfo()` | JSON | RAM/Swap usage, history, top processes |
| `GetCpuInfo()` | JSON | CPU usage, per-core, history, top processes |
| `GetUptimeInfo()` | JSON | Uptime, level, reboot history |

## Licencia

MIT
