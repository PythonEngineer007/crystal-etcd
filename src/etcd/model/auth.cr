require "./base"

module Etcd::Model
  struct Token < WithHeader
    getter token : String
  end

  struct PermArray < WithHeader
    getter perm : Array(PermItem)
  end

  struct PermItem < WithHeader
    getter key : String
    @[JSON::Field(key: "permType")]
    getter perm_type : String # should be READ
    getter range_end : String
  end

  struct RoleArray < WithHeader
    getter roles : Array(String)
  end

  struct UserArray < WithHeader
    getter user : Array(String)
  end
end
