class Etcd::Auth
  getter token : String
  private getter connection : HTTP::Client

  def initialize(@connection = nil, @username : String? = nil, @password : String? = nil, @api_version : String? = "v3beta")
    @token = authenticate
  end

  # auth/authenticate
  def authenticate
    body = {
      "name" => @username,
      "password" => @password,
    }.to_json

    response = @connection.post("/#{@api_version}/auth/authenticate", headers: nil, body: body)
    @token = JSON.parse(response.body)["token"].to_s
  rescue ex
    raise "authenticate get token error: #{JSON.parse(response.body)}" if response
    raise "authenticate can't get reponse: #{ex}"
  end

  # auth/disable
  def disable
    raise "unimplemented"
  end

  # auth/enable
  def enable
    raise "unimplemented"
  end

  # auth/role/add
  def role_add
    raise "unimplemented"
  end

  # auth/role/delete
  def role_delete
    raise "unimplemented"
  end

  # auth/role/get
  def role_get
    raise "unimplemented"
  end

  # auth/role/grant
  def role_grant
    raise "unimplemented"
  end

  # auth/role/list
  def role_list
    raise "unimplemented"
  end

  # auth/role/revoke
  def role_revoke
    raise "unimplemented"
  end

  # auth/user/add
  def user_add
    raise "unimplemented"
  end

  # auth/user/changepw
  def user_changepw
    raise "unimplemented"
  end

  # auth/user/delete
  def user_delete
    raise "unimplemented"
  end

  # auth/user/get
  def user_get
    raise "unimplemented"
  end

  # auth/user/grant
  def user_grant
    raise "unimplemented"
  end

  # auth/user/list
  def user_list
    raise "unimplemented"
  end

  # auth/user/revoke
  def user_revoke
    raise "unimplemented"
  end
end
