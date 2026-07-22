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

On startup the script names the dials (see below), resolves them by name, then
loops every `POLL_INTERVAL_SECONDS`, pushing each metric as a 0–100 value with a
green/yellow/red backlight based on the thresholds. Press `Ctrl-C` to stop — it
blanks all four dials on the way out.

## Naming the dials

`name_dials.rb` maps hardware UIDs to names and is applied automatically on
startup. **Edit its `UID_TO_NAME` map to match your hardware** — find your real
UIDs with `dial.list_dials` or the VU1 web UI. You can also run it standalone:

```bash
env $(grep -v '^#' .env | xargs) bundle exec ruby name_dials.rb
```

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
