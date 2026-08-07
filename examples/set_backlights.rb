# frozen_string_literal: true

# One-time setup helper: set every VU1 dial's backlight to a single color
# (green by default).
#
# resource_monitor.rb requires this file and calls SetBacklights.apply on
# startup so the dials light up immediately instead of staying dark until the
# first poll. You can also run it directly:
#
#   API_KEY=... ruby set_backlights.rb
#
# The dial UIDs are reused from name_dials.rb so all the helpers stay in sync.

require "vu_dials"

require_relative "name_dials"

module SetBacklights
  # The vu-server backlight API takes 0-100 per channel (it silently clamps
  # anything higher), so full scale is 100, not 255.
  GREEN = { red: 0, green: 100, blue: 0 }.freeze

  module_function

  # Set the same backlight color on every known dial UID. Yields a message per
  # dial if a block is given, so callers can route it through their own logger.
  def apply(dial, red: GREEN[:red], green: GREEN[:green], blue: GREEN[:blue])
    NameDials::UID_TO_NAME.each_key do |uid|
      dial.set_color(uid: uid, red: red, green: green, blue: blue)
      yield "Set backlight on dial #{uid} -> (#{red}, #{green}, #{blue})" if block_given?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  dial = VuDials::Dial.new(
    host: ENV.fetch("VU1_SERVER_ADDRESS", "localhost"),
    port: Integer(ENV.fetch("VU1_SERVER_PORT", "5340")),
    api_key: ENV.fetch("API_KEY")
  )
  SetBacklights.apply(dial) { |msg| puts msg }
end
