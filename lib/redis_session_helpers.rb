module RedisSessionHelpers

  def prefixed(sid)
    "#{default_options[:key_prefix]}#{sid}"
  end

  def find_by_session_id(sid)
    unless sid && (session = load_session_from_redis(sid))
      sid = generate_sid
      session = {}
    end

    [sid, session]
  end

  def load_session_from_redis(sid)
    data = redis.get(prefixed(sid))
    begin
      data ? decode(data) : nil
    rescue => e
      destroy_session_from_sid(sid, drop: true)
      on_session_load_error.call(e, sid) if on_session_load_error
      nil
    end
  end

  def decode(data)
    serializer.load(data)
  end

  def save_by_session_id(sid, session_data, options = nil)
    save_with_expiry(sid, session_data, true, options || env.fetch(ENV_SESSION_OPTIONS_KEY))
  end

  def save_with_expiry(key, value, encrypt = false, options = nil)
    expiry = (options || {})[:expire_after]
    value = encrypt ? encode(value) : value
    expiry ? redis.setex(prefixed(key), expiry, value) : redis.set(prefixed(key), value)

    key
  end

  def encode(session_data)
    serializer.dump(session_data)
  end

  def determine_serializer(serializer)
    serializer ||= :marshal
    case serializer
    when :marshal then Marshal
    when :json    then JsonSerializer
    when :hybrid  then HybridSerializer
    else serializer
    end
  end  

end
