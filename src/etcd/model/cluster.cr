require "./base"

module Etcd::Model
  struct MemberAdd < WithHeader
    getter member : MemberItem
    getter members : Array(MemberItem)
  end

  struct MemberArray < WithHeader
    getter members : Array(MemberItem)
  end

  struct MemberItem
    @[JSON::Field(key: "ID", converter: Etcd::Model::StringTypeConverter(UInt64))]
    getter id : UInt64
    @[JSON::Field(key: "clientURLs")]
    getter client_urls : Array(String)
    @[JSON::Field(key: "isLearner")]
    getter is_learner : Bool
    getter name : String
    @[JSON::Field(key: "peerURLs")]
    getter peer_urls : Array(String)
  end
end
