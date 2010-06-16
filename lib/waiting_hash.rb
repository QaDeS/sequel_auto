class WaitingHash < Hash
  undef clear, delete, delete_if, merge!, reject!, replace, update, store
  def wait_all(*keys, &block)
    callback = callback_proc(*keys, &block)
    missing = keys.reject{|k| self.has_key? k}
    missing.each do |key|
      waiting[key] << callback
    end
    (keys.size - missing.size).times { callback.call }
  end

  def []=(key, value)
    result = super
    if blocks = waiting.delete(key)
      blocks.each { |block| block.call }
    end
    result
  end

  # Returns
  # => false when none
  # => an array of the unresolved keys otherwise
  def remaining_waits
    waiting.empty? ? false : waiting.keys
  end

  private
  def callback_proc(*keys, &block)
    to_go = keys.size
    proc {
      block.call keys.map{ |key| self[key] } if (to_go -= 1) == 0
    }
  end

  def waiting
    @waiting ||= Hash.new{ |h,k| h[k] = [] }
  end
end
