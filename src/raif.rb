# $Id: raif.rb,v 1.65 2011/09/25 12:57:52 hito Exp $

require 'rexml/document'
require 'csv'

def sanitize(str)
  str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
end

class Zaif_category
  [
   :INCOME,
   :INCOME_HAVE_CHILDREN,
   :EXPENSE,
   :EXPENSE_HAVE_CHILDREN,
   :ALL_HAVE_CHILDREN,
   :ALL,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  attr_reader :parent, :children, :expense, :income
  include Enumerable

  def initialize(id, name, parent = nil, expense = true, income = false)
    @id = id
    @name = name
    @expense = expense
    @income = income
    @children = []
    @parent = parent
  end

  def to_i
    @id
  end

  def to_s
    @name
  end

  def add_from_data(element)
    id = element.attributes['id'].to_i
    expense = element.attributes['expense']
    income = element.attributes['income']
    exp = true
    exp = (expense == '1') if (expense)
    inc = (income == '1')
    name = ''
    element.elements.each('name') {|e|
      name = e.text
    }
    category = Zaif_category.new(id, name, self, exp, inc)
    add_child(category)
    element.elements.each('category') {|e|
      category.add_from_data(e)
    }
  end

  def delete_all_child
    children.clear
  end

  def add_child(category)
    @children.push(category)
  end

  def search_id(id)
    self.find {|c|
      c.to_i == id
    }
  end

  def each_child(&block)
    @children.each {|c|
      yield(c)
    }
  end

  def each(&block)
    if (@id != 0)
      yield(self)
    end

    @children.each {|c|
      c.each {|d|
        yield(d)
      }
    }
  end

  def xml
    s = ''
    if (@id != 0)
      expense = @expense ? '1': '0'
      income = @income ? '1': '0'
      s += %Q!<category id="#{@id}" expense="#{expense}" income="#{income}"><name>#{sanitize(@name)}</name>!
      s += "\n" if (@children.length > 0)
    end

    @children.each {|c|
      s += c.xml
    }
    s += "</category>\n" if (@id != 0)
    s
   end
end

class Zaif_account
  attr_reader :credit

  def Zaif_account::new_from_data(element)
    id = element.attributes['id'].to_i
    credit = false
    credit = true if (element.attributes['credit'])
    name = ''
    element.elements.each('name') {|e|
      name = e.text
    }
    Zaif_account.new(id, name, credit)
  end

  def initialize(id, name, credit = false)
    @id = id
    @name = name
    @credit = credit
  end

  def to_i
    @id
  end

  def to_s
    @name
  end

  def xml
    credit = ''
    credit = ' credit="1"' if (@credit)
    %Q!<account id="#{@id}"#{credit}><name>#{sanitize(@name)}</name></account>\n!
  end
end

class Zaif_config
  attr_reader :account, :category
  ID_OFFSET = 10000

  def initialize
    @config_file = "config.xml"
    @category = Zaif_category.new(0, nil)
    @account = []

    def @account.get_by_id (id)
      self.find {|a|
        a.to_i == id
      }
    end
  end

  def read(file = @config_file)
    return unless (File.readable?(file))
    file = File.new(file)
    begin
      zaif_file = REXML::Document.new(file)
    rescue => ever
      #ToDo: Check
    end
    file.close
    return unless (zaif_file && zaif_file.elements)
    zaif_file.elements.each('zaifconfig') {|e|
      e.each {|i|
        next unless (i.is_a?(REXML::Element))
        case i.name
        when 'category'
          @category.add_from_data(i)
        when 'account'
          @account.push(Zaif_account.new_from_data(i))
        end
      }
    }
  end

  def clear_account
    @account.clear
  end

  def clear_category
    @category.delete_all_child
  end

  def get_category_by_id(id, expense, income, create = true)
    return '' if (! id || id == 0)
    c = @category.search_id(id)
    c = Zaif_category.new(id, (id - ID_OFFSET).to_s, nil, expense, income) if (!c && create)
    c
  end

  def get_account_by_id(id, create = true)
    return nil if (! id || id == 0)
    account = @account.get_by_id(id)
    account = Zaif_account.new(id, (id - ID_OFFSET).to_s, 31, false) if (!account && create)
    account
  end

  def add_account(id, name, credit = false)
    @account.push(Zaif_account.new(id, name, credit))
  end

  def xml
    s = %Q!<?xml version="1.0" encoding="utf-8"?>\n<zaifconfig>\n!
    s += @category.xml
    @account.each {|a|
      s += a.xml
    }
    s += "</zaifconfig>\n"
  end

  def save
    tmp_file = "#config_tmp.xml"
    File.open(tmp_file, "w") {|f|
      f.print xml
    }
    File.rename(tmp_file, @config_file)
  end
end

class Zaif_item
  attr_reader :type, :category, :account, :time, :amount, :memo, :account_to, :fee, :fee_sign, :exceptional

  TYPE_EXPENSE = 1
  TYPE_INCOME  = 2
  TYPE_MOVE    = 3
  TYPE_ADJUST  = 4

  def initialize(type, account, time, amount, category = nil, memo = nil, account_to = nil, fee = nil, fee_sign = nil, exceptional = false)
    @type = type
    @category = category
    @account = account
    @time = time
    @amount = amount
    @memo = memo
    @account_to = account_to
    @fee = fee
    @fee_sign = fee_sign
    @exceptional = exceptional
  end

  def Zaif_item.set_config(cfg)
    @@zaif_config = cfg
  end

  def Zaif_item.new_from_csv(str)
    return nil unless (str)
    d = CSV.parse_line(str)
    return nil if (d.length != 9)
    type = d[0].to_i
    time = d[2].split(':').collect{|t| t.to_i}
    return nil if (d[1].size < 1)
    return nil if (time.size != 2 ||
                     time[0] < 0 || time[0] > 24 ||
                     time[1] < 0 || time[1] > 59)
    case type
    when TYPE_EXPENSE
      return nil if (d[4].size < 1)
      Zaif_item.new(type, d[1].to_i, d[2], d[3].to_i, d[4].to_i, d[5])
    when TYPE_INCOME
      Zaif_item.new(type, d[1].to_i, d[2], d[3].to_i, d[4].to_i, d[5])
    when TYPE_MOVE
      return nil if (d[6].size < 1)
      Zaif_item.new(type, d[1].to_i, d[2], d[3].to_i, d[4].to_i, d[5],
                    d[6].to_i, d[7].to_i, d[8].to_i)
    when TYPE_ADJUST
      Zaif_item.new(type, d[1].to_i, d[2], d[3].to_i, nil, d[5])
    else
      nil
    end
  end

  def csv
    CSV.generate_line([@type, @account, @time, @amount, @category,
                        @memo, @account_to, @fee, @fee_sign])
  end

  def csv2(y, m, d)
    CSV.generate_line([
                       @type,
                       @account,
                       @@zaif_config.get_account_by_id(@account).to_s,
                       "#{y}/#{m}/#{d}",
                       @time,
                       @amount,
                       @category,
                       @@zaif_config.get_category_by_id(@category, false, false).to_s,
                       @memo,
                       @account_to,
                       @@zaif_config.get_account_by_id(@account_to).to_s,
                       @fee,
                       @fee_sign,
                      ])
  end

  def xml
    c = (! @category || @category == 0) ? "": %Q! category="#{@category}"!
    a = (! @account || @account == 0) ? "": %Q! account="#{@account}"!
    at = (! @account_to || @account_to == 0) ? "": %Q! accountTo="#{@account_to}"!
    e = (@exceptional)? 'true': 'false'
    case @type
    when TYPE_EXPENSE
      s = sprintf(%Q!<item type="%d"%s%s exceptional="%s" time="%s" amount="%d">\n!,
                  @type, c, a, e, @time, @amount)
    when TYPE_INCOME
      s = sprintf(%Q!<item type="%d"%s%s exceptional="%s" time="%s" amount="%d">\n!,
                  @type, c, a, e, @time, @amount)
    when TYPE_MOVE
      s = sprintf(%Q!<item type="%d"%s%s fee="%d" feeSign="%d" time="%s" amount="%d">\n!,
                  @type, a, at, @fee, @fee_sign, @time, @amount)
    when TYPE_ADJUST
      s = sprintf(%Q!<item type="%d"%s time="%s" amount="%d">\n!,
                  @type, a, @time, @amount)
    end
    s += sprintf(" <memo>%s</memo>\n", sanitize(@memo)) if (@memo)
    s += "</item>\n"
  end

  def update(account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
    @category = category
    @account = account
    @time = time
    @amount = amount
    @memo = memo
    @account_to = account_to
    @fee = fee
    @fee_sign = fee_sign
    @exceptional = exceptional
  end

  def match(arg, parm)
    var = instance_variable_get(parm)
    if (var.class == String)
      var.match(arg)
    else
      var == arg.to_i
    end
  end
end

class Zaif_date
  include Enumerable
  attr_reader :date

  def initialize(d)
    @date = d
    @items = []
  end

  def add(i)
    @items.push(i)
    sort
  end

  def add_from_csv(str)
    str.split(/[\r\n]+/).each {|l|
      i = Zaif_item.new_from_csv(str)
      @items.push(i) if (i)
    }
  end

  def sort
    @items.sort! {|a, b|
      a.time <=> b.time
    }
  end

  def xml
    s = %Q!<date date="#{@date}">\n!
    @items.each {|i|
      s += i.xml
    }
    s += "</date>\n"
  end

  def each(&block)
    @items.each {|i|
      yield(i)
    }
  end

  def delete(item)
    @items.delete(item)
  end
end

class Zaif_budget
  attr_accessor :category, :budget, :sumup

  def initialize(category, budget, sumup)
    @category = category
    @budget = budget
    @sumup = sumup
  end

  def add(val)
    @budget += val
  end

  def xml
    %Q!<budget category="#{@category}" budget="#{@budget}" sumup="#{@sumup ? 1 : 0}"/>\n!
  end
end

class Zaif_month
  include Enumerable

  attr_reader :year, :month, :subtotals, :Month_array, :budget
  DATE_NUM = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  Month_array = {}

  def initialize(year, month)
    @modified = false
    @year = year
    @month = month
    @subtotals = {}
    @budget = {}

    if (month == 2)
      if (year % 4 == 0 && year % 400 == 0)
        @num_of_day = 29
      elsif (year % 4 == 0 && year % 100 == 0)
        @num_of_day = 28
      elsif (year % 4 == 0)
        @num_of_day = 29
      else
        @num_of_day = 28
      end
    elsif (month > 0 && month < 13)
      @num_of_day = DATE_NUM[month - 1]
    else
      raise "Invalid date"
    end

    @data = Array.new(@num_of_day)
    @data.each_index {|i|
      @data[i] = Zaif_date.new(i + 1)
    }

    def @budget.sum
      self.inject(0) {|sum, v|
        sum + v[1].budget
      }
    end

    def @subtotals.[](id)
      val = super
      val = 0 unless (val)
      val
    end
  end

  def size
    @data.size
  end

  def each(&block)
    @data.each {|d|
      d.each {|i|
        yield(d, i)
      }
    }
  end

  def find_init
    @find_index = 0
  end

  def find_next(str, parm = :@memo)
    i = 0
    find {|d, item|
      if (item.match(str, parm))
        i += 1
        if (i - 1 == @find_index)
          @find_index = i
          true
        else
          false
        end
      else
        nil
      end
    }
  end

  def [](d)
    return nil if (d < 1 || d > @num_of_day)
    @data[d - 1]
  end

  def add_item(d, item)
    return nil if (d < 1 || d > @num_of_day)
    @modified = true
    @data[d - 1].add(item)
    @data[d - 1].sort
  end

  def delete_item(d, item)
    return nil if (d < 1 || d > @num_of_day)
    @modified = true
    @data[d - 1].delete(item)
    @data[d - 1].sort
  end

  def subtotal(id, amount)
    @subtotals[id] = amount
  end

  def xml
    s = %Q!<?xml version="1.0" encoding="utf-8"?>\n<zaifdata>\n!
    @budget.each {|k, b|
      if (b.budget !=0 || b.sumup)
        s += sprintf(%Q!<budget category="%d" budget="%d" sumup="%s"/>\n!,
                     b.category, b.budget, b.sumup ? "1" : "0")
      else
        s += sprintf(%Q!<budget category="%d"/>\n!, b.category)
      end
    }
    @data.each {|d|
      s += d.xml
    }
    s += "<subtotals>\n"
    @subtotals.each {|v|
      if (v[0] != 0)
        s += sprintf(%Q!<subtotal account="%d" amount="%d">\n</subtotal>\n!, v[0], v[1])
      else
        s += sprintf(%Q!<subtotal amount="%d">\n</subtotal>\n!, v[1])
      end
    }
    s += "</subtotals>\n</zaifdata>\n"
  end

  def read
    return false unless (File.readable?("data_#{@year*100+@month}.xml"))
    file = File.new("data_#{@year*100+@month}.xml")
    begin
      zaif_file = REXML::Document.new(file)
    rescue => ever
      #ToDo: Check
    end
    file.close
    return false unless (zaif_file && zaif_file.elements)
    zaif_file.elements.each("zaifdata") {|e|
      e.each {|i|
        next unless (i.is_a?(REXML::Element))
        case i.name
        when "date"
          next if (i.elements.size < 1)
          d = i.attributes["date"].to_i
          i.elements.each {|e|
            exceptional = false
            category = nil
            memo = nil
            account_to = nil
            fee = nil
            fee_sign = nil
            type = e.attributes["type"].to_i
            account = e.attributes["account"].to_i
            time = e.attributes["time"]
            amount = e.attributes["amount"].to_i
            memo = e.elements[1].text if (e.elements[1])
            case type
            when Zaif_item::TYPE_EXPENSE
              category = e.attributes["category"].to_i
              exceptional = (e.attributes["exceptional"] == 'true') ? true: false
            when Zaif_item::TYPE_INCOME
              category = e.attributes["category"].to_i
              exceptional = (e.attributes["exceptional"] == 'true') ? true: false
            when Zaif_item::TYPE_MOVE
              account_to = e.attributes["accountTo"].to_i
              fee = e.attributes["fee"].to_i
              fee_sign = e.attributes["feeSign"].to_i
            when Zaif_item::TYPE_ADJUST
            end
            item = Zaif_item.new(type, account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
            add_item(d, item)
          }
        when "subtotals"
          next if (i.elements.size < 1)
          i.elements.each {|e|
            account = e.attributes["account"].to_i
            amount = e.attributes["amount"].to_i
            subtotal(account, amount)
          }
        when "budget"
          sumup = 0
          budget = 0

          category = i.attributes["category"].to_i
          budget = i.attributes["budget"].to_i
          sumup = i.attributes["sumup"].to_i

          @budget[category] = Zaif_budget.new(category, budget, sumup == 1)
        end
      }
    }
    @modified = false
    return true
  end

  def save_modified
    save if (@modified)
    @modified = false
  end

  def save
    tmp_file = "#data_#{@year*100+@month}tmp.xml"
    File.open(tmp_file, "w") {|f|
      f.print xml
    }
    File.rename(tmp_file, "data_#{@year*100+@month}.xml")
  end

  def update_item(d, data, account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
    day = self[d]
    return nil unless (day)

    item = day.find {|i|
      i == data
    }
    return nil unless (item)

    item.update(account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
    day.sort
    @modified = true
  end

  def get_account_summary(account, date = nil, time = nil)
    @data.each {|day|
      break if (date && day.date > date)
      day.each {|item|
        ac = account[item.account]
        break if (date && day.date == date && time && item.time > time)
        next unless (ac)
        case item.type
        when Zaif_item::TYPE_EXPENSE
          account[0][0] -= item.amount
          account[0][2] += item.amount
          account[item.account][0] -= item.amount
          account[item.account][2] += item.amount
        when Zaif_item::TYPE_INCOME
          account[0][0] += item.amount
          account[0][1] += item.amount
          account[item.account][0] += item.amount
          account[item.account][1] += item.amount
        when Zaif_item::TYPE_MOVE
          account[item.account][0] -= item.amount
          account[item.account][3] -= item.amount
          if (item.fee_sign < 0)
            account[0][0] -= item.fee
            account[0][2] += item.fee
            account[item.account][0] -= item.fee
            account[item.account][2] += item.fee
          end

          ac2 = account[item.account_to]
          next unless (ac2)

          account[item.account_to][0] += item.amount
          account[item.account_to][3] += item.amount
          if (item.fee_sign > 0)
            account[0][0] += item.fee
            account[0][1] += item.fee
            account[item.account_to][0] += item.fee
            account[item.account_to][1] += item.fee
          end
        when Zaif_item::TYPE_ADJUST
          diff = item.amount - account[item.account][0]
          account[0][0] += diff
          account[0][4] += diff
          account[item.account][0] = item.amount
          account[item.account][4] += diff
        end
      }
    }
  end

  def get_prev(recursive = true)
    y = @year
    m = @month
    if (m == 1)
      m = 12
      y -= 1
    else
      m -= 1
    end
    Zaif_month.get_month_data(y, m, recursive)
  end

  def get_next(recursive = true)
    y = @year
    m = @month

    if (m == 12)
      m = 1
      y += 1
    else
      m += 1
    end
    Zaif_month.get_month_data(y, m, recursive)
  end

  def Zaif_month.get_month_data(y, m, recursive = true)
    if (m > 12)
      y += (m / 12).to_i
      m %= 12
    elsif (m < 1)
      m = m.abs
      y -= (m / 12).to_i + 1
      m = 12 - m % 12
    end

    month = Month_array["#{y*100+m}"]
    unless (month)
      Month_array["#{y*100+m}"] = Zaif_month.new(y, m)
      month = Month_array["#{y*100+m}"]
      if (! month.read && recursive)
        prev = month.get_prev(false)
        prev.subtotals.each {|k, v|
          v = 0 if (k == 0)
          month.subtotal(k, v)
        } if (prev)
      end
    end
    month
  end

  def get_category_summary(category, include_exceptional = true)
    summary = {}
    category.each {|c|
      summary[c.to_i] = [0, 0]
    }

    @data.each {|day|
      day.each {|item|
        next unless (summary[item.category])
        case item.type
        when Zaif_item::TYPE_EXPENSE
          summary[item.category][0] += item.amount if (include_exceptional || (! include_exceptional && ! item.exceptional))
        when Zaif_item::TYPE_INCOME
          summary[item.category][1] += item.amount if (include_exceptional || (! include_exceptional && ! item.exceptional))
        when Zaif_item::TYPE_MOVE
          # nothing to do becase move fee does not have a category.
        end
      }
    }

    summary
  end

  def set_budget(id, budget, sumup)
    b = @budget[id]
    if (b)
      b.category = id
      b.budget =budget.to_i
      b.sumup = sumup
    else
      @budget[id] = Zaif_budget.new(id, budget.to_i, sumup)
    end
    @modified = true
  end

  def modified
    @modified = true
  end

  def modified?
    @modified
  end
end

class Zaif_data
  def initialize
    @month_array = Zaif_month::Month_array
    @config = Zaif_config.new
    Zaif_item.set_config(@config)
  end

  def items(y, m, d)
    month = @month_array["#{y*100+m}"]
    if (month)
      month[d]
    else
      nil
    end
  end

  def get_day_data(y, m, d)
    get_month_data(y, m)[d]
  end

  def get_month_data(y, m)
    return nil if (!y || !m)
    month = Zaif_month.get_month_data(y, m)
    if (month.budget.size == 0)
      month.get_prev.budget.each {|id, val|
        month.budget[id] = val.dup
      }
    end
    month
  end

  def subtotal(y, m, id, amount)
    month = get_month_data(y, m)
    month.subtotal(id, amount)
  end

  def read(y, m)
    get_month_data(y, m).read
  end

  def read_config
    @config.read
  end

  def xml(y, m)
    s = ""
    m = @month_array["#{y*100+m}"]
    s = m.xml if (m)
    s
  end

  def config_xml
    @config.xml
  end

  def get_accounts
    @config.account
  end

  def clear_data
    @month_array.clear
  end

  def clear_account
    @config.clear_account
  end

  def clear_category
    @config.clear_category
  end

  def add_account(id, name, credit = false)
    @config.add_account(id, name, credit)
  end

  def get_account_by_id(id)
    @config.get_account_by_id(id)
  end

  def get_category_by_id(id, expense, income, create = true)
    @config.get_category_by_id(id, expense, income, create)
  end

  def get_root_category
    @config.category
  end

  def update_subtotal(y, m, d, item)
    month = get_month_data(y, m)
    ac = get_account_by_id(item.account)
    ac2 = get_account_by_id(item.account_to)
    calculate_subtotal(y, m)
  end

  def update_item(y, m, d, item, account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
    month = get_month_data(y, m)
    r = month.update_item(d, item, account, time, amount, category, memo, account_to, fee, fee_sign, exceptional)
    update_subtotal(y, m, d, item)
    r
  end

  def add_item(y, m, d, item)
    month = get_month_data(y, m)
    r = month.add_item(d, item)
    update_subtotal(y, m, d, item)
    r
  end

  def delete_item(y, m, d, item)
    month = get_month_data(y, m)
    r = month.delete_item(d, item)
    update_subtotal(y, m, d, item)
    r
  end

  def save_data
    @month_array.each {|key, m|
      m.save_modified
    }
  end

  def save_config
    @config.save
  end

  def get_account_summary_month(y, m, d = nil, t = nil, &block)
    month = get_prev_month_data(y, m)
    prev_subtotals = month.subtotals

    account = {}
    total = @config.account.inject(0) {|sum, a|
      account[a.to_i] = [prev_subtotals[a.to_i].to_i, 0, 0, 0, 0]
      sum + prev_subtotals[a.to_i].to_i
    }
    account[0] = [total, 0, 0, 0, 0, 0]

    month = get_month_data(y, m)
    month.get_account_summary(account, d, t)
    subtotals = month.subtotals

    s = account[0]
    if (!d && !t && subtotals[0] != s[1] - s[2])
      subtotals[0] = s[1] - s[2]
      month.modified
    end
    yield(nil, s[0], s[1], s[2], s[3], s[4], total, 1)
    @config.account.each {|a|
      s = account[a.to_i]
      if (!d && !t && a.to_i > 0 && subtotals[a.to_i] != s[0])
        subtotals[a.to_i] = s[0]
        month.modified
      end
      yield(a, s[0], s[1], s[2], s[3], s[4], prev_subtotals[a.to_i].to_i, 1)
    }
    month
  end

  def get_account_summary_year(y, start = 0, &block)
    data = {}

    prev_subtotals = get_prev_month_data(y, 1 + start).subtotals
    @config.account.each {|a|
      data[a.to_i] = [0, 0, 0, 0, 0, prev_subtotals[a.to_i].to_i]
    }
    (1..12).each {|m|
      get_account_summary_month(y, m + start) {
        |account, sum, income, expenses, move, adjustment, balance, date, dummy|

        a = account.to_i
        if (data[a])
          data[a][0] = sum
          data[a][1] += income
          data[a][2] += expenses
          data[a][3] += move
          data[a][4] += adjustment
        else
          data[a] = [sum, income, expenses, move, adjustment, balance, date]
        end
      }
      yield(nil, nil, nil, nil, nil, nil, nil, (m - 1)/12.0)
    }
    yield(nil, data[0][0], data[0][1], data[0][2], data[0][3], data[0][4], data[0][5], 1)
    @config.account.each {|a|
      v = data[a.to_i]
      yield(a, v[0], v[1], v[2], v[3], v[4], v[5], 1)
    }
  end

  def last_data_file
    file = Dir.glob("data_[0-9][0-9][0-9][0-9][0-9][0-9].xml").sort[-1]
    file =~ /(\d{4})(\d{2})/
    [$1.to_i, $2.to_i]
  end

  def get_prev_month_data(y, m)
    month = Zaif_month.get_month_data(y, m)
    month.get_prev
  end

  def get_next_month_data(y, m)
    month = Zaif_month.get_month_data(y, m)
    month.get_next
  end

  def calculate_subtotal(y, m)
    last_y = last_m = 0
    if (true)
      t = Time.now
      last_y = t.year
      last_m = t.month
    else
      last_file = last_data_file
      last_month_data = @month_array.max {|a, b| (a[1].year * 100 + a[1].month) - (b[1].year * 100 + b[1].month)}
      yy = last_month_data[1].year
      mm = last_month_data[1].year
      if (yy > last_file[0])
        last_y = yy
        last_m = mm
      elsif (yy == last_file[0])
        last_y = yy
        last_m = [mm, last_file[1]].max
      else
        last_y = last_file[0]
        last_m = last_file[1]
      end
    end

    begin
      month = get_account_summary_month(y, m) {|*parm|}
      break unless (month.modified?)
      if (m == 12)
        m = 1
        y += 1
      else
        m += 1
      end
    end while (y < last_y || (y == last_y  && m <= last_m))
  end

  def get_category_summary(y, m, include_exceptional = true)
    month = Zaif_month.get_month_data(y, m)
    month.get_category_summary(@config.category, include_exceptional)
  end

  def get_category_summary_year(y, start = 0, include_exceptional = true, &block)
    (1..12).inject({}) {|summary ,m|
      get_category_summary(y, m + start, include_exceptional).each {|k, v|
        c = get_category_by_id(k, false, false, false)
        if (summary[k].nil?)
          summary[k] = v
        else
          summary[k][0] += v[0]
          summary[k][1] += v[1]
        end
      }
      yield((m - 1) / 12.0)
      summary
    }
  end

  def get_month_budget(y, m)
    month = get_month_data(y, m)
    month.budget
  end

  def get_year_budget(y, start = 0)
    (1..12).inject({}) {|budget, m|
      month = get_month_data(y, m + start)
      month.budget.each {|k, v|
        if (budget[k].nil?)
          budget[k] = Zaif_budget.new(v.category, v.budget, v.sumup)
        else
          budget[k].add(v.budget)
        end
      }
      budget
    }
  end

  def get_account_summation(aid, y, m, d, t)
    sum = 0

    a = @config.get_account_by_id(aid, false)
    return 0 unless (a)

    get_account_summary_month(y, m, d, t) {|account, s, *parm|
      sum = s if (aid == account.to_i)
    }
    sum
  end

  def modified
    @month_array.find {|k, m| m.modified?}
  end
end
