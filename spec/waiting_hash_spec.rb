require 'waiting_hash'

unless [].respond_to? :each_cons
  class Array
    def each_cons(count)
      buffer = []
      each do |e|
        buffer << e
        next unless buffer.size == count
        yield buffer
        buffer.shift
      end
    end
  end
end
describe WaitingHash do
  it "should work properly" do
    h = WaitingHash.new
    keys = (0..10_000).to_a
    reverse_keys = keys.reverse
    values = keys

    start = Time.now
    result = []
    keys.each_cons(2) do |k1, k2|
      h.wait_all k1, k2 do |v1, v2|
        result << "#{k1} => #{v1}, #{k2} => #{v2}"
      end
    end

    reverse_keys.zip(values).each_with_index do |(k, v), index|
      unless index == 0 # omit one key so we can test remaining_waits
        h[k] = v
      end
    end

    reverse_keys.each_cons(2) do |k1, k2|
      h.wait_all k1, k2 do |v1, v2|
        result << "#{k1} => #{v1}, #{k2} => #{v2}"
      end
    end

    puts "Took #{(Time.now - start).to_f} seconds"
    result.size.should == (keys.size - 2) * 2
    h.remaining_waits.should == [reverse_keys.first]
  end
end

