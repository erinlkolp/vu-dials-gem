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
  UID_TO_NAME = {
    "66002F000650564139323920" => "CPU",
    "740069000650564139323920" => "RAM",
    "400068000650564139323920" => "Disk",
    "510018000650564139323920" => "Network"
  }.freeze

  module_function

  # Apply every UID -> name mapping. Yields a message per dial if a block is
  # given, so callers can route it through their own logger.
  def apply(dial)
    UID_TO_NAME.each do |uid, name|
      dial.set_name(uid: uid, name: name)
      yield "Named dial #{uid} -> #{name}" if block_given?
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
