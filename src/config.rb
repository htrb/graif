class GraifConfig
  def initialize(conf_file)
    @conf = {}
    @file = conf_file

    read
  end

  def read
    return unless (File.exist?(@file))
    File.open(@file, "r:utf-8") { |f|
      f.each { |l|
        l.chomp!
        n = l.index("\t")
        key = l[0..(n - 1)]
        val = l[(n + 1)..- 1]
        @conf[key] = val
      }
    }
  end

  def save
    File.open(@file, "w:utf-8") {|f|
      @conf.each {|k, v|
        f.puts("#{k}\t#{v}")
      }
    }
  end

  def get_conf(key)
    @conf[key]
  end

  def set_conf(key, val)
    @conf[key] = val
  end

  def [](key)
    get_conf(key)
  end

  def []=(key, val)
    set_conf(key, val)
  end
end
