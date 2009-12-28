require 'gtk2'
require 'gtkmozembed'

Gtk::MozEmbed.set_profile_path ENV['HOME'] + '/.mozilla', 'fliewr'

module Fliewr

  SECONDS_PER_MINUTE = 60

  DATA_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data'))
  
  class UI < Gtk::Window

    attr_accessor :logo, :statusbar, :theme_base, :theme_item, :theme_error, :theme_style

    def initialize
      super Gtk::Window::TOPLEVEL

      filename = File.join(Fliewr::DATA_ROOT, 'pixmaps', 'fliewr.svg')
      self.logo = Gdk::Pixbuf.new filename, 128, 128

      self.set_title 'Fliewr'
      self.set_icon self.logo
      self.set_width_request 279
      self.set_height_request 400
      self.set_allow_shrink false
      self.set_default_width $cfg.get(:window_width).to_i
      self.set_default_height $cfg.get(:window_height).to_i
      self.move $cfg.get(:window_x_pos).to_i, $cfg.get(:window_y_pos).to_i

      theme = $cfg.get(:theme) || 'default'
      theme_root = File.join(DATA_ROOT,'themes',theme)
      self.theme_base  = File.read(File.join(theme_root,'theme.html'))
      self.theme_item  = File.read(File.join(theme_root,'item.html'))
      self.theme_error = File.read(File.join(theme_root,'error.html'))
      self.theme_style = File.read(File.join(theme_root,'style.css'))

      self.signal_connect(:destroy) { quit }
      self.signal_connect(:delete_event) { minimize }
      self.signal_connect(:check_resize) { remember_size_position }
      self.signal_connect(:window_state_event) do |widget, event|
        case event.event_type
        when Gdk::Event::WINDOW_STATE
          minimize if event.changed_mask.iconified? and event.new_window_state.iconified?
        end
      end

      self.statusbar = Gtk::Statusbar.new
      self.statusbar.set_has_resize_grip false

      toolbar = Gtk::Toolbar.new
      toolbar.icon_size = Gtk::IconSize::MENU

      icon = Gtk::Image.new Gtk::Stock::HOME, Gtk::IconSize::MENU
      button = Gtk::ToolButton.new icon, 'Flickr'
      button.set_important true
      button.signal_connect(:clicked) do |widget|
        visit_user_profile
      end
      toolbar.insert 0, button

      icon = Gtk::Image.new Gtk::Stock::REFRESH, Gtk::IconSize::MENU
      button = Gtk::ToolButton.new icon, 'Refresh'
      button.set_important true
      button.set_can_default true
      button.set_can_focus true
      button.signal_connect(:clicked) do |widget|
        $app.ask_update
      end
      toolbar.insert 1, button
      self.set_default button
      self.set_focus button

      icon = Gtk::Image.new Gtk::Stock::PREFERENCES, Gtk::IconSize::MENU
      button = Gtk::ToolButton.new icon, 'Settings'
      button.signal_connect(:clicked) do |widget|
        Fliewr::SettingsDialog.new
      end
      toolbar.insert 2, button

      separator = Gtk::SeparatorToolItem.new
      separator.set_draw false
      separator.set_expand true
      toolbar.insert 3, separator

      icon = Gtk::Image.new Gtk::Stock::QUIT, Gtk::IconSize::MENU
      button = Gtk::ToolButton.new icon, 'Quit'
      button.signal_connect(:clicked) do |widget|
        $app.quit
      end
      toolbar.insert 4, button

      @browser = Gtk::MozEmbed.new
      @browser.signal_connect(:open_uri) do |widget, uri|
        open_in_external_browser(uri)
      end

      vbox = Gtk::VBox.new false, 4
      vbox.pack_start toolbar, false
      vbox.pack_start @browser
      vbox.pack_start self.statusbar, false
      self.add vbox
    end

    def remember_size_position
      x, y = self.position
      w, h = self.size
      $cfg.set :window_x_pos, x
      $cfg.set :window_y_pos, y
      $cfg.set :window_width, w
      $cfg.set :window_height, h
    end

    def minimize
      remember_size_position
      hide
    end

    def maximize
      self.show
      self.present
    end

    def open_in_gecko(html)
      @browser.open_stream "file:///", "text/html"
      @browser.append_data self.theme_base % [ self.theme_style, html ]
      @browser.close_stream
    end

    def refresh_with(data)
      html = data.map { |d| templatize(d) }.join
      open_in_gecko html
    end

    def templatize(data)
      self.theme_item % [
        photolink(data.owner,  data.id),
        photopreview(data.farm, data.server, data.id, data.secret),
        user_profile_link(data.owner),
        data.username,
        userpic(data.iconfarm, data.iconserver, data.owner),
        data.title,
        dateupload(data.dateupload)
      ]
    end

    def photopreview(*args)
      'http://farm%s.static.flickr.com/%s/%s_%s_m.jpg' % args
    end

    def photolink(*args)
      'http://www.flickr.com/photos/%s/%s' % args
    end

    def user_profile_link(id = @nsid)
      'http://www.flickr.com/people/%s' % id
    end

    def userpic(farm, server, owner)
      return 'http://www.flickr.com/images/buddyicon.jpg' if farm.to_i == 0
      'http://farm%s.static.flickr.com/%s/buddyicons/%s.jpg' % [ farm, server, owner ]
    end

    def dateupload(date_and_time)
      Time.at(date_and_time.to_i)
    end

    def visit_user_profile
      open_in_external_browser user_profile_link
    end

    def open_in_external_browser(uri)
      Thread.new { system('xdg-open "%s"' % uri) }
    end

    def quit
      $app.quit
    end
  end


  class StatusIcon < Gtk::StatusIcon
    def initialize
      super
      self.file = File.join(Fliewr::DATA_ROOT, 'pixmaps', 'fliewr.svg')
      self.set_tooltip 'Flickr Viewr'
      self.signal_connect(:activate) do
        if $gui.visible?
          $gui.minimize
        else
          $gui.move $cfg.get(:window_x_pos), $cfg.get(:window_y_pos)
          $gui.show.present
        end
      end

      menu = Gtk::Menu.new

      self.signal_connect(:popup_menu) do |icon, button, time|
        menu.popup nil, nil, button, time
      end

      separator = Gtk::SeparatorMenuItem.new

      item = Gtk::ImageMenuItem.new Gtk::Stock::HOME
      item.signal_connect(:activate) do
        $app.visit_user_profile
      end
      menu.append item

      item = Gtk::ImageMenuItem.new Gtk::Stock::REFRESH
      item.signal_connect(:activate) do
        $app.update
      end
      menu.append item

      item = Gtk::CheckMenuItem.new 'Always on top'
      item.signal_connect(:toggled) do |widget|
        $gui.keep_above = widget.active?
      end
      menu.append item

      item = Gtk::ImageMenuItem.new Gtk::Stock::PREFERENCES
      item.signal_connect(:activate) do
        Fliewr::SettingsDialog.new
      end
      menu.append item

      item = Gtk::ImageMenuItem.new Gtk::Stock::ABOUT
      item.signal_connect(:activate) do
        AboutDialog.new
      end
      menu.append item
      menu.append separator

      item = Gtk::ImageMenuItem.new Gtk::Stock::QUIT
      item.signal_connect(:activate) do
        $app.quit
      end
      menu.append item
      menu.show_all
    end
  end

  class AboutDialog < Gtk::AboutDialog
    def initialize
      Gtk::AboutDialog.set_email_hook do |widget, email|
        system("xdg-email #{email}")
      end
      Gtk::AboutDialog.set_url_hook do |widget, link|
        system("xdg-open #{link}")
      end
      super
      self.name         = 'Flickr Viewr'
      self.program_name = 'Flickr Viewr'
      self.comments     = "Flickr photostream viewer"
      self.version      = '2.0.0'
      self.copyright    = "Copyright (c)2008 Paul Philippov"
      self.license      = "This software is released under the BSD License.\nhttp://creativecommons.org/licenses/BSD/"
      self.authors      = ['Paul Philippov <paul@ppds.ws>']
      self.documenters  = ['Paul Philippov <paul@ppds.ws>']
      self.website      = "http://themactep.com/fliewr/"
      self.logo         = $gui.logo
      self.run
      self.destroy
    end
  end

  class SettingsDialog < Gtk::Dialog
    def initialize
      super "Settings", nil, Gtk::Dialog::MODAL,
        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT],
        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL]

      self.set_default_response Gtk::Dialog::RESPONSE_ACCEPT
      self.signal_connect :response do |dialog, response|
        case response
        when Gtk::Dialog::RESPONSE_ACCEPT
          if /\d\d\d\d\d\d\d\d@N\d\d/ =~ @nsid_entry.text
            $cfg.set :nsid, @nsid_entry.text
            $cfg.set :update_interval, @update_interval_spin.value
            $cfg.set :max_photos, @max_photos_spin.value
            $cfg.set :one_per_contact, @one_per_contact_toggle.active?
            $cfg.set :only_from_friends, @only_from_friends_toggle.active?
            $cfg.set :include_self, @include_self_toggle.active?
            $app.update
          else
            Alert.new "User ID has incorrect format"
          end
        when Gtk::Dialog::RESPONSE_CANCEL
          true
        end
      end
      hbox = Gtk::HBox.new false, 8
      hbox.set_border_width 8
      self.vbox.pack_start hbox, false, false, 0

      stock = Gtk::Image.new Gtk::Stock::PREFERENCES, Gtk::IconSize::DIALOG
      hbox.pack_start stock, false, false, 0

      table = Gtk::Table.new 3, 6
      table.set_row_spacings 4
      table.set_column_spacings 8
      hbox.pack_start table, true, true, 0

      @nsid_entry = Gtk::Entry.new
      @nsid_entry.width_chars = 13
      @nsid_entry.max_length = 12
      @nsid_entry.text = $cfg.get(:nsid)
      table.attach_defaults label('Your Flickr user ID'), 0, 1, 0, 1
      table.attach_defaults @nsid_entry, 1, 2, 0, 1
      table.attach_defaults button_with_click(:find, :find_nsid), 2, 3, 0, 1

      @update_interval_spin = Gtk::SpinButton.new(1, 100, 1)
      @update_interval_spin.value = $cfg.get(:update_interval).to_i
      table.attach_defaults label('Check new photos every'), 0, 1, 1, 2
      table.attach_defaults @update_interval_spin, 1, 2, 1, 2
      table.attach_defaults label('minutes'), 2, 3, 1, 2

      @max_photos_spin = Gtk::SpinButton.new(1, 50, 1)
      @max_photos_spin.value = $cfg.get(:max_photos).to_i
      table.attach_defaults label('Maximum photos to display'), 0, 1, 2, 3
      table.attach_defaults @max_photos_spin, 1, 2, 2, 3

      @one_per_contact_toggle = Gtk::CheckButton.new
      @one_per_contact_toggle.active = $cfg.get(:one_per_contact)
      table.attach_defaults label('Only one photo per contact'), 0, 1, 3, 4
      table.attach_defaults @one_per_contact_toggle, 1, 2, 3, 4

      @only_from_friends_toggle = Gtk::CheckButton.new
      @only_from_friends_toggle.active = $cfg.get(:only_from_friend)
      table.attach_defaults label('Only from friends and family'), 0, 1, 4, 5
      table.attach_defaults @only_from_friends_toggle, 1, 2, 4, 5

      @include_self_toggle = Gtk::CheckButton.new
      @include_self_toggle.active = $cfg.get(:include_self)
      table.attach_defaults label('Include your own photos'), 0, 1, 5, 6
      table.attach_defaults @include_self_toggle, 1, 2, 5, 6

      self.show_all
      self.run
      self.destroy
    end

    def button_with_click(stock_id, method_name)
      button = Gtk::Button.new icon(stock_id)
      button.signal_connect(:clicked) do |widget|
        self.method(method_name).call
      end
      button.show_all
    end

    def find_nsid
      $gui.open_in_external_browser 'http://www.flickr.com/services/api/explore/?method=flickr.people.getInfo'
    end

    def icon(stock_id)
      Gtk::Stock.const_get stock_id.to_s.upcase
    end

    def label(text)
      Gtk::Label.new(text).set_alignment(0, 0.5)
    end
  end

  class Alert
    def initialize(*args)
      html = $gui.theme_error % [args].flatten.map { |e| "<li>#{e}</li>" }.join
      $gui.open_in_gecko(html)
      false
    end
  end
end
