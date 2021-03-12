require "http"

module Etcd
  class Error < ::Exception
    getter message
  end

  class ApiError < Error
    def initialize(@status_code : Int32, message = "")
      super(message)
    end

    def self.from_response(response)
      pp! response
      new(response.status_code, response.body)
    end
  end

  class WatchError < Error
  end
end
