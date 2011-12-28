# -*- coding: utf-8 -*-
# $Id: util.rb,v 1.85 2011/09/25 12:57:52 hito Exp $

class TreeViewColumnNumeric < Gtk::TreeViewColumn
  @@hide_zero = true

  def TreeViewColumnNumeric.hide_zero=(state)
    @@hide_zero = state
  end

  def initialize(title, renderer, column)
    super(title, renderer)
    set_cell_data_func(renderer) { |col, rend, model, iter|
      val = iter[column]
      
      str = if (val.kind_of?(Float))
              if (val == 0.0)
                "--"
              else
                iter[column] = val.to_i
                Commalize(val.to_i)
              end
            elsif (val.kind_of?(Integer))
              if (@@hide_zero && val == 0)
                ""
              elsif (COMMALIZE[0] < 1 || val.abs < 1000)
                val.to_s
              else
                Commalize(val)
              end
            else
              ""
            end
      rend.text = str
    }
  end
end

class MyLabel < Gtk::Label
  def initialize(s, f = false)
    super(s, f)
    self.xpad = 10
  end
end


class NumericEntry < Gtk::Entry
  Chars = "0123456789+*/-().,".unpack("c*")

  def initialize
    super

    signal_connect("key-press-event") {|w, e|
      if (e.keyval < 0xff && !Chars.index(e.keyval))
        w.signal_emit_stop("key-press-event")
      end
    }
  end

  def value=(val)
    self.text = val.to_s
  end

  def value
    begin
      str = self.text.gsub(COMMALIZE[1], '').delete('^0-9\+\*/\-()\.,')
      str.gsub!(',', '.') if (COMMALIZE[1] == '.')
      r = eval(str)
      r = nil unless (r.kind_of?(Numeric))
    rescue StandardError, ScriptError
      r = nil
    end
    r
  end
end

class IntegerEntry < NumericEntry
  def value=(val)
    self.text = Commalize(val.to_i)
  end

  def value
    r = super
    if (r)
      r.to_i
    else
      nil
    end
  end
end

class MonthYearComboBox < Gtk::ComboBox
  def initialize
    super
    ["月", "年"].each {|i|
      append_text(i)
    }
    self.active = 0
  end

  def month?
    self.active == 0
  end

  def year?
    self.active == 1
  end
end

class AccountTreeModel < Gtk::ListStore
  [
   :COLUMN_NAME,
   :COLUMN_ITEM,
   :COLUMN_UNIFIED_NAME,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  Account_name = {}
  Instances = []

  def AccountTreeModel::set_accouts(account)
    @@account = account
  end

  def AccountTreeModel::update
    Instances.each {|a|
      a.update
    }
  end

  def initialize
    super(String, Zaif_account, String)
    Instances.push(self)
    update
  end

  def update
    self.clear
    Account_name.clear
    @@account.each {|a|
      row = self.append
      name = a.to_s
      row[COLUMN_NAME] = name
      row[COLUMN_ITEM] = a
      if (Account_name[name].nil?)
        Account_name[name] = 0
        row[COLUMN_UNIFIED_NAME] = "#{a.to_s}"
      else
        Account_name[name] += 1
        row[COLUMN_UNIFIED_NAME] = "#{a.to_s}\t#{@account_name[name]}"
      end
    }
    Account_name.clear
    each {|model, path, iter|
      Account_name[iter[COLUMN_UNIFIED_NAME]] = iter[COLUMN_ITEM].to_i
    }
  end

  def get_id_by_name(name)
    Account_name[name]
  end
end

class AccountComboBox < Gtk::ComboBox
  Instances = []

  def AccountComboBox::update
    AccountTreeModel.update
    Instances.each {|a|
      a.update
    }
  end

  def initialize
    super(AccountTreeModel.new)
    renderer_s = Gtk::CellRendererText.new
    pack_start(renderer_s, true)
    set_attributes(renderer_s, :text => AccountTreeModel::COLUMN_NAME)
    Instances.push(self)
    update(0)
  end

  def update(active = 0)
    self.model.update
    self.active = active
  end

  def active
    if (active_iter)
      active_iter[AccountTreeModel::COLUMN_ITEM].to_i
    else
      if (model.iter_first)
        model.iter_first[AccountTreeModel::COLUMN_ITEM].to_i
      else
        0
      end
    end
  end

  def active=(id)
    if (id == 0)
      super(id)
    else
      self.model.each {|model, path, iter|
        set_active_iter(iter) if (iter[AccountTreeModel::COLUMN_ITEM].to_i == id)
      }
    end
  end

  def active_item
    active_iter[AccountTreeModel::COLUMN_ITEM]
  end
end

class CategoryTreeModel < Gtk::TreeStore
  [
   :COLUMN_NAME,
   :COLUMN_ITEM,
   :COLUMN_UNIFIED_NAME,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  Instances = []

  def CategoryTreeModel::set_category(category)
    @@category = category
  end

  def CategoryTreeModel::update(add_root = false)
    Instances.each {|c|
      c.update(add_root)
    }
  end

  def initialize(type, add_root = false, category = false)
    super(String, Zaif_category, String)
    @@category = category if (category)
    @category_name = {}
    @type = type

    Instances.push(self)

    update(add_root) if (@@category)
  end

  def update(add_root = false)
    self.clear
    if (add_root && @@category.children.size != 0)
      row = self.append(nil)
      row[COLUMN_NAME] = "Root"
      row[COLUMN_ITEM] = @@category
      row[COLUMN_UNIFIED_NAME] = "Root"
    end
    @category_name.clear
    @@category.each_child {|c|
      add_category(row, c)
    }
    @category_name.clear
    each {|model, path, iter|
      @category_name[iter[COLUMN_UNIFIED_NAME]] = iter[COLUMN_ITEM].to_i
    }
  end

  def add_category(row, category)
    if ((@type == Zaif_category::EXPENSE && category.expense) ||
        (@type == Zaif_category::INCOME && category.income) ||
        (@type == Zaif_category::EXPENSE_HAVE_CHILDREN &&
         category.children.size != 0 &&
         category.expense) ||
        (@type == Zaif_category::INCOME_HAVE_CHILDREN &&
         category.children.size != 0 &&
         category.income) ||
        (@type == Zaif_category::ALL_HAVE_CHILDREN &&
         category.children.size != 0) ||
        @type == Zaif_category::ALL)
      row = self.append(row)
      name = category.to_s
      row[COLUMN_NAME] = name
      row[COLUMN_ITEM] = category
      if (@category_name[name].nil?)
        @category_name[name] = 0
        row[COLUMN_UNIFIED_NAME] = "#{category.to_s}"
      else
        @category_name[name] += 1
        row[COLUMN_UNIFIED_NAME] = "#{category.to_s}\t#{@category_name[name]}"
      end
    end
    category.each_child {|c|
      add_category(row, c)
    }
  end

  def get_id(iter)
    get_id_by_name(iter[COLUMN_UNIFIED_NAME])
  end

  def get_id_by_name(name)
    @category_name[name]
  end
end

class CategoryComboBox < Gtk::ComboBox
  Instances = []

  def CategoryComboBox::update
    CategoryTreeModel.update
    Instances.each {|c|
      c.update
    }
  end

  def initialize(type, add_root = false)
    super(CategoryTreeModel.new(type, add_root))

    renderer_s = Gtk::CellRendererText.new
    pack_start(renderer_s, true)
    set_attributes(renderer_s, :text => CategoryTreeModel::COLUMN_NAME)
    Instances.push(self)
    update(0, add_root)
  end

  def update(active = 0, add_root = false)
    row = nil
    begin
      self.model.update(add_root)
      self.active = active
    rescue NoMethodError
    end
  end

  def active
    return nil unless (active_iter)
    self.active_iter[CategoryTreeModel::COLUMN_ITEM].to_i
  end

  def active=(id)
    if (id == 0)
      self.active_iter = self.model.iter_first if (self.model.iter_first)
      return
    end

    itr = nil
    each {|i|
      if (i[CategoryTreeModel::COLUMN_ITEM] && i[CategoryTreeModel::COLUMN_ITEM].to_i == id)
        itr = i
        break
      end
    }

    self.active_iter = itr if (itr)
  end

  def each(iter = self.model.iter_first, &block)
    return unless (iter)
    begin
      yield(iter)
      each(iter.nth_child(0)) {|i|
        yield(i)
      } if (iter.has_child?)
    end while (iter.next!)
  end

  def active_item
    unless (active_iter)
      if (self.model.iter_first)
        self.active_iter = self.model.iter_first
      else
        return nil
      end
    end
    self.active_iter[CategoryTreeModel::COLUMN_ITEM]
  end
end

class Gtk::Window
  # Gtk::Window#parse_geometry is buggy now?
  def parse_geometry(geometry)
    geo =  geometry.split(/([+\-])|x/)

    x = (geo[2] == "+") ? 1 : -1
    x *= geo[3].to_i

    y = (geo[4] == "+") ? 1 : -1
    y *= geo[5].to_i

    set_default_size(geo[0].to_i, geo[1].to_i)
    move(x, y)
  end
end

class Gtk::Calendar
  Day_of_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  History = []
  History_forward = []
  History_size = 32
  Mark = {}

  def initialize
    super
    @delete_forward_history = true
    @save_history = true
    signal_connect("day_selected") {|w|
      if (w.date != History[-1] && @save_history)
        History.push(w.date)
        History.delete_at(0) if (History.size > History_size)
        History_forward.clear if (@delete_forward_history)
      end
    }
    signal_connect("month-changed") {|w|
      clear_marks
      m = Mark[mark_hash_key]
      if (m)
        m.each {|d|
          mark_day(d)
        }
      end
    }
  end

  def back?
    History.size > 1
  end

  def forward?
    History_forward.size > 0
  end

  def back
    if (History.size > 1)
      @delete_forward_history = false
      History_forward.push(History.pop)
      d = History.pop
      select_month(d[1], d[0])
      select_day(d[2])
      @delete_forward_history = true
    end
  end

  def forward
    if (History_forward.size > 0)
      @delete_forward_history = false
      d = History_forward.pop
      select_month(d[1], d[0])
      select_day(d[2])
      @delete_forward_history = true
    end
  end

  def mark
    key = mark_hash_key
    Mark[key] = [] if (Mark[key].nil?)
    Mark[key].push(day) unless (Mark[key].include?(day))
    mark_day(day)
  end

  def mark_clear
    Mark.clear
    clear_marks
  end

  def day_of_month(m)
    if (month == 1)
      if (year % 4 == 0 && year % 400 == 0)
        29
      elsif (year % 4 == 0 && year % 100 == 0)
        28
      elsif (year % 4 == 0)
        29
      else
        28
      end
    elsif (month >= 0 && month < 12)
      Day_of_month[month]
    else
      raise "Invalid month"
    end
  end

  def prev_month(save_hist = true)
    if (self.month == 0)
      self.year -= 1
      self.month = 11
    else
      self.month -= 1
    end

    @save_history = save_hist
    if (self.day > day_of_month(self.month))
      self.day = day_of_month(self.month)
    else
      self.day = self.day
    end
    @save_history = true
  end

  def next_month(save_hist = true)
    if (self.month == 11)
      self.year += 1
      self.month = 0
    else
      self.month += 1
    end

    @save_history = save_hist
    if (self.day > day_of_month(self.month))
      self.day = day_of_month(self.month)
    else
      self.day = self.day
    end
    @save_history = true
  end

  def prev_day
    if (self.day == 1)
      prev_month(false)
      self.day = day_of_month(self.month)
    else
      self.day -= 1
    end
  end

  def next_day
    if (self.day == day_of_month(self.month))
      next_month(false)
      self.day = 1
    else
      self.day += 1
    end
  end

  def today
    t = Date.today
    self.month = t.month - 1
    self.year = t.year
    self.day = t.day
  end

  private

  def mark_hash_key
    year * 100 + month
  end
end

class TimeInput < Gtk::HBox
  def initialize(pad = 4)
    super()
    t = Time.new
    
    @hour = Gtk::SpinButton.new(0, 23, 1)
    @min  = Gtk::SpinButton.new(-1, 60, 1)
    @hour.xalign = 1
    @min.xalign = 1

    @hour.width_chars = 2
    @min.width_chars = 2

    @hour.max_length = 2
    @min.max_length = 2

    @hour.value = t.hour
    @min.value = t.min

    @hour.signal_connect("value-changed") {|w|
      if (w.value > 0 && w.value < 23)
        @min.set_range(-1, 60)
      end
    }

    @min.signal_connect("value-changed") {|w|
      if (w.value > 59)
        if (@hour.value < 23)
          @hour.spin(Gtk::SpinButton::STEP_FORWARD, 1)
          w.value = 0
          w.set_range(-1, 60)
        else
          w.value = 59
          w.set_range(-1, 59)
        end
      elsif(w.value < 0)
        if (@hour.value > 0)
          @hour.spin(Gtk::SpinButton::STEP_BACKWARD, 1)
          w.value = 59
          w.set_range(-1, 60)
        else
          w.value = 0
          w.set_range(0, 60)
        end
      end
    }

    self.pack_start(MyLabel.new(_("時刻")), false, false, pad)
    self.pack_start(@hour, false, false, pad)
    self.pack_start(Gtk::Label.new(":"), false, false, pad)
    self.pack_start(@min, false, false, pad)
  end

  def to_s
    sprintf("%02d:%02d", @hour.value, @min.value)
  end

  def set(*args)
    case (args.length)
    when 1
      t = args[0].split(":")
      h = t[0].to_i
      m = t[1].to_i
    when 2
      h = args[0].to_i
      m = args[1].to_i
    else
      return
    end

    @hour.value = h
    @min.value = m
  end
end

class SubtotalPanel < Gtk::Frame
  def initialize
    super

    self.set_shadow_type(Gtk::ShadowType::ETCHED_OUT)

    hbox = Gtk::HBox.new(false, 10)
    hbox.border_width = 4

    @date = MyLabel.new("")
    hbox.pack_start(@date, false, false, 0)

    [
      [:@income, _("収入:")],
      [:@expense, _("支出:")],
      [:@subtotal, _("小計:")]
    ].each {|val, title|
      label = instance_variable_set(val, Gtk::Label.new(""))
      hb = Gtk::HBox.new
      hb.pack_start(MyLabel.new(title), false, false, 0)
      hb.pack_start(label, false, false, 0)
      hbox.pack_start(hb, false, false, 0)
    }

    self.add(hbox)
  end

  def set(y, m, d, i, e)
    @date.label = "#{y}/#{m}/#{d}"
    @income.label = Commalize(i)
    @expense.label = Commalize(e)
    @subtotal.label = Commalize(i - e)
  end
end

class String
  alias to_I to_i
  def to_i
    if (COMMALIZE[1])
      self.gsub(COMMALIZE[1], '').gsub(',', '.').to_I
    else
      self.to_I
    end
  end
end

class TreeView < Gtk::TreeView
  def initialize(ts)
    super(ts)

    self.headers_visible = true
    self.rules_hint = true

    signal_connect("key-press-event") {|w, e|
      case (e.keyval)
      when Gdk::Keyval::GDK_KEY_space
        toggle_expand(w.selection.selected)
      end
    }
  end

  def toggle_expand(iter)
    return unless (iter)
    path = iter.path
    if (row_expanded?(path))
      collapse_row(path)
    else
      expand_row(path, false)
    end
  end
end

class MyProgressBar < Gtk::ProgressBar
  def initialize
    super
    h = create_pango_layout('8').pixel_size[1]
    set_size_request(120, h + 2)
    hide
  end

  def show_progress(val)
    if (val >=0 && val <= 1)
      set_fraction(val)
      set_text("#{(val*100).to_i}%")
      show_now
      while (Gtk.events_pending?)
        Gtk.main_iteration
      end
    end
  end

  def end_progress
    set_fraction(0)
    set_text('')
    hide
  end
end

class Migemo
  COMMAND = "migemo -d /usr/share/migemo/migemo-dict" 

  def Migemo.callback
    proc {
      @migemo.close if (@migemo)
    }
  end


  def initialize
    @migemo = nil
    @command = COMMAND

    open
    ObjectSpace.define_finalizer(self, Migemo.callback)
  end

  def open(cmd = COMMAND)
    @command = cmd
    begin
      @migemo = IO.popen(@command, 'r+')
    rescue
      @migemo = nil
    end
  end

  def close
    @migemo.close if (@migemo)
  end

  def reopen(cmd = @command)
    close
    open(cmd)
  end

  def get_regexp(str)
    return str unless (@migemo)
    begin
      @migemo.puts(str.encode(MIGEMO_KCODE, Encoding::UTF_8))
      if (MIGEMO_OUTPUT_UTF8)
        @migemo.gets.chomp
      else
        @migemo.gets.chomp(Encoding::UTF_8, MIGEMO_KCODE)
      end
    rescue
      reopen
      str
    end
  end
end

class Memo_entry < Gtk::Entry
  @@completion_model = Gtk::ListStore.new(String)
  @@load_history_thread = nil
  @@instances = []
  @@use_migemo = false
  @@migemo = Migemo.new
  @@loaded = false

  def initialize
    super

    width_chars = 30

    comp = Gtk::EntryCompletion.new 
    comp.set_model(@@completion_model)
    comp.set_match_func{|completion, key, iter|
      if (@key != self.text)
        @key = self.text.dup
#        puts key.kconv(MIGEMO_KCODE, Kconv::UTF8)
#        puts self.text.kconv(MIGEMO_KCODE, Kconv::UTF8)
        if (@@use_migemo)
          @key_regexp = /\A(?:#{migemo_get_regexp(@key)})/i
        else
          @key_regexp = /\A#{Regexp.escape(@key.downcase)}/
        end
      end
      iter && iter[0] && iter[0].downcase =~ @key_regexp
    }
    comp.popup_completion = true
    comp.popup_set_width = true
    comp.inline_completion = false
    comp.set_text_column(0)

=begin
      # need following codes to avoid GC.
      @compid = (@compid)? @compid + 1: 0
      instance_variable_set("@comp_instance_#{@compid}", comp)
=end
    @completion = comp
    set_completion(true) if (@@loaded)
    @@instances.push(self)
  end

  def Memo_entry.save_history(file, hist_size)
    @@load_history_thread.join if (@@load_history_thread)

    begin
      File.open(file, "w") {|f|
        @@completion_model.each {|model, path, iter|
          f.puts(iter[0]) if (iter && iter[0])
          hist_size -= 1
          break if (hist_size < 1)
        }
      }
    rescue => ever
      err_message("履歴保存時にエラーが発生しました。\n#{ever.to_s}\n履歴が正常に保存されていない可能性があります。")
    end
  end

  def Memo_entry.load_history(file, hist_size)
    @@load_history_thread = Thread.new do
      Thread.pass
      begin
        IO.foreach(file) {|l|
          l.chomp!
          @@completion_model.append[0] = l
          hist_size -= 1
          break if (hist_size < 1)
        }
      rescue
      end
      Mutex.new.synchronize {
        Memo_entry.set_completion(true)
        @@loaded = true
      }
    end
  end

  def Memo_entry.use_migemo(state, cmd)
    @@migemo.reopen(cmd) if (@@use_migemo != state && state)

    @@use_migemo = state
  end

  def Memo_entry.set_completion(state)
    @@instances.each {|i|
      i.set_completion(state)
    }
  end

  def completion_model_add_item(item = self.text)
    return if (item.length < 1)
    @@load_history_thread.join if (@@load_history_thread)

    old_path = nil
    @@completion_model.each {|model, path, iter|
      old_path = path if (iter && iter[0] && iter[0] == item)
    }
    if (old_path)
      iter = @@completion_model.get_iter(old_path)
      @@completion_model.remove(iter)
    end
    row = @@completion_model.prepend
    row[0] = item
  end

  def migemo_get_regexp(str)
    if (@@migemo)
      @@migemo.get_regexp(str)
    else
      str
    end
  end

  def set_completion(state)
    if (state)
      super(@completion)
    else
      super(nil)
    end
  end
end
