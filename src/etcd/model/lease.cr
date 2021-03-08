require "./base"

module Etcd::Model
  struct LeasesArray < WithHeader
    getter leases : Array(LeasesItem)
  end

  struct LeasesItem < Base
    @[JSON::Field(key: "ID", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter id : Int64
  end

  struct TimeToLive < WithHeader
    @[JSON::Field(key: "ID", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter id : Int64
    @[JSON::Field(key: "TTL", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter ttl : Int64
    @[JSON::Field(key: "grantedTTL", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter granted_ttl : Int64
    getter keys : Array(String)?
  end

  # Returns error
  struct Grant < WithHeader
    @[JSON::Field(key: "ID", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter id : Int64
    @[JSON::Field(key: "TTL", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter ttl : Int64
    getter error : String?
  end

  # Returns error
  struct KeepAlive < Base
    getter error : KeepAliveError?
    getter result : KeepAliveResult?
  end

  struct KeepAliveError < Base
    getter details : Array(NamedTuple(type_url: String, value: String))
    getter grpc_code : Int32
    getter http_code : Int32
    getter http_status : String
    getter message : String
  end

  struct KeepAliveResult < WithHeader
    @[JSON::Field(key: "ID", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter id : Int64
    @[JSON::Field(key: "TTL", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter ttl : Int64
  end
end
