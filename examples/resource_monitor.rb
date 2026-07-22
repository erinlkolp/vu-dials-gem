# frozen_string_literal: true

# Reads local system load and pushes it to 4 VU1 dials (CPU/RAM/Disk/Network)
# through the vu_dials gem. A Ruby port of the python-resource-monitor example.
#
# Run it with bundler so the example's own dependencies (vu_dials + vmstat) are
# on the load path:
#
#   bundle install
#   API_KEY=... bundle exec ruby resource_monitor.rb
#
# System metrics come from the `vmstat` gem, so this reads real load. The Disk
# dial shows disk-*usage* (used space), since vmstat exposes capacity rather
# than I/O throughput.

require "logger"
require "vu_dials"
require "vmstat"

require_relative "name_dials"
require_relative "set_backgrounds"

# --- configuration (environment) --------------------------------------------
VU1_SERVER_ADDRESS = ENV.fetch("VU1_SERVER_ADDRESS", "localhost")
VU1_SERVER_PORT    = Integer(ENV.fetch("VU1_SERVER_PORT", "5340"))
VU1_API_KEY        = ENV.fetch("API_KEY")

DIAL_NAMES = { cpu: "CPU", ram: "RAM", disk: "Disk", network: "Network" }.freeze

DISK_PATH             = ENV.fetch("DISK_PATH", "/")
NETWORK_MAX_MBPS      = Float(ENV.fetch("NETWORK_MAX_MBPS", "100"))
POLL_INTERVAL_SECONDS = Float(ENV.fetch("POLL_INTERVAL_SECONDS", "2"))

YELLOW_THRESHOLD = Float(ENV.fetch("YELLOW_THRESHOLD", "60"))
RED_THRESHOLD    = Float(ENV.fetch("RED_THRESHOLD", "85"))

LOG = Logger.new($stdout)
LOG.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO"))
LOG.formatter = lambda do |severity, time, _progname, msg|
  "#{time.strftime('%Y-%m-%d %H:%M:%S')} #{severity} #{msg}\n"
end

def monotonic
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def value_to_color(value)
  # The vu-server backlight API takes 0-100 per channel (it silently clamps
  # anything higher), so full scale is 100, not 255.
  return [100, 0, 0] if value >= RED_THRESHOLD
  return [100, 100, 0] if value >= YELLOW_THRESHOLD

  [0, 100, 0]
end

# Turns cumulative CPU jiffie counters into a busy percentage between samples.
class CpuSampler
  def initialize
    @last_busy, @last_total = totals
  end

  def sample_percent
    busy, total = totals
    delta_busy = busy - @last_busy
    delta_total = total - @last_total
    @last_busy = busy
    @last_total = total
    return 0.0 if delta_total <= 0

    [100.0, 100.0 * delta_busy / delta_total].min
  end

  private

  def totals
    cpus = Vmstat.cpu
    busy = cpus.sum { |c| c.user + c.system + c.nice }
    idle = cpus.sum(&:idle)
    [busy, busy + idle]
  end
end

# Tracks a monotonically increasing byte counter between calls to compute a
# throughput percentage against a configured maximum.
class RateSampler
  def initialize(&read_bytes)
    @read_bytes = read_bytes
    @last_bytes = read_bytes.call
    @last_time = monotonic
  end

  def sample_percent(max_mbps)
    total_bytes = @read_bytes.call
    now = monotonic
    elapsed = [now - @last_time, 1e-6].max
    delta_bytes = total_bytes - @last_bytes
    @last_bytes = total_bytes
    @last_time = now
    mbps = (delta_bytes.to_f / 125_000) / elapsed # 125_000 bytes == 1 Mbit
    [100.0, (mbps / max_mbps) * 100.0].min
  end
end

def ram_percent
  mem = Vmstat.memory
  total_bytes = (mem.wired + mem.active + mem.inactive + mem.free) * mem.pagesize
  return 0.0 if total_bytes <= 0

  100.0 * (1.0 - (mem.available_bytes.to_f / total_bytes))
end

def disk_percent
  disk = Vmstat.disk(DISK_PATH)
  return 0.0 if disk.total_blocks <= 0

  used_blocks = disk.total_blocks - disk.free_blocks
  100.0 * used_blocks / disk.total_blocks
end

def network_bytes
  Vmstat.network_interfaces
        .reject(&:loopback?)
        .sum { |iface| iface.in_bytes + iface.out_bytes }
end

def resolve_dial_uids(dial, dial_names)
  data = dial.list_dials.fetch("data")
  name_to_uid = data.to_h { |entry| [entry["dial_name"], entry["uid"]] }

  dial_names.transform_values do |configured_name|
    uid = name_to_uid[configured_name]
    unless uid
      available = name_to_uid.keys.compact.sort.join(", ")
      abort "Dial named #{configured_name.inspect} not found on vu-server. " \
            "Available dial names: #{available.empty? ? '(none)' : available}"
    end
    uid
  end
end

def update_dial(dial, uid, value)
  # Color and needle are two independent HTTP requests. Wrap them separately so
  # a failure of one never suppresses the other -- otherwise a failing value
  # call would skip the color call entirely, leaving a stale (higher) color
  # stuck on after the meter has dropped. Color is set first so a dropping
  # needle is never displayed under a color that no longer matches.
  red, green, blue = value_to_color(value)
  begin
    dial.set_color(uid: uid, red: red, green: green, blue: blue)
  rescue VuDials::Error => e
    LOG.warn("Failed to set color on dial #{uid}: #{e.message}")
  end

  begin
    dial.set_value(uid: uid, value: value.round)
  rescue VuDials::Error => e
    LOG.warn("Failed to set value on dial #{uid}: #{e.message}")
  end
end

# Reset every dial to 0 with its backlight off (used on shutdown).
def blank_dials(dial, uids)
  uids.each_value do |uid|
    dial.set_value(uid: uid, value: 0)
    dial.set_color(uid: uid, red: 0, green: 0, blue: 0)
  rescue VuDials::Error => e
    LOG.warn("Failed to blank dial #{uid}: #{e.message}")
  end
end

def main
  dial = VuDials::Dial.new(host: VU1_SERVER_ADDRESS, port: VU1_SERVER_PORT, api_key: VU1_API_KEY)

  # Name the dials on startup so resolve_dial_uids can find them by name.
  NameDials.apply(dial) { |msg| LOG.info(msg) }

  # Give every dial the shared analog-meter face.
  SetBackgrounds.apply(dial) { |msg| LOG.info(msg) }

  uids = resolve_dial_uids(dial, DIAL_NAMES)
  LOG.info("Resolved dial UIDs: #{uids.inspect}")

  cpu_sampler = CpuSampler.new
  network_sampler = RateSampler.new { network_bytes }

  running = true
  %w[INT TERM].each { |sig| trap(sig) { running = false } }

  LOG.info(format("Starting monitor loop (poll interval: %.1fs)", POLL_INTERVAL_SECONDS))
  while running
    started = monotonic

    values = {
      cpu: cpu_sampler.sample_percent,
      ram: ram_percent,
      disk: disk_percent,
      network: network_sampler.sample_percent(NETWORK_MAX_MBPS)
    }
    LOG.debug("Metric values: #{values.inspect}")

    values.each { |metric_key, value| update_dial(dial, uids[metric_key], value) }

    elapsed = monotonic - started
    remaining = POLL_INTERVAL_SECONDS - elapsed
    sleep(remaining) if running && remaining.positive? # returns early on a trapped signal
  end

  LOG.info("Stopping monitor.")
ensure
  if defined?(dial) && dial && defined?(uids) && uids
    LOG.info("Blanking dials.")
    blank_dials(dial, uids)
  end
end

main if __FILE__ == $PROGRAM_NAME
