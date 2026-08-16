# Example: CPU/GPU monitor

`resource_monitor.rb` reads local CPU and GPU load/temperature and drives four
VU1 dials (**CPU Load / CPU Temp / GPU Load / GPU Temp**) through the `vu_dials`
gem.

Metrics come straight from the kernel and the NVIDIA driver, so the example has
no gem dependencies beyond `vu_dials` itself — which stays zero-dependency.

| Dial | Source | Value |
| --- | --- | --- |
| CPU Load | `/proc/stat` jiffie counters | 0–100 % |
| CPU Temp | `/sys/class/hwmon` (the `coretemp` device) | °C, clamped to 0–100 |
| GPU Load | `nvidia-smi` | 0–100 % |
| GPU Temp | `nvidia-smi` | °C, clamped to 0–100 |

Temperatures read **straight onto the dial as degrees** — 72 °C parks the needle
at 72 — so the face reads like a real thermometer gauge rather than a percentage.

## Run it

```bash
cd examples
bundle install
cp .env.example .env   # then edit API_KEY (and anything else you need)

# load the .env into the environment, then run under bundler:
env $(grep -v '^#' .env | xargs) bundle exec ruby resource_monitor.rb
```

On startup the script names the dials, gives each one its background image,
turns all their backlights green, and resolves them by name; then it loops every
`POLL_INTERVAL_SECONDS`, pushing each metric to its dial with a green/yellow/red
backlight based on the thresholds. Press `Ctrl-C` to stop — it zeroes all four
dials and turns their backlights off on the way out.

## Missing hardware

Nothing here is fatal. If the machine has no NVIDIA GPU, or no `coretemp` sensor,
the monitor says so once at startup and that dial simply reads 0 — the rest keep
working. If your CPU sensor lives somewhere unusual, point `CPU_TEMP_PATH` at it
directly.

## Startup helpers

Three small helper modules run automatically on startup. Each one is also
runnable standalone, e.g.:

```bash
env $(grep -v '^#' .env | xargs) bundle exec ruby name_dials.rb
```

| File | What it does |
| --- | --- |
| `name_dials.rb` | Defines the dial lineup: UID, name and background image per metric. **Edit its `DIALS` table to match your hardware** — find your real UIDs with `dial.list_dials` or the VU1 web UI. |
| `set_backgrounds.rb` | Pushes each dial its own face from `image_pack/`. |
| `set_backlights.rb` | Sets every dial's backlight to one color (green by default). Pass `red:`/`green:`/`blue:` to `SetBacklights.apply` for a different one; channels are 0–100. |

`set_backgrounds.rb` and `set_backlights.rb` both read `NameDials::DIALS`, so
editing the UIDs in one place covers all three.

## Dial faces

`image_pack/` holds one PNG per metric, plus a blank plate:

```
cpu-load.png  cpu-temp.png  gpu-load.png  gpu-temp.png  fan-speed.png  blank.png
```

`fan-speed.png` isn't used by the four-dial lineup above — it's there if you add
a fan dial.

Writing a background burns dial flash, so clearing the faces is opt-in rather
than part of shutdown:

```bash
env $(grep -v '^#' .env | xargs) bundle exec ruby set_backgrounds.rb --blank
```

## Configuration (`.env`)

| Variable | Default | Meaning |
| --- | --- | --- |
| `VU1_SERVER_ADDRESS` | `localhost` | VU1 server host |
| `VU1_SERVER_PORT` | `5340` | VU1 server port |
| `API_KEY` | _(required)_ | dial API key |
| `POLL_INTERVAL_SECONDS` | `2` | seconds between updates |
| `YELLOW_THRESHOLD` | `60` | load % at which the backlight turns yellow |
| `RED_THRESHOLD` | `85` | load % at which the backlight turns red |
| `TEMP_YELLOW_C` | `70` | °C at which a temp dial's backlight turns yellow |
| `TEMP_RED_C` | `85` | °C at which a temp dial's backlight turns red |
| `CPU_TEMP_HWMON` | `coretemp` | hwmon device name to read CPU temperature from |
| `CPU_TEMP_PATH` | _(auto)_ | exact sysfs file to read, bypassing discovery |
| `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARN`, … |
