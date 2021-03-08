require "./base"

module Etcd::Model
  struct AlarmArray < WithHeader
    getter alarms : Array(AlarmItem)
  end

  struct AlarmItem < Base
    getter alarm : String
    @[JSON::Field(converter: Etcd::Model::StringTypeConverter(UInt64))]
    getter member_id : UInt64
  end

  struct Revision < WithHeader
    getter compact_revision : String
    getter hash : Int32
  end

  struct Snapshot < Base
    getter error : Error?
    getter result : SnapshotResult?
  end

  struct SnapshotResult < WithHeader
    getter blob : String
    getter remaining_bytes : String
  end

  struct Status < WithHeader
    getter version : String
    @[JSON::Field(key: "dbSize", converter: Etcd::Model::StringTypeConverter(Int64))]
    getter db_size : Int64
    @[JSON::Field(converter: Etcd::Model::StringTypeConverter(UInt64))]
    getter leader : UInt64
    @[JSON::Field(key: "raftIndex", converter: Etcd::Model::StringTypeConverter(UInt64))]
    getter raft_index : UInt64
    @[JSON::Field(key: "raftTerm", converter: Etcd::Model::StringTypeConverter(UInt64))]
    getter raft_term : UInt64
  end
end
