# frozen_string_literal: true

# One-time setup helper: set every VU1 dial's background image to the shared
# analog-meter.png that ships alongside this example.
#
# resource_monitor.rb requires this file and calls SetBackgrounds.apply on
# startup so all dials share the same face. You can also run it directly:
#
#   API_KEY=... ruby set_backgrounds.rb
#
# The dial UIDs are reused from name_dials.rb so both helpers stay in sync.

require "vu_dials"

require_relative "name_dials"

module SetBackgrounds
  # The image to push to every dial, resolved relative to this file so it works
  # no matter what directory the script is run from.
  BACKGROUND_IMAGE = File.expand_path("analog-meter.jpg", __dir__)

  module_function

  # Set BACKGROUND_IMAGE as the background for every known dial UID. Yields a
  # message per dial if a block is given, so callers can route it through their
  # own logger.
  def apply(dial, image: BACKGROUND_IMAGE)
    NameDials::UID_TO_NAME.each_key do |uid|
      dial.set_background(uid: uid, file: image)
      yield "Set background on dial #{uid} -> #{File.basename(image)}" if block_given?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  dial = VuDials::Dial.new(
    host: ENV.fetch("VU1_SERVER_ADDRESS", "localhost"),
    port: Integer(ENV.fetch("VU1_SERVER_PORT", "5340")),
    api_key: ENV.fetch("API_KEY")
  )
  SetBackgrounds.apply(dial) { |msg| puts msg }
end
