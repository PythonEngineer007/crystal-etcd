require "simple_retry"
require "tokenizer"

require "./utils"
require "./model/watch"

class Etcd::Watch
  include Utils

  # Types for watch event filters
  enum Filter
    NOPUT    # filter put events
    NODELETE # filter delete events
  end

  private getter client : Etcd::Client

  def initialize(@client = Etcd::Client.new)
  end

  # Watches keys by prefix, passing events to a supplied block.
  # Exposes a synchronous interface to the watch session via `Etcd::Watcher`
  #
  # opts
  #  filters         filters filter the events at server side before it sends back to the watcher.                                           [Watch::Filter]
  #  start_revision  start_revision is an optional revision to watch from (inclusive). No start_revision is "now".                           Int64
  #  progress_notify progress_notify is set so that the etcd server will periodically send a WatchResponse with no events to the new watcher
  #                  if there are no recent events. It is useful when clients wish to recover a disconnected watcher starting from
  #                  a recent known revision. The etcd server may decide how often it will send notifications based on current load.         Bool
  #  prev_kv         If prev_kv is set, created watcher gets the previous Kv before the event happens.                                       Bool
  def watch_prefix(prefix, **opts, &block : Array(Model::WatchEvent) -> Void)
    encoded_prefix = Base64.strict_encode(prefix)
    opts = opts.merge({range_end: prefix_range_end(encoded_prefix), base64_keys: false})
    watch(encoded_prefix, **opts, &block)
  end

  # Watch a key in ETCD, returns a `Etcd::Watcher`
  # Exposes a synchronous interface to the watch session via `Etcd::Watcher`
  #
  # opts
  #  range_end       range_end is the end of the range [key, range_end) to watch.
  #  filters         filter the events at server side before it sends back to the watcher.                                           [Watch::Filter]
  #  start_revision  start_revision is an optional revision to watch from (inclusive). No start_revision is "now".                           Int64
  #  progress_notify progress_notify is set so that the etcd server will periodically send a WatchResponse with no events to the new watcher
  #                  if there are no recent events. It is useful when clients wish to recover a disconnected watcher starting from
  #                  a recent known revision. The etcd server may decide how often it will send notifications based on current load.         Bool
  #  prev_kv         If prev_kv is set, created watcher gets the previous Kv before the event happens.                                       Bool
  def watch(
    key,
    range_end : String? = nil,
    filters : Array(Watch::Filter)? = nil,
    start_revision : Int64? = nil,
    progress_notify : Bool? = nil,
    base64_keys : Bool = true,
    &block : Array(Model::WatchEvent) -> Void
  ) : Watcher
    if base64_keys
      key = Base64.strict_encode(key)
      range_end = range_end.try &->Base64.strict_encode(String)
    end

    Watcher.new(
      key: key,
      create_api: ->@client.spawn_api,
      range_end: range_end,
      filters: filters,
      start_revision: start_revision,
      progress_notify: progress_notify,
      &block
    )
  end

  # Wrapper for a watch session with etcd.
  #
  # ```
  # client = Etcd::Client.new
  # watcher = client.watch(key: "hello") do |e|
  #   # This block will be called upon each etcd event
  #   puts e
  # end
  #
  # spawn { watcher.start }
  # ```
  class Watcher
    Log = ::Log.for(self)

    getter key : String
    private getter create_api : Proc(Etcd::Api)
    private getter api : Etcd::Api
    private getter block : Proc(Array(Model::WatchEvent), Void)
    private getter range_end : String?
    private getter filters : Array(Watch::Filter)?
    private getter start_revision : Int64?
    private getter progress_notify : Bool?
    private getter watch_id : String { Random.rand(0_i64..Int64::MAX).to_s }

    private property event_channel : Channel(Array(Model::WatchEvent)) { Channel(Array(Model::WatchEvent)).new }

    getter? watching : Bool = false

    def initialize(
      @key,
      @create_api = ->Etcd::Api.new,
      @range_end = nil,
      @filters = nil,
      @start_revision = nil,
      @progress_notify = nil,
      &@block : Array(Model::WatchEvent) -> Void
    )
      @api = create_api.call
    end

    # Pass events to captured block
    private def forward_events
      self.event_channel = Channel(Array(Model::WatchEvent)).new if self.event_channel.closed?
      loop do
        select
        when event = self.event_channel.receive?
          break if event.nil?
          # Don't forward empty events
          @block.call(event) unless event.empty?
        when timeout 1.minute
          # If no events received, trigger a client reconnect as connection may be silently dropped
          api.connection.close
        end
      end
    end

    # Start the watcher
    def start
      raise Etcd::WatchError.new "Already watching `#{key}`" if watching?
      Log.context.set({
        key:       Base64.decode_string(key),
        range_end: range_end.try &->Base64.decode_string(String),
      })

      Log.debug { "consuming watch events" }

      spawn { forward_events }

      # Check out from the thread pool here
      post_body = {
        create_request: {
          :key             => key,
          :range_end       => range_end,
          :filters         => filters,
          :start_revision  => start_revision,
          :progress_notify => progress_notify,
          :watch_id        => watch_id,
        }.compact,
      }

      pp! post_body
      @watching = true

      SimpleRetry.try_to(
        base_interval: 50.milliseconds,
        max_interval: 10.seconds,
        randomise: 100.milliseconds
      ) do
        if watching?
          begin
            api.post("/watch", post_body) do |stream|
              consume_io(stream.body_io, json_chunk_tokenizer) do |chunk|
                begin
                  response = Model::WatchResponse.from_json(chunk)
                  pp! response
                  unless response.error.nil?
                    Log.error { "received error #{response.error} in watch" }
                    raise IO::EOFError.new
                  end

                  if response.cancelled?
                    Log.info { "cancelled watch feed" }
                    return
                  end

                  # Ignore "created" message
                  self.event_channel.send(response.result.events) unless response.created
                rescue e : Channel::ClosedError
                  return
                rescue e
                  # Ignore close events
                  return if e.message.try &.includes?("<EOF>")

                  raise Etcd::WatchError.new e.message
                end
              end
            end
          rescue e
            # Ignore timeouts
            unless e.is_a?(IO::Error) && e.message.try(&.includes? "Closed stream")
              Log.error(exception: e) { "while watching" }
            end

            # Generate a new api connection if still watching
            if watching?
              Log.warn { "#{e} generating new etcd client" }
              api.connection.close
              @api = create_api.call
            end

            raise e
          end
        end
      end
    end

    # Close the client and stop the watcher
    def stop
      # TODO: When adding pooling, return connection to the conn pool
      @watching = false
      self.event_channel.close

      client = create_api.call
      client.post("/watch", {cancel_request: {watch_id: watch_id}})
      client.connection.close

      api.connection.close
    end

    # Partitions IO into JSON chunks (only objects!)
    protected def json_chunk_tokenizer
      Tokenizer.new do |io|
        length, unpaired = 0, 0
        loop do
          case io.read_char
          when '{' then unpaired += 1
          when '}' then unpaired -= 1
          when Nil then break
          end

          length += 1
          break if unpaired.zero?
        end
        unpaired.zero? && length > 0 ? length : -1
      end
    end

    # Pulls tokens off stream IO, and calls block with tokenized IO
    # io          Streaming IO                                      IO
    # tokenizer   Tokenizer class with which the stream is parsed   Tokenizer
    # block       Block that takes a string                         Block
    protected def consume_io(io, tokenizer, &block : String -> Void)
      raw_data = Bytes.new(4096)
      while !io.closed?
        bytes_read = io.read(raw_data)
        break if bytes_read == 0 # IO was closed
        tokenizer.extract(raw_data[0, bytes_read]).each do |message|
          yield String.new(message)
        end
      end
    end
  end
end
