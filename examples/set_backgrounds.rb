# frozen_string_literal: true

# One-time setup helper: give every VU1 dial its own background image from
# image_pack/, so each dial's face matches the metric it displays.
#
# resource_monitor.rb requires this file and calls SetBackgrounds.apply on
# startup so the faces always match the lineup. You can also run it directly:
#
#   API_KEY=... ruby set_backgrounds.rb
#
# Pushing a background writes to the dial's flash, so there's a separate
# opt-in mode for clearing the faces back to a blank plate:
#
#   API_KEY=... ruby set_backgrounds.rb --blank
#
# The dial lineup comes from name_dials.rb so all the helpers stay in sync.

require "vu_dials"

require_relative "name_dials"

module SetBackgrounds
  # Where the per-dial faces live, resolved relative to this file so it works
  # no matter what directory the script is run from.
  IMAGE_PACK = File.expand_path("image_pack", __dir__)

  # The empty plate used by .blank to clear a dial's face.
  BLANK_IMAGE = "blank.png"

  module_function

  # Give every dial the face named in NameDials::DIALS. Yields a message per
  # dial if a block is given, so callers can route it through their own logger.
  def apply(dial)
    NameDials::DIALS.each_value do |spec|
      push(dial, spec[:uid], spec[:image]) { |msg| yield msg if block_given? }
    end
  end

  # Clear every dial back to the blank plate. Deliberately not wired into the
  # monitor's shutdown path -- each call rewrites dial flash, so it's something
  # you ask for rather than something that happens on every Ctrl-C.
  def blank(dial)
    NameDials::DIALS.each_value do |spec|
      push(dial, spec[:uid], BLANK_IMAGE) { |msg| yield msg if block_given? }
    end
  end

  # Resolve an image_pack filename to a full path, failing loudly if the file
  # isn't there rather than letting the server reject an empty upload.
  def image_path(filename)
    path = File.join(IMAGE_PACK, filename)
    raise ArgumentError, "background image not found: #{path}" unless File.file?(path)

    path
  end

  def push(dial, uid, filename)
    path = image_path(filename)
    dial.set_background(uid: uid, file: path)
    yield "Set background on dial #{uid} -> #{filename}"
  end
  private_class_method :push
end

if __FILE__ == $PROGRAM_NAME
  dial = VuDials::Dial.new(
    host: ENV.fetch("VU1_SERVER_ADDRESS", "localhost"),
    port: Integer(ENV.fetch("VU1_SERVER_PORT", "5340")),
    api_key: ENV.fetch("API_KEY")
  )

  if ARGV.include?("--blank")
    SetBackgrounds.blank(dial) { |msg| puts msg }
  else
    SetBackgrounds.apply(dial) { |msg| puts msg }
  end
end
