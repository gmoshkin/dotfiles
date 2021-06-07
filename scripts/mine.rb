require 'parallel'
require 'json'

class Object
  def say
    print self, "\n"
  end

  def put
    puts self
  end

  def do(&block)
    yield self
  end
end

class String
  def parse_json
    JSON.parse self
  end
end

def ceil x
  x.ceil
end

def json_file f
  JSON.parse File.open(f).read
end
