module Stasher
  module CurrentScope
    ##
    # Gets the hash of fields in the current scope
    def self.fields
      Thread.current[:stasher_fields] ||= {}
    end

    ##
    # Gets the hash of fields in the current scope
    def self.fields=(values)
      Thread.current[:stasher_fields] = values
    end

    ##
    # Clears the current scope
    def self.clear!
      Thread.current[:stasher_fields] = nil
    end
  end
end