# frozen_string_literal: true

# Reads local CPU and GPU load/temperature and pushes it to 4 VU1 dials through
# the vu_dials gem.
#
# Run it with bundler so the example picks up the gem from this repo:
#
#   bundle install
#   API_KEY=... bundle exec ruby resource_monitor.rb
#
# Metrics are read straight from the kernel and the NVIDIA driver, so this
# example has no gem dependencies beyond vu_dials itself:
#
#   CPU load -- /proc/stat jiffie counters
#   CPU temp -- /sys/class/hwmon (the `coretemp` device)
#   GPU load -- nvidia-smi
#   GPU temp -- nvidia-smi
#
# Anything the machine can't provide (no NVIDIA GPU, no coretemp) is reported
# once at startup and its dial simply reads 0 -- the monitor still runs.

require "logger"
require "open3"
require "vu_dials"

require_relative "name_dials"
require_relative "set_backgrounds"
require_relative "set_backlights"

# --- configuration (environment) --------------------------------------------
VU1_SERVER_ADDRESS = ENV.fetch("VU1_SERVER_ADDRESS", "localhost")
VU1_SERVER_PORT    = Integer(ENV.fetch("VU1_SERVER_PORT", "5340"))
VU1_API_KEY        = ENV.fetch("API_KEY")

POLL_INTERVAL_SECONDS = Float(ENV.fetch("POLL_INTERVAL_SECONDS", "2"))

# Load dials are percentages; temp dials are degrees Celsius read straight onto
# the 0-100 scale. The two aren't comparable, so they get their own thresholds.
YELLOW_THRESHOLD = Float(ENV.fetch("YELLOW_THRESHOLD", "60"))
RED_THRESHOLD    = Float(ENV.fetch("RED_THRESHOLD", "85"))
TEMP_YELLOW_C    = Float(ENV.fetch("TEMP_YELLOW_C", "70"))
TEMP_RED_C       = Float(ENV.fetch("TEMP_RED_C", "85"))

THRESHOLDS = {
  cpu_load: { yellow: YELLOW_THRESHOLD, red: RED_THRESHOLD },
  gpu_load: { yellow: YELLOW_THRESHOLD, red: RED_THRESHOLD },
  cpu_temp: { yellow: TEMP_YELLOW_C, red: TEMP_RED_C },
  gpu_temp: { yellow: TEMP_YELLOW_C, red: TEMP_RED_C }
}.freeze

LOG = Logger.new($stdout)
LOG.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO"))
LOG.formatter = lambda do |severity, time, _progname, msg|
  "#{time.strftime('%Y-%m-%d %H:%M:%S')} #{severity} #{msg}\n"
end

def monotonic
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def value_to_color(value, yellow:, red:)
  # The vu-server backlight API takes 0-100 per channel (it silently clamps
  # anything higher), so full scale is 100, not 255.
  return [100, 0, 0] if value >= red
  return [100, 100, 0] if value >= yellow

  [0, 100, 0]
end

# Turns cumulative CPU jiffie counters from /proc/stat into a busy percentage
# between samples.
class CpuLoadSampler
  STAT_PATH = "/proc/stat"

  def self.available?
    File.readable?(STAT_PATH)
  end

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

  # The aggregate "cpu" line: user nice system idle iowait irq softirq steal ...
  # Idle time is idle + iowait; everything else counts as busy.
  def totals
    line = File.foreach(STAT_PATH).first
    fields = line.to_s.split[1..].to_a.map(&:to_i)
    return [0, 0] if fields.empty?

    total = fields.sum
    idle = fields[3].to_i + fields[4].to_i
    [total - idle, total]
  end
end

# Reads CPU package temperature from sysfs. hwmon numbering isn't stable across
# boots, so the device is located by its `name` rather than a fixed hwmonN path.
class CpuTempSampler
  HWMON_GLOB = "/sys/class/hwmon/hwmon*"
  PACKAGE_LABEL = "Package id 0"

  attr_reader :path

  def initialize(path: self.class.resolve_path)
    @path = path
  end

  def available?
    !@path.nil?
  end

  # Sysfs reports millidegrees Celsius.
  def sample_celsius
    return 0.0 unless available?

    Integer(File.read(@path).strip) / 1000.0
  rescue SystemCallError, ArgumentError
    0.0
  end

  # An explicit CPU_TEMP_PATH wins; otherwise find the configured hwmon device
  # and prefer its package-wide sensor over the first per-core one.
  def self.resolve_path
    explicit = ENV["CPU_TEMP_PATH"]
    return explicit if explicit && File.readable?(explicit)

    wanted = ENV.fetch("CPU_TEMP_HWMON", "coretemp")
    Dir[HWMON_GLOB].sort.each do |dir|
      next unless read_name(dir) == wanted

      package = Dir[File.join(dir, "temp*_label")].sort.find do |label|
        File.read(label).strip == PACKAGE_LABEL
      rescue SystemCallError
        false
      end
      return package.sub(/_label\z/, "_input") if package

      first = File.join(dir, "temp1_input")
      return first if File.readable?(first)
    end
    nil
  end

  def self.read_name(dir)
    File.read(File.join(dir, "name")).strip
  rescue SystemCallError
    nil
  end
  private_class_method :read_name
end

# Reads GPU utilization and temperature from nvidia-smi. Both numbers come back
# from a single invocation, so one poll costs one subprocess rather than two.
class NvidiaGpuSampler
  COMMAND = [
    "nvidia-smi",
    "--query-gpu=utilization.gpu,temperature.gpu",
    "--format=csv,noheader,nounits"
  ].freeze

  ZERO = { load: 0.0, temp: 0.0 }.freeze

  def initialize
    @available = !sample_raw.nil?
  end

  def available?
    @available
  end

  # Returns { load: <percent>, temp: <celsius> }, zeroed if the GPU can't be
  # read. Called once per poll and its result fanned out to both GPU dials.
  def sample
    return ZERO unless @available

    sample_raw || ZERO
  end

  private

  def sample_raw
    stdout, _stderr, status = Open3.capture3(*COMMAND)
    return nil unless status.success?

    # Multi-GPU machines print one row per GPU; this example uses the first.
    load, temp = stdout.lines.first.to_s.split(",").map(&:strip)
    return nil if load.nil? || temp.nil?

    { load: Float(load), temp: Float(temp) }
  rescue Errno::ENOENT, ArgumentError, TypeError
    nil
  end
end

def resolve_dial_uids(dial)
  data = dial.list_dials.fetch("data")
  name_to_uid = data.to_h { |entry| [entry["dial_name"], entry["uid"]] }

  NameDials::DIALS.transform_values do |spec|
    uid = name_to_uid[spec[:name]]
    unless uid
      available = name_to_uid.keys.compact.sort.join(", ")
      abort "Dial named #{spec[:name].inspect} not found on vu-server. " \
            "Available dial names: #{available.empty? ? '(none)' : available}"
    end
    uid
  end
end

def update_dial(dial, uid, value, thresholds)
  # Color and needle are two independent HTTP requests. Wrap them separately so
  # a failure of one never suppresses the other -- otherwise a failing value
  # call would skip the color call entirely, leaving a stale (higher) color
  # stuck on after the meter has dropped. Color is set first so a dropping
  # needle is never displayed under a color that no longer matches.
  red, green, blue = value_to_color(value, **thresholds)
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

# Reset every dial to 0 with its backlight off (used on shutdown). The dial
# faces are left alone -- clearing those is `ruby set_backgrounds.rb --blank`.
def blank_dials(dial, uids)
  uids.each_value do |uid|
    dial.set_value(uid: uid, value: 0)
    dial.set_color(uid: uid, red: 0, green: 0, blue: 0)
  rescue VuDials::Error => e
    LOG.warn("Failed to blank dial #{uid}: #{e.message}")
  end
end

# Say up front what this machine can and can't report, so a dial parked at 0
# is explained rather than mysterious.
def report_sources(cpu_temp, gpu)
  LOG.warn("/proc/stat unreadable; CPU Load dial will read 0.") unless CpuLoadSampler.available?

  if cpu_temp.available?
    LOG.info("CPU temperature source: #{cpu_temp.path}")
  else
    LOG.warn("No CPU temperature sensor found (looked for the " \
             "#{ENV.fetch('CPU_TEMP_HWMON', 'coretemp')} hwmon device); " \
             "CPU Temp dial will read 0. Set CPU_TEMP_PATH to override.")
  end

  if gpu.available?
    LOG.info("GPU source: nvidia-smi")
  else
    LOG.warn("nvidia-smi unavailable; GPU Load and GPU Temp dials will read 0.")
  end
end

# Temperatures go straight onto the dial as degrees, so a sensor reading past
# full scale has to be clamped or the server rejects the value.
def clamp(value)
  value.clamp(0.0, 100.0)
end

def main
  dial = VuDials::Dial.new(host: VU1_SERVER_ADDRESS, port: VU1_SERVER_PORT, api_key: VU1_API_KEY)

  # Name the dials on startup so resolve_dial_uids can find them by name.
  NameDials.apply(dial) { |msg| LOG.info(msg) }

  # Give each dial the face that matches its metric.
  SetBackgrounds.apply(dial) { |msg| LOG.info(msg) }

  # Light every dial green up front so they aren't dark until the first poll.
  SetBacklights.apply(dial) { |msg| LOG.info(msg) }

  uids = resolve_dial_uids(dial)
  LOG.info("Resolved dial UIDs: #{uids.inspect}")

  cpu_load = CpuLoadSampler.new
  cpu_temp = CpuTempSampler.new
  gpu = NvidiaGpuSampler.new
  report_sources(cpu_temp, gpu)

  running = true
  %w[INT TERM].each { |sig| trap(sig) { running = false } }

  LOG.info(format("Starting monitor loop (poll interval: %.1fs)", POLL_INTERVAL_SECONDS))
  while running
    started = monotonic

    gpu_reading = gpu.sample
    values = {
      cpu_load: clamp(cpu_load.sample_percent),
      cpu_temp: clamp(cpu_temp.sample_celsius),
      gpu_load: clamp(gpu_reading[:load]),
      gpu_temp: clamp(gpu_reading[:temp])
    }
    LOG.debug("Metric values: #{values.inspect}")

    values.each { |metric_key, value| update_dial(dial, uids[metric_key], value, THRESHOLDS[metric_key]) }

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
