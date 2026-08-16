# frozen_string_literal: true

# One-time setup helper: assign human-readable names to the VU1 dials by UID.
#
# resource_monitor.rb requires this file and calls NameDials.apply on startup so
# that the monitor can then resolve dials by name. You can also run it directly:
#
#   API_KEY=... ruby name_dials.rb
#
# Replace the placeholder UIDs below with your hardware's real UIDs (find them
# with `dial.list_dials` or the VU1 web UI).

require "vu_dials"

module NameDials
  # The single source of truth for the dial lineup: which hardware UID carries
  # which metric, what it's called on the server, and which face from
  # image_pack/ it wears. set_backgrounds.rb, set_backlights.rb and
  # resource_monitor.rb all read this table, so the UIDs live in one place.
  #
  # The keys double as the metric names resource_monitor.rb samples.
  DIALS = {
    cpu_load: { uid: "66002F000650564139323920", name: "CPU Load", image: "cpu-load.png" },
    cpu_temp: { uid: "740069000650564139323920", name: "CPU Temp", image: "cpu-temp.png" },
    gpu_load: { uid: "400068000650564139323920", name: "GPU Load", image: "gpu-load.png" },
    gpu_temp: { uid: "510018000650564139323920", name: "GPU Temp", image: "gpu-temp.png" }
  }.freeze

  module_function

  # Apply every UID -> name mapping. Yields a message per dial if a block is
  # given, so callers can route it through their own logger.
  def apply(dial)
    DIALS.each_value do |spec|
      dial.set_name(uid: spec[:uid], name: spec[:name])
      yield "Named dial #{spec[:uid]} -> #{spec[:name]}" if block_given?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  dial = VuDials::Dial.new(
    host: ENV.fetch("VU1_SERVER_ADDRESS", "localhost"),
    port: Integer(ENV.fetch("VU1_SERVER_PORT", "5340")),
    api_key: ENV.fetch("API_KEY")
  )
  NameDials.apply(dial) { |msg| puts msg }
end
