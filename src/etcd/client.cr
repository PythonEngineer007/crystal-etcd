require "./kv"
require "./auth"
require "./lease"
require "./maintenance"
require "./watch"

class Etcd::Client
  getter api : Etcd::Api
  private getter create_api : Proc(Etcd::Api)

  delegate close, to: api.connection

  def initialize(
    url : URI,
    api_version : String? = nil
  )
    @create_api = ->{ Etcd::Api.new(uri: url) }
    @api = @create_api.call
  end

  def initialize(
    host : String = "localhost",
    port : Int32? = nil,
    api_version : String? = nil
  )
    @create_api = ->{ Etcd::Api.new(host: host, port: port) }
    @api = @create_api.call
  end

  def initialize(
    host : String = "localhost",
    port : Int32? = nil,
    username : String? = nil,
    password : String? = nil,
    api_version : String? = nil
  )
    @create_api = ->{ Etcd::Api.new(host: host, port: port, username: username, password: password) }
    @api = @create_api.call
  end

  def api_version
    api.api_version
  end

  def spawn_api : Etcd::Api
    create_api.call
  end

  {% for component in %w(kv lease maintenance watch) %}
    # Provide an object for managing {{component.id}}. See `Docker::{{component.id.capitalize}}`.
    def {{component.id}} : {{component.id.capitalize}}
      @{{component.id}} ||= {{component.id.capitalize}}.new(self)
    end
  {% end %}
end
