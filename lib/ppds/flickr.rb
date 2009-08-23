require 'ppds/class_factory'
require 'rest_client'
require 'xml'

module Ppds
  class Photo < ClassFactory
    attr_accessor :id, :secret, :server, :farm, :title, :owner, :username,
                  :ispublic, :isfriend, :isfamily, :dateupload, :iconserver,
                  :iconfarm, :license
  end

  class Flickr
    API_URL = 'http://api.flickr.com/services/rest'
    API_KEY = '0282f93eb6da0425310bd5791f4c2fc0'

    attr_accessor :photos

    def initialize
    end

    def query(action, data)
      data.update({
        :api_key => API_KEY,
        :method  => action
      })
      RestClient.post(API_URL, data)
    rescue RestClient::RequestFailed
      raise 'Query failed: %s' % $!
    rescue RestClient::RequestTimeout
      raise 'Timeout occured'
    rescue Exception
      raise $!
    end

    def update(qty)
      data = {
        :extras       => 'date_upload,icon_server,license',
        :count        => qty,
        :user_id      => $cfg.get(:nsid).to_s,
        :single_photo => $cfg.get(:one_per_contact) ? 1 : 0,
        :just_friends => $cfg.get(:only_from_friends) ? 1 : 0,
        :include_self => $cfg.get(:include_self) ? 1 : 0
      }
      xml = query('flickr.photos.getContactsPublicPhotos', data)
      @xml = XML::Parser.string(xml).parse
      self.photos = @xml.find('//photos/photo').map do |node|
        Photo.new(node.attributes)
      end
    end
  end
end
