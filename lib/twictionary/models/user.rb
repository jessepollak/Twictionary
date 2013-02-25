require 'mongoid'

module Twictionary
    module Models
        class User
            include Mongoid::Document
            field :screen_name, type: String
            field :name, type: String
            field :followers_count, type: Integer
            field :uid, type: Integer
            field :scraped, type: Boolean, default: false

            index({uid: 1}, {unique: true})
            index({screen_name: 1}, {unique: true})
        end
    end
end