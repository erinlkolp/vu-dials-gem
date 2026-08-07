# Example: system resource monitor

`resource_monitor.rb` reads local system load and drives four VU1 dials
(**CPU / RAM / Disk / Network**) through the `vu_dials` gem — a Ruby port of the
`python-resource-monitor-vu-dials` example.

Real metrics come from the [`vmstat`](https://rubygems.org/gems/vmstat) gem.
`vu_dials` itself stays zero-dependency; only this example adds `vmstat`.

## Run it

```bash
cd examples
bundle install
cp .env.example .env   # then edit API_KEY (and anything else you need)

# load the .env into the environment, then run under bundler:
env $(grep -v '^#' .env | xargs) bundle exec ruby resource_monitor.rb
```

On startup the script names the dials, sets their background image, turns all
their backlights green, and resolves them by name; then it loops every
`POLL_INTERVAL_SECONDS`, pushing each metric as a 0–100 value with a
green/yellow/red backlight based on the thresholds. Press `Ctrl-C` to stop — it
blanks all four dials on the way out.

## Startup helpers

Three small helper modules run automatically on startup. Each one is also
runnable standalone, e.g.:

```bash
env $(grep -v '^#' .env | xargs) bundle exec ruby name_dials.rb
```

| File | What it does |
| --- | --- |
| `name_dials.rb` | Maps hardware UIDs to names so the monitor can resolve dials by name. **Edit its `UID_TO_NAME` map to match your hardware** — find your real UIDs with `dial.list_dials` or the VU1 web UI. |
| `set_backgrounds.rb` | Pushes the shared `analog-meter.jpg` face to every dial. |
| `set_backlights.rb` | Sets every dial's backlight to one color (green by default). Pass `red:`/`green:`/`blue:` to `SetBacklights.apply` for a different one; channels are 0–100. |

`set_backgrounds.rb` and `set_backlights.rb` both reuse `NameDials::UID_TO_NAME`
for the dial list, so editing the UIDs in one place covers all three.

## Configuration (`.env`)

| Variable | Default | Meaning |
| --- | --- | --- |
| `VU1_SERVER_ADDRESS` | `localhost` | VU1 server host |
| `VU1_SERVER_PORT` | `5340` | VU1 server port |
| `API_KEY` | _(required)_ | dial API key |
| `DISK_PATH` | `/` | filesystem whose usage the Disk dial shows |
| `NETWORK_MAX_MBPS` | `100` | throughput mapped to 100% on the Network dial |
| `POLL_INTERVAL_SECONDS` | `2` | seconds between updates |
| `YELLOW_THRESHOLD` | `60` | value at which the backlight turns yellow |
| `RED_THRESHOLD` | `85` | value at which the backlight turns red |
| `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARN`, … |

## A note on the Disk dial

The Python version's Disk dial tracks disk **I/O throughput**. `vmstat` exposes
disk **capacity**, not I/O, so this Ruby port's Disk dial shows disk **usage**
(used space on `DISK_PATH`) instead. The other three dials match the Python
example.
