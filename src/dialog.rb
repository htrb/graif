# -*- coding: utf-8 -*-
# $Id: dialog.rb,v 1.110 2011/09/25 12:57:52 hito Exp $

class DialogWindow < Gtk::Window
  attr_reader :geometry

  def initialize(parent)
    super(Gtk::WindowType::TOPLEVEL)
    @parent = parent
    @show_all = true
    set_icon(Icon)
    begin
      @parent.add_group(self)
    rescue NameError
    end

    signal_connect('delete-event') {|w, e|
      w.hide
      w.signal_emit_stop('delete-event')
    }

    @geometry = @parent.get_gconf("/window/#{self.class.to_s.gsub('Window','').downcase}_geometry")
  end

  def show
    if (self.visible?)
      self.present
      return
    end 
    self.parse_geometry(@geometry) if (@geometry)
    if (@show_all)
      show_all
      @show_all = false
    end
    super
  end

  def hide
    return unless (self.visible?)
    save_geometry
    super()
  end

  private

  def save_geometry
    @geometry  = self.size.join('x')
    @geometry += self.position.collect{|v| sprintf('%+d', v)}.join('')

    @parent.set_gconf("/window/#{self.class.to_s.gsub('Window','').downcase}_geometry", @geometry)
  end
end

class SummaryDialog < DialogWindow
  def initialize(parent, data)
    super(parent)
    @stack = Gtk::Stack.new
#    @stack.transition_type = :slide_right
#    @stack.transition_duration = 1000
    switcher = Gtk::StackSwitcher.new
    switcher.stack = @stack

    @widgets = []
    @visible = nil

    append(AccountSummaryWindow.new(parent, self, data))
    append(CategorySummaryWindow.new(parent, self, data))
    append(AccountInOutWindow.new(parent, self, data))
    append(MonthSummaryWindow.new(parent, self, data))
    append(ItemSummaryWindow.new(parent, self, data))
    append(GraphWindow.new(parent, self, data))

    vbox = Gtk::Box.new(:vertical, 0)
    vbox.pack_start(switcher, :expand => false, :fill => false, :padding => 0)
    vbox.pack_start(@stack)
    add(vbox)

    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_W, Gdk::Keyval::KEY_w
        hide if ((e.state & Gdk::ModifierType::CONTROL_MASK).to_i != 0)
      end
    }
  end

  def append(widget)
    @widgets.push(widget)
    title = widget.title
    @stack.add(widget, title, title)
  end

  def show(y, m)
    @widgets.each {|w|
      w.year = y
      w.month = m
    }
    @stack.set_visible_child(@visible) if (@visible)
    super()
  end

  def hide
    @visible = @stack.visible_child
    super
  end

  def update(y, m)
    @widgets.each {|w|
      w.update(y, m)
    }
  end
end

class SummaryWindow < Gtk::Box
  Label_this_year  = ' 今年 '
  Label_this_month = ' 今月 '

  @@mode = MonthYearComboBox::MonthMode
  @@year = nil
  @@month = nil

  attr_reader :title
  attr_accessor :year, :month

  def initialize(parent, window, data, has_year_btn = false, has_progress = false)
    super(:vertical, 0)
    @zaif_data = data
    @vbox = self
    @title = ""
    @window = window
    @button_box = nil

    @parent = parent
    e = @parent.get_gconf("/general/#{self.class.to_s.gsub('Window','').downcase}_expand")
    @expand = if (e)
                e.split(',').collect {|p| Gtk::TreePath.new(p)}
              else
                []
              end

    @updating = false

    signal_connect('map') {|w|
      if (@@month && @@year)
        show_data(@@year, @@month)
      else
        show_today
      end
    }

    pack_end(create_btns(has_year_btn, has_progress), :expand => false, :fill => false, :padding => 0)
  end

  def year=(y)
    @@year = y
  end

  def month=(m)
    @@month = m if (m > 0 && m < 13)
  end

  def set_title(title)
    @title = title
  end

  def title=(title)
    @window.title = title
  end

  def update(y, m)
    show_data(@@year, @@month) if ((y < @@year || (y == @@year && m <= @@month)) && self.visible?)
  end

  def show(y, m)
    show_data(y, m)
  end

  def hide
    set_expand
    @window.hide
  end

  private

  def show_data(y, m)
    updating
    @cb_year.mode = @@mode if (@cb_year)
    if (@cb_year && @cb_year.year?)
      y , m = get_start_of_year(y, m)
      self.title = sprintf('%s %04d年度 (%d/%02d-%d/%02d)',
                           @title,
                           y,
                           y, m + 1,
                           (m == 0)? y: y + 1, (m == 0)? 12: m)
    else
      self.title = sprintf('%s %04d/%02d', @title, y, m)
    end
  end

  def show_next
    return if (@updating)
    updating
    set_expand
    if (@cb_year && @cb_year.year?)
      @@year += 1
    elsif (@@month == 12)
      @@month = 1
      @@year += 1
    else
      @@month += 1
    end
    show_data(@@year, @@month)
  end

  def show_prev
    return if (@updating)
    updating
    set_expand
    if (@cb_year && @cb_year.year?)
      @@year -= 1
    elsif (@@month == 1)
      @@month = 12
      @@year -= 1
    else
      @@month -= 1
    end
    show_data(@@year, @@month)
  end

  def show_today
    return if (@updating)
    updating
    set_expand
    d = Date.today
    show_data(d.year, d.month)
  end

  def updating(state = true)
    @updating = state
    @window.sensitive = ! state
  end

  def updating_done
    updating(false)
  end

  def create_btns(has_year_btn, has_progress)
    hbox = Gtk::Box.new(:horizontal, 0)

    [
     [Gtk::Stock::GO_BACK,    :show_prev,      :pack_start, :@prev_btn],
     [Label_this_month,       :show_today,     :pack_start, :@today_btn],
     [Gtk::Stock::GO_FORWARD, :show_next,      :pack_start, :@next_btn],
     [Gtk::Stock::CLOSE,      :hide,           :pack_end,   :@close_btn],
    ].each {|(stock, func, pack, val)|
      btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => stock)
      instance_variable_set(val, btn) if (val)
      btn.signal_connect('clicked') {|w|
        send(func)
      }
      hbox.send(pack, btn, :expand => false, :fill => false, :padding => 0)
    }

    if (has_year_btn)
      hb = Gtk::Box.new(:horizontal, 0)
      @cb_year = MonthYearComboBox.new
      hb.pack_end(@cb_year, :expand => false, :fill => false, :padding => 0)
      @cb_year.signal_connect("changed") {|w|
        @@mode = @cb_year.mode
#        set_expand
        show_data(@@year, @@month)
        if (@cb_year.year?)
          @today_btn.label = Label_this_year
        else
          @today_btn.label = Label_this_month
        end
      }
      hbox.pack_start(hb, :expand => false, :fill => false, :padding => 10)
    end

    if (has_progress)
      @progress = MyProgressBar.new
      hbox.pack_end(@progress, :expand => true, :fill => true, :padding => 10)
    end

    @button_box = hbox
    hbox
  end

  def expand
    return unless (@tree_view)
    @expand.each {|path|
      @tree_view.expand_to_path(path)
    }
  end

  def set_expand
    return unless (@tree_view)
    @expand.clear
    @tree_view.model.each{|model, path, iter|
      @expand.push(path) if (@tree_view.row_expanded?(path))
    }
  end

  def get_start_of_year(y, m)
    @parent.get_start_of_year(y, m)
  end
end

def _(s)
  s
end

class AccountSummaryWindow < SummaryWindow

  COLUMN_DATA = [
                 [_('口座'),   :COLUMN_ACCOUNT,   String],
                 [_('小計'),   :COLUMN_SUMMATION, Numeric],
                 [_('収入'),   :COLUMN_INCOME,    Numeric],
                 [_('支出'),   :COLUMN_EXPENSE,   Numeric],
                 [_('移動'),   :COLUMN_MOVE,      Numeric],
                 [_('不明額'), :COLUMN_ADJUST,    Numeric],
                 [_('繰越'),   :COLUMN_BALANCE,   Numeric],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }


  def initialize(parent, win, data)
    super(parent, win, data, true, true)
    @tree_view = create_table(@vbox)
    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Left
        show_prev
        w.signal_emit_stop('key-press-event')
      when Gdk::Keyval::KEY_Right
        show_next
        w.signal_emit_stop('key-press-event')
      end
    }
    set_title(_('口座集計'))
  end

  def create_table(box)
    tree_view = TreeView.new(Gtk::TreeStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}))
    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      renderer = Gtk::CellRendererText.new

      column = nil
      if (type == Numeric)
        renderer.xalign = 1.0
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    tree_view.set_size_request(480, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  private

  def show_data(y, m)
    super
    @@year = y
    @@month = m

    if (@cb_year.year?)
      method = :get_account_summary_year
      y, m = get_start_of_year(y, m)
    else
      method = :get_account_summary_month
    end
    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil
    model.clear
    root = nil
    @zaif_data.send(method, y, m) {
      |account, sum, income, expenses, move, adjustment, balance, progress|

      if (progress < 1)
        @progress.show_progress(progress) if (@parent.progress_bar?)
        next 
      end

      row = model.append(root)

      if (account)
        row[COLUMN_ACCOUNT] = account.to_s
      else
        root = row
        row[COLUMN_ACCOUNT] = _('小計')
      end
      row[COLUMN_SUMMATION] = sum
      row[COLUMN_INCOME]    = income
      row[COLUMN_EXPENSE]   = expenses
      row[COLUMN_MOVE]      = move
      row[COLUMN_ADJUST]    = adjustment
      row[COLUMN_BALANCE]   = balance
    }
    @tree_view.model = model
    expand
    @progress.end_progress
    updating_done
  end
end

class CategorySummaryWindow < SummaryWindow
  COLUMN_DATA = [
                 [_('分類'),     :COLUMN_CATEGORY,       String],
                 [_('予算'),     :COLUMN_BUDGET,         Numeric],
                 [_('収入'),     :COLUMN_INCOME,         Numeric],
                 [_('支出'),     :COLUMN_EXPENSE,        Numeric],
                 [_('予算残額'), :COLUMN_BUDGET_BALANCE, Numeric],
                 [_('収支'),     :COLUMN_TOTAL_BALANCE,  Numeric],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  def initialize(parent, win, data)
    super(parent, win, data, true, true)
    @tree_view = create_table(@vbox)
    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Left
        show_prev
        w.signal_emit_stop('key-press-event')
      when Gdk::Keyval::KEY_Right
        show_next
        w.signal_emit_stop('key-press-event')
      end
    }
    set_title(_('分類集計'))
  end

  def create_table(box)
    tree_view = TreeView.new(Gtk::TreeStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}))
    renderer_s = Gtk::CellRendererText.new
    renderer_n = Gtk::CellRendererText.new
    renderer_n.xalign = 1.0
    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      renderer = Gtk::CellRendererText.new

      column = nil
      if (type == Numeric)
        renderer.xalign = 1.0
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    tree_view.set_size_request(320, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  private

  def append_tree_item(model, parent, category, summary, budget)
    row = model.append(parent)
    esum = summary[category.to_i][0].to_i
    isum = summary[category.to_i][1].to_i
    bsum = budget[category.to_i]

    bsum = bsum ? bsum.budget : 0

    row[COLUMN_CATEGORY] = category.to_s
    category.each_child {|c|
      es, is, b = append_tree_item(model, row, c, summary, budget)
      if (budget[category.to_i].nil? || budget[category.to_i].sumup)
        esum += es
        isum += is
        bsum += b
      end
    }

    if (category.expense)
      row[COLUMN_BUDGET]  = bsum
      row[COLUMN_EXPENSE] = esum
      row[COLUMN_BUDGET_BALANCE] = (category.income) ? (bsum - esum + isum) : (bsum - esum)
    else
      row[COLUMN_BUDGET]  = 0.0
      row[COLUMN_EXPENSE] = 0.0
      row[COLUMN_BUDGET_BALANCE] = 0.0
      row[COLUMN_TOTAL_BALANCE] = 0.0
    end

    row[COLUMN_TOTAL_BALANCE] = 
      if (category.expense || category.income)
        isum - esum
      else
        0.0
      end
    row[COLUMN_INCOME] = (category.income || isum != 0) ? isum : 0.0

    [esum, isum, bsum]
  end

  def show_data(y, m)
    super
    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil
    model.clear

    @@month = m
    @@year = y
    if (@cb_year.year?)
      y, m = get_start_of_year(y, m)
      summary = @zaif_data.get_category_summary_year(y, m) {|progress|
        @progress.show_progress(progress) if (@parent.progress_bar?)
      }
      budget = @zaif_data.get_year_budget(y, m)
    else
      summary = @zaif_data.get_category_summary(y, m)
      budget = @zaif_data.get_month_budget(y, m)
    end
    esum, isum, isum2 = summary.inject([0, 0, 0]) {|s, d|
      v = d[1]
      c = @zaif_data.get_category_by_id(d[0], false, false, false)
      s[0] += v[0]
      s[1] += v[1]
      s[2] += ((c.expense && c.income)?  v[1]: 0)
      s
    }

    bsum = budget.inject(0) {|s, v|
      s + v[1].budget
    }

    row = model.append(nil)
    row[COLUMN_CATEGORY] = _('小計')
    row[COLUMN_BUDGET]   = bsum
    row[COLUMN_INCOME]   = isum
    row[COLUMN_EXPENSE]  = esum
    row[COLUMN_BUDGET_BALANCE]  = bsum - esum + isum2
    row[COLUMN_TOTAL_BALANCE]  = isum - esum

    @zaif_data.get_root_category.each_child {|c|
      append_tree_item(model, row, c, summary, budget)
    }
    @progress.end_progress
    @tree_view.model = model
    expand

    updating_done
  end
end

class BudgetDialog < DialogWindow
  def initialize(parent, data)
    super(parent)
    @budget = BudgetWindow.new(parent, self, data)
    add(@budget)

    self.modal = true
    self.transient_for = parent
  end

  def show(y, m)
    @budget.show(y, m)
    super()
  end

  def hide
    @budget.save
    super
  end
end

class BudgetWindow < SummaryWindow
  COLUMN_DATA = [
                 [_('分類'),     :COLUMN_CATEGORY,     String,    false],
                 [_('先月予算'), :COLUMN_PREV_BUDGET,  Numeric,   false],
                 [_('先月収入'), :COLUMN_PREV_INCOME,  Numeric,   false],
                 [_('先月支出'), :COLUMN_PREV_EXPENSE, Numeric,   false],
                 [_('先月収支'), :COLUMN_PREV_BALANCE, Numeric,   false],
                 [_('予算'),     :COLUMN_BUDGET,       Numeric,   true],
                 [_('合算'),     :COLUMN_SUM,          TrueClass, true],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_ID = COLUMN_DATA.size

  def initialize(parent, win, data)
    super(parent, win, data, false, false)

    @tree_view = create_table(@vbox)
    @modified = false
    set_title(_('予算入力'))
  end

  def set_sum
    sum = 0
    @tree_view.model.each {|model, path, iter|
      sum += iter[COLUMN_BUDGET].to_i if (path.to_s != '0')
    }
    @tree_view.model.iter_first[COLUMN_BUDGET] = sum
  end

  def set_budget(itr, month)
    return unless (itr)
    begin
      month.set_budget(itr[COLUMN_ID].to_i, itr[COLUMN_BUDGET], itr[COLUMN_SUM])
      set_budget(itr.nth_child(0), month) if (itr.has_child?)
    end while (itr.next!)
  end

  def create_table(box)
    tree_view = TreeView.new(Gtk::TreeStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Zaif_category)))
    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      editable = data[COLUMN_DATA_EDIT]
      renderer = Gtk::CellRendererText.new

      if (type == String)
        r = Gtk::CellRendererText.new
        column = Gtk::TreeViewColumn.new(title, r, :text => id)
      elsif (type == TrueClass)
        r = Gtk::CellRendererToggle.new
        r.activatable = true
        r.signal_connect('toggled') {|cell, path|
          if (path != '0')
            iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
            iter[id] = ! iter[id]
            @modified = true
          end
        }
        column = Gtk::TreeViewColumn.new(title, r, :active => id)
      else
        r = Gtk::CellRendererText.new
        r.xalign = 1.0
        if (editable)
          r.editable = true
          r.signal_connect('edited') {|cell, path, str|
            iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
            if (path != '0' && iter[COLUMN_ID].expense)
              val = str.to_i
              if (val != iter[id])
                iter[id] = val
                set_sum
                @modified = true
              end
            end
          }
        end
        column = TreeViewColumnNumeric.new(title, r, id)
      end
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    column = Gtk::TreeViewColumn.new('', Gtk::CellRendererText.new)
    column.visible = false
    tree_view.append_column(column)

    tree_view.set_size_request(420, 300)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  def save
    return unless (@modified)
    month = @zaif_data.get_month_data(@@year, @@month)
    set_budget(@tree_view.model.iter_first.first_child, month)
    @modified = false
  end

  private

  def append_tree_item(model, parent, category, summary, budget, p_budget)
    row = model.append(parent)
    b = budget[category.to_i]
    p_b = p_budget[category.to_i]
    es = summary[category.to_i][0].to_i
    is = summary[category.to_i][1].to_i
    s = is - es
    if (p_b)
      s += p_b.budget
    end

    row[COLUMN_CATEGORY] = category.to_s

    if (category.expense)
      row[COLUMN_PREV_BUDGET] = p_b ? p_b.budget : 0
      row[COLUMN_PREV_EXPENSE] = es
      row[COLUMN_PREV_BALANCE] = s
      row[COLUMN_BUDGET] = b ? b.budget : 0
      row[COLUMN_PREV_INCOME] = (category.income) ? is : 0.0
    else
      row[COLUMN_PREV_BUDGET] = 0.0
      row[COLUMN_PREV_EXPENSE] = 0.0
      row[COLUMN_PREV_BALANCE] = 0.0
      row[COLUMN_BUDGET] = 0.0
      row[COLUMN_SUM] = 0.0
      row[COLUMN_PREV_INCOME] = 0.0
    end

    row[COLUMN_ID] = category
    row[COLUMN_SUM] = b ? (b.sumup ? true : false) : true

    category.each_child {|c|
      append_tree_item(model, row, c, summary, budget, p_budget)
    }
  end

  def show_data(y, m)
    super
    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil
    model.clear

    month = @zaif_data.get_month_data(y, m)
    p_month = month.get_prev

    summary = p_month.get_category_summary(@zaif_data.get_root_category)
    budget = month.budget

    p_budget = p_month.budget

    isum = 0
    esum = 0
    isum2 = 0
    summary.each {|k, v|
      c = @zaif_data.get_category_by_id(k, false, false, false)
      esum += v[0]
      isum += v[1]
      isum2 += v[1] if (c.expense && c.income)
    }

    bsum = budget.sum
    p_bsum = p_budget.sum


    row = model.append(nil)
    row[COLUMN_CATEGORY] = _('合計')
    row[COLUMN_PREV_INCOME] = isum2
    row[COLUMN_PREV_BUDGET] = p_bsum
    row[COLUMN_PREV_EXPENSE] = esum
    row[COLUMN_PREV_BALANCE] = p_bsum - esum + isum2
    row[COLUMN_BUDGET] = bsum

    @zaif_data.get_root_category.each_child {|c|
      append_tree_item(model, row, c, summary, budget, p_budget)
    }
    @tree_view.model = model
    expand
    @@year = y
    @@month = m
    updating_done
  end

  def show_prev
    save if (@modified)
    super
  end

  def show_today
    save if (@modified)
    super
  end

  def show_next
    save if (@modified)
    super
  end
end

class MonthSummaryWindow < SummaryWindow
  COLUMN_DATA = [
                 ['*',            :COLUMN_TYPE,     String],
                 [_('日'),        :COLUMN_DAY,      Numeric],
                 [_('時刻'),      :COLUMN_TIME,     String],
                 
                 [_('分類'),      :COLUMN_CATEGORY, String],
                 [_('収入'),      :COLUMN_INCOME,   Numeric],
                 [_('支出'),      :COLUMN_EXPENSE,  Numeric],
                 
                 [_('移動/調整'), :COLUMN_MOVE,     Numeric],
                 [_('口座'),      :COLUMN_ACCOUNT,  String],
                 [_('メモ'),      :COLUMN_MEMO,     String],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_INDEX = COLUMN_DATA.size
  COLUMN_ITEM  = COLUMN_INDEX + 1

  def initialize(parent, win, data)
    super(parent, win, data, false, true)

    @tree_view = create_table(@vbox)

    @tree_view.signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Return
        select_item
      end
    }

    @tree_view.signal_connect('button-press-event') {|w, e|
      if (e.kind_of?(Gdk::EventButton))
        if (e.button == 1 && e.event_type == Gdk::EventType::BUTTON2_PRESS)
          select_item
        end
      end
    }
    set_title(_('月データ一覧'))
  end

  def update(y, m)
    show_data(@@year, @@month) if (y == @@year && m == @@month && self.visible?)
  end

  def select_item
    itr = @tree_view.selection.selected
    if (itr)
      @parent.goto(@@year, @@month, itr[COLUMN_DAY], itr[COLUMN_ITEM])
      @parent.present
    end
  end

  def create_table(box)
    ls = Gtk::ListStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Integer).push(Zaif_category))
    tree_view = TreeView.new(ls)

    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      editable = data[COLUMN_DATA_EDIT]
      renderer = Gtk::CellRendererText.new

      column = nil
      if (type == Numeric)
        renderer.xalign = 1.0
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
        renderer.xalign = 0.5 if (id == COLUMN_TYPE)
      end
      column.clickable = true
      column.resizable = true
      column.sort_order = Gtk::SortType::DESCENDING
      column.sort_column_id = id
      tree_view.append_column(column)
=begin
      tree_view.model.set_sort_func(id){|itr1, itr2|
        a = itr1[id]
        b = itr2[id]

        if (a == b)
          itr1[COLUMN_INDEX] <=> itr2[COLUMN_INDEX]
        else
          if (! a)
            -1
          elsif (! b)
            1
          else
            a <=> b
          end
        end
      }
=end
    }

    [COLUMN_INDEX, COLUMN_ITEM].each {|i|
      column = Gtk::TreeViewColumn.new('', Gtk::CellRendererText.new)
      column.visible = false
      tree_view.append_column(column)
    }

    tree_view.set_size_request(600, 400)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  private

  def show_data(y, m)
    super
    vadj = @tree_view.vadjustment.value
    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil
    model.clear
    month = @zaif_data.get_month_data(y, m)
    size = month.size + 1.0
    month.each_with_index {|data, index|
      @progress.show_progress(index / size) if (index % 10 == 0 && @parent.progress_bar?) #/
      d, i = data
      row = model.append
      row[COLUMN_DAY] = d.date
      row[COLUMN_TIME] = i.time
      row[COLUMN_MEMO] = i.memo
      row[COLUMN_INDEX] = index
      row[COLUMN_ITEM] = i
      case (i.type)
      when Zaif_item::TYPE_EXPENSE
        row[COLUMN_TYPE] = '-'
        row[COLUMN_CATEGORY] =
          @zaif_data.get_category_by_id(i.category, true, false).to_s
        row[COLUMN_EXPENSE] = i.amount
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
      when Zaif_item::TYPE_INCOME
        row[COLUMN_TYPE] = '+'
        row[COLUMN_CATEGORY] =
          @zaif_data.get_category_by_id(i.category, false, true).to_s
        row[COLUMN_INCOME] = i.amount
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
      when Zaif_item::TYPE_MOVE
        row[COLUMN_TYPE] = '='
        row[COLUMN_MOVE] = i.amount
        if (i.fee_sign < 0)
          row[COLUMN_EXPENSE] = i.fee
        else
          row[COLUMN_INCOME] = i.fee
        end
        row[COLUMN_CATEGORY] =
          @zaif_data.get_account_by_id(i.account).to_s
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account_to).to_s
      when Zaif_item::TYPE_ADJUST
        row[COLUMN_TYPE] = '*'
        row[COLUMN_MOVE] = i.amount
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
      end
      row[COLUMN_TYPE] = "(#{row[COLUMN_TYPE]})" if (i.exceptional)
    }
    @@year = y
    @@month = m
    @progress.show_progress(1) if (@parent.progress_bar?)
#   ^ this code is needed to wait for tree_view will be shown.
    @progress.end_progress
    @tree_view.model = model
    @tree_view.vadjustment.set_value(vadj)
    updating_done
  end
end

class AccountInOutWindow < SummaryWindow
  COLUMN_DATA = [
                 [_('年'),   :COLUMN_YEAR,     Numeric],
                 [_('月'),   :COLUMN_MONTH,    Numeric],
                 [_('日'),   :COLUMN_DAY,      Numeric],
                 [_('時刻'), :COLUMN_TIME,     String],
                 [_('分類'), :COLUMN_CATEGORY, String],
                 [_('入金'), :COLUMN_INCOME,   Numeric],
                 [_('出金'), :COLUMN_EXPENSE,  Numeric],
                 [_('残高'), :COLUMN_REST,     Numeric],
                 [_('メモ'), :COLUMN_MEMO,     String],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_INDEX = COLUMN_DATA.size
  COLUMN_ITEM  = COLUMN_INDEX + 1

  def initialize(parent, win, data)
    super(parent, win, data, true, true)

    @account = AccountComboBox.new
    @vbox.pack_start(@account, :expand => false, :fill => false, :padding => 0)

    @tree_view = create_table(@vbox)

    @tree_view.signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Return
        select_item
      end
    }

    @tree_view.signal_connect('button-press-event') {|w, e|
      if (e.kind_of?(Gdk::EventButton))
        if (e.button == 1 && e.event_type == Gdk::EventType::BUTTON2_PRESS)
          select_item
        end
      end
    }

    @account.signal_connect("changed"){|w|
      show_data(@@year, @@month)
    }

    @summary_panel = MyLabel.new("")
    frame = Gtk::Frame.new
    @summary_panel.set_alignment(0, 0.5)
    frame.add(@summary_panel)
    @vbox.pack_start(frame, :expand => false, :fill => false, :padding => 0)

    set_title(_('口座出入金一覧'))
  end

  def update(y, m)
    show_data(@@year, @@month) if (self.visible? && (y < @@year || (y == @@year && m <= @@month)))
  end

  def select_item
    itr = @tree_view.selection.selected
    if (itr)
      @parent.goto(itr[COLUMN_YEAR], itr[COLUMN_MONTH], itr[COLUMN_DAY], itr[COLUMN_ITEM])
      @parent.present
    end
  end

  def create_table(box)
    ls = Gtk::ListStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Integer).push(Zaif_category))

    tree_view = TreeView.new(ls)

    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      editable = data[COLUMN_DATA_EDIT]
      renderer = Gtk::CellRendererText.new

      column = nil
      if (type == Numeric)
        renderer.xalign = 1.0
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end
      column.resizable = true
      column.visible = false if (id == COLUMN_YEAR)
      tree_view.append_column(column)
    }

    [COLUMN_INDEX, COLUMN_ITEM].each {|i|
      column = Gtk::TreeViewColumn.new('', Gtk::CellRendererText.new)
      column.visible = false
      tree_view.append_column(column)
    }

    tree_view.set_size_request(600, 400)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window)

    tree_view
  end

  private

  def show_data(y, m)
    super
    @summary_panel.label = ""
    account = @account.active
#    vadj = @tree_view.vadjustment.value
    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil
    model.clear

    @@year = y
    @@month = m

    if (@cb_year.year?)
      y, m = get_start_of_year(y, m)
      m += 1
      n = 12
    else
      n = 1
    end

    @tree_view.get_column(COLUMN_MONTH).visible = @cb_year.year?

    income = 0
    expense = 0
    move = 0
    month = @zaif_data.get_month_data(y, m)
    n.times {|j|
      size = month.size + 1.0

      date = Date.new(month.year, month.month, 1) - 1
      rest = @zaif_data.get_account_summation(account, date.year, date.month, date.day, "23:59")

      month.each_with_index {|data, index|
        if (index % 10 == 0 && @parent.progress_bar?)
          progress = if (n > 1) then (j + 1) / 12.0 else index / size end #/
          @progress.show_progress(progress) 
        end

        d, i = data
        next if (i.account.to_i != account && i.account_to.to_i != account)

        row = model.append
        row[COLUMN_YEAR] = month.year
        row[COLUMN_MONTH] = month.month
        row[COLUMN_DAY] = d.date
        row[COLUMN_TIME] = i.time
        row[COLUMN_MEMO] = i.memo
        row[COLUMN_INDEX] = index
        row[COLUMN_ITEM] = i

        case (i.type)
        when Zaif_item::TYPE_EXPENSE
          row[COLUMN_CATEGORY] =
            @zaif_data.get_category_by_id(i.category, true, false).to_s
          row[COLUMN_EXPENSE] = i.amount
          rest -= i.amount
          row[COLUMN_REST] = rest
          expense += i.amount
        when Zaif_item::TYPE_INCOME
          row[COLUMN_CATEGORY] =
            @zaif_data.get_category_by_id(i.category, false, true).to_s
          row[COLUMN_INCOME] = i.amount
          rest += i.amount
          row[COLUMN_REST] = rest
          income += i.amount
        when Zaif_item::TYPE_MOVE
          amount = i.amount
          fee = 0
          if (i.account.to_i == account)
            if (i.fee_sign < 0)
              fee = -i.fee
            end
            row[COLUMN_EXPENSE] = amount
            row[COLUMN_CATEGORY] = @zaif_data.get_account_by_id(i.account_to).to_s
            rest -= amount
            move -= amount
          else
            unless (i.fee_sign < 0)
              fee = i.fee
            end
            row[COLUMN_INCOME] = amount
            row[COLUMN_CATEGORY] = @zaif_data.get_account_by_id(i.account).to_s
            rest += amount
            move += amount
          end
          row[COLUMN_REST] = rest

          if (fee != 0)
            rest += fee
            row = model.append
            row[COLUMN_YEAR] = month.year
            row[COLUMN_MONTH] = month.month
            row[COLUMN_DAY] = d.date
            row[COLUMN_TIME] = i.time
            row[COLUMN_MEMO] = i.memo
            row[COLUMN_CATEGORY] = "手数料"
            row[COLUMN_REST] = rest
            row[COLUMN_INDEX] = index
            row[COLUMN_ITEM] = i
            if (rest < 0)
              row[COLUMN_EXPENSE] = -fee
              expense -= fee
            else
              row[COLUMN_INCOME] = fee
              income += fee
            end
          end

        when Zaif_item::TYPE_ADJUST
          row[COLUMN_CATEGORY] = "調整"
          row[COLUMN_REST] = i.amount
        end
      }
      month = month.get_next
    }
    @progress.show_progress(1) if (@parent.progress_bar?)
#   ^ this code is needed to wait for tree_view will be shown.
    @progress.end_progress
#    @tree_view.vadjustment.set_value(vadj)
    @tree_view.model = model

    @summary_panel.label = "収入 : #{Commalize(income)}   支出 : #{Commalize(expense)}   移動 : #{Commalize(move)}   収支 : #{Commalize(income - expense + move)}"

    updating_done
  end
end

class ItemSummaryWindow < SummaryWindow
  COLUMN_DATA = [
                 [_('年'),   :COLUMN_YEAR,     Numeric],
                 [_('月'),   :COLUMN_MONTH,    Numeric],
                 [_('日'),   :COLUMN_DAY,      Numeric],
                 [_('時刻'), :COLUMN_TIME,     String],
                 [_('分類'), :COLUMN_CATEGORY, String],
                 [_('入金'), :COLUMN_INCOME,   Numeric],
                 [_('出金'), :COLUMN_EXPENSE,  Numeric],
                 [_('口座'), :COLUMN_ACCOUNT,  String],
                 [_('メモ'), :COLUMN_MEMO,     String],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_ITEM = COLUMN_DATA.size

  def initialize(parent, win, data)
    super(parent, win, data, true, true)

    @tree_view = create_table(@vbox)

    @tree_view.signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Return
        select_item
      end
    }

    @tree_view.signal_connect('button-press-event') {|w, e|
      if (e.kind_of?(Gdk::EventButton))
        if (e.button == 1 && e.event_type == Gdk::EventType::BUTTON2_PRESS)
          select_item
        end
      end
    }

    @search_item = SearchWidget.new
    @summary_panel = MyLabel.new("")
    frame = Gtk::Frame.new
    @summary_panel.set_alignment(0, 0.5)
    frame.add(@summary_panel)
    @vbox.pack_start(frame, :expand => false, :fill => false, :padding => 0)

#    hbox = Gtk::Box.new(:horizontal, 0)

#    hbox.pack_start(@search_item.widget, :expand => true, :fill => true, :padding => 10)

    @search_btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => Gtk::Stock::FIND)
    @search_btn.set_margin_start(PAD)
    @search_btn.set_margin_end(PAD)
    @search_btn.set_margin_top(PAD)
    @search_btn.set_margin_bottom(PAD)
    @search_btn.signal_connect('clicked') {|w, e|
      show_data(@@year, @@month)
    }

    @search_item.widget.attach(@search_btn, 2, 0, 1, 3)
#    hbox.pack_start(@search_btn, :expand => false, :fill => false, :padding => 10)

    @vbox.pack_start(@search_item.widget, :expand => false, :fill => false, :padding => 10)

    set_title(_('項目一覧'))
  end

  def create_table(box)
    ls = Gtk::ListStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Zaif_category))

    tree_view = TreeView.new(ls)
    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      editable = data[COLUMN_DATA_EDIT]
      renderer = Gtk::CellRendererText.new

      column = nil
      if (type == Numeric)
        renderer.xalign = 1.0
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end
      column.resizable = true
      column.visible = false if (id == COLUMN_YEAR)
      tree_view.append_column(column)
    }

    [COLUMN_ITEM].each {|i|
      column = Gtk::TreeViewColumn.new('', Gtk::CellRendererText.new)
      column.visible = false
      tree_view.append_column(column)
    }

    tree_view.set_size_request(600, 400)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_size_request(600, 400)
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  def update(y, m)
    @search_item.update
  end

  def show(y, m)
    @@year = y
    @@month = m
    show_all
    @progress.end_progress
  end

  private

  def select_item
    itr = @tree_view.selection.selected
    if (itr)
      @parent.goto(itr[COLUMN_YEAR], itr[COLUMN_MONTH], itr[COLUMN_DAY], itr[COLUMN_ITEM])
      @parent.present
    end
  end

  def add_item(model, y, m, d, i)
    return 0 if (i.type ==  Zaif_item::TYPE_MOVE ||
                 i.type ==  Zaif_item::TYPE_ADJUST)

    row = model.append
    row[COLUMN_YEAR] = y
    row[COLUMN_MONTH] = m
    row[COLUMN_DAY] = d.date
    row[COLUMN_TIME] = i.time
    row[COLUMN_MEMO] = i.memo
    row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
    row[COLUMN_ITEM] = i

    case (i.type)
    when Zaif_item::TYPE_EXPENSE
      row[COLUMN_CATEGORY] =
        @zaif_data.get_category_by_id(i.category, true, false).to_s
      row[COLUMN_EXPENSE] = i.amount
    when Zaif_item::TYPE_INCOME
      row[COLUMN_CATEGORY] =
        @zaif_data.get_category_by_id(i.category, false, true).to_s
      row[COLUMN_INCOME] = i.amount
    when Zaif_item::TYPE_MOVE
    when Zaif_item::TYPE_ADJUST
    end
  end

  def show_data(y, m)
    @progress.end_progress
    super
    @summary_panel.label = ""
    @tree_view.model.clear

    w = @search_item.word
    t = @search_item.type

    if (t == :@memo && w.length == 0)
      updating_done
      return
    end

    @@year = y

    model = @tree_view.model
    return unless (model)
    @tree_view.model = nil

    if (@cb_year.year?)
      y, m = get_start_of_year(y, m)
      m += 1
      n = 12
    else
      n = 1
    end

    @tree_view.get_column(COLUMN_MONTH).visible = @cb_year.year?

    month = @zaif_data.get_month_data(y, m)

    expense = 0
    income = 0

    n.times {|j|
      month.find_init

      loop {
        d, i = month.find_next(w, t)
        if (d && i)
          add_item(model, month.year, month.month, d, i)
          case (i.type)
          when Zaif_item::TYPE_EXPENSE
            expense += i.amount
          when Zaif_item::TYPE_INCOME
            income += i.amount
          end
        else
          break
        end
      }
      month = month.get_next
      @progress.show_progress(j / 12.0) if (@parent.progress_bar?)
    }
    @progress.show_progress(1) if (@parent.progress_bar?)
#   ^ this code is needed to wait for tree_view will be shown.
    @progress.end_progress
#    @tree_view.vadjustment.set_value(vadj)
    @summary_panel.label = "収入 : #{Commalize(income)}   支出 : #{Commalize(expense)}   収支 : #{Commalize(income - expense)}"
    @tree_view.model = model
    updating_done
  end
end
