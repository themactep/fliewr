require 'ppds/config'
require 'ppds/flickr'
require 'fliewr/ui'
require 'gtk2'

module Fliewr
  class Core

    def initialize
      $app = self
      $cfg = Ppds::Config.new 'fliewr'

      $gui = Fliewr::UI.new
      $gui.show_all

      $api = Ppds::Flickr.new

      start_timer
    end

    def update
      Gtk.timeout_remove(@@timeout) if @@timeout
      $gui.statusbar.push 0, "updating..."
      
      Thread.new do
        ask_update $cfg.get(:update_interval) * 60
        photos = $api.update $cfg.get(:max_photos)
        $gui.refresh_with photos
        @last_updated_at = timestamp
      end
      start_timer
    rescue Exception => e
      Alert.new @nsid, e.message, e.backtrace
    end

    def timestamp
      Time.now.to_i
    end

    def ask_update(time_ahead = 0)
      @requires_update_at = timestamp + time_ahead
    end

    def start_timer
      @@timeout = Gtk::timeout_add(1000) do
        sec_to_next_update = @requires_update_at.to_i - timestamp
        if sec_to_next_update < 0
          update
        else
          $gui.statusbar.push 0, "%s to update" % human_time(sec_to_next_update)
        end
      end
    end

    def human_time(time)
      seconds = time.modulo(SECONDS_PER_MINUTE)
      minutes = (time - seconds) / SECONDS_PER_MINUTE
      "%d:%02d" % [minutes, seconds]
    end

    def main
      Gtk::main
    end

    def quit
      Gtk::main_quit
    ensure
      $cfg.save
    end
  end
end
