require 'mongoid'

module Twictionary
    module Models
        class User
            include Mongoid::Document
            field :screen_name, type: String
            field :name, type: String
            field :followers_count, type: Integer
            field :uid, type: Integer
        end
    end
end