require "./base"

module Etcd::Model
  struct Token < WithHeader
    getter token : String
  end

  struct PermArray < WithHeader
    getter perm : Array(PermItem)
  end

  enum PermType
    READ
    WRITE
    READWRITE
  end

  struct PermItem < WithHeader
    @[JSON::Field(converter: Etcd::Model::StringTypeConverter(Bytes))]
    getter key : String
    @[JSON::Field(key: "permType")]
    getter perm_type : PermType
    @[JSON::Field(converter: Etcd::Model::StringTypeConverter(Bytes))]
    getter range_end : String
  end

  struct RoleArray < WithHeader
    getter roles : Array(String)
  end

  struct UserArray < WithHeader
    getter user : Array(String)
  end
end
