# -*- coding: utf-8 -*-
# $Id: setup_window.rb,v 1.49 2010-02-25 06:59:16 hito Exp $

class SetupWindow < DialogWindow
  attr_reader :modified, :path_modified

  [
   :COLUMN_ACCOUNT,
   :COLUMN_CREDIT,
   :COLUMN_ACCOUNT_ID,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  [
   :COLUMN_CATEGORY,
   :COLUMN_EXPENSE,
   :COLUMN_INCOME,
   :COLUMN_CATEGORY_ID,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  def initialize(parent, data)
    super(parent)
    @zaif_data = data
    self.modal = true
    self.transient_for = parent

    vbox = Gtk::Box.new(:vertical, 0)

    @tab = create_tab
    @tab_page = 0
    vbox.pack_start(@tab, :expand => true, :fill => true, :padding => 0)
    vbox.pack_end(create_root_btns, :expand => false, :fill => false, :padding => 4)

    self.title = "#{APP_NAME} setup"
    add(vbox)

    signal_connect('delete-event') {|w, e|
      w.cancel
      w.signal_emit_stop('delete-event')
    }

    @prev_modified = false
    @modified = false
    @path_modified = false
  end

  def create_tab
    tab = Gtk::Notebook.new
    [
      [_("全般"), create_option_page],
      [_("口座"), create_account_page],
      [_("分類"), create_category_page],
    ].each {|(title, page)|
      tab.append_page(page, MyLabel.new(title))
    }

    tab
  end

  def category_set_item(itr, parent)
    begin
      c = Zaif_category.new(itr[COLUMN_CATEGORY_ID].to_i + Zaif_config::ID_OFFSET,
                            itr[COLUMN_CATEGORY],
                            parent,
                            itr[COLUMN_EXPENSE],
                            itr[COLUMN_INCOME])
      parent.add_child(c)
      category_set_item(itr.model.nth_child(itr, 0), c) if (itr.has_child?)
    end while (itr.next!)
  end

  def ok
    if (@modified)
      @zaif_data.clear_account
      @zaif_data.clear_category

      category_set_item(@category_tree.model.iter_first, @zaif_data.get_root_category) if (@category_tree.model.iter_first)

      @account_tree.model.each {|m, p, itr|
        @zaif_data.add_account(itr[2].to_i + Zaif_config::ID_OFFSET, itr[0], itr[1])
      }
      @prev_modified = true
    end

    current_path = Dir.pwd

    if (@path_modified)
      begin
        @parent.path = @path.text
      rescue =>ever
        @parent.err_message(ever.to_s, self)
        @path_modified = false
      end
    end

    if (current_path != Dir.pwd &&
        @parent.conf_message(_("データディレクトリが変更されました。\n設定、データを読み直しますか？"), self))
      Dir.chdir(current_path) {
        @parent.save
      }
      @zaif_data.clear_account
      @zaif_data.clear_category
      @zaif_data.clear_data
      @zaif_data.read_config
      @parent.update
    end

    @parent.set_gconf('/general/conf_save', @conf_save.active?)
    @parent.set_gconf('/general/conf_quit', @conf_quit.active?)
    @parent.set_gconf('/general/calc_subtotal_every_time', @calc_subtotal_every_time.active?)
    @parent.set_gconf('/general/show_delete_button', @show_delete_button.active?)
    @parent.delete_btn_state(@show_delete_button.active?)
    @parent.set_gconf('/general/show_clear_button', @show_clear_button.active?)
    @parent.clear_btn_state(@show_clear_button.active?)
    @parent.set_gconf('/general/start_of_year', @start_of_year.value.to_i)
    @parent.set_gconf('/general/consumption_tax', @consumption_tax.value.to_i)
    @parent.set_gconf('/general/show_progress_bar', @show_progress_bar.active?)
    @parent.set_gconf('/general/graph_include_income', @graph_include_income.active?)
    @parent.set_gconf('/general/graph_include_expense', @graph_include_expense.active?)
    @parent.history_size = [@history_size.value, 1].max
    @parent.migemo_cmd = @migemo_cmd.text
    @parent.use_migemo = @use_migemo.active?

    @parent.hide_zero = @hide_zero.active?

    n = nil
    sep = nil
    @rb_commalize_n.group.each {|w|
      n = w.label.to_i if (w.active?)
    }
    @rb_commalize_sep.group.each {|w|
      sep = w.label if (w.active?)
    }

    if (n && sep)
      CommalizeSetiing(n, sep)
    end
    @parent.set_gconf('/general/commalize_num', COMMALIZE[0])
    @parent.set_gconf('/general/commalize_separator', COMMALIZE[1])

    hide
  end

  def cancel
    unless (@prev_modified)
      @path_modified = false
      @modified = false
    end
    hide
  end

  def show
    super
    @tab.page = @tab_page
    modified = @modified
    category_show_data
    account_show_data
    @path.text = Dir.pwd
    @path_modified = false
    @modified = modified

    if (COMMALIZE[0] == @rb_commalize_n.label.to_i)
      @rb_commalize_n.active = true
    else
      @rb_commalize_n.group[0].active = true
    end

    if (COMMALIZE[1] == @rb_commalize_sep.label)
      @rb_commalize_sep.active = true
    else
      @rb_commalize_sep.group[0].active = true
    end

    @start_of_year.value = @parent.start_of_year
    @consumption_tax.value = @parent.consumption_tax
    @show_delete_button.active = @parent.get_gconf_bool('/general/show_delete_button')
    @show_clear_button.active = @parent.get_gconf_bool('/general/show_clear_button')
    @conf_save.active = @parent.get_gconf_bool('/general/conf_save')
    @conf_quit.active = @parent.get_gconf_bool('/general/conf_quit')
    @calc_subtotal_every_time.active = @parent.get_gconf_bool('/general/calc_subtotal_every_time')
    @show_progress_bar.active = @parent.get_gconf_bool('/general/show_progress_bar')
    @graph_include_income.active = @parent.get_gconf_bool('/general/graph_include_income')
    @graph_include_expense.active = @parent.get_gconf_bool('/general/graph_include_expense')
    @hide_zero.active = @parent.hide_zero
    @history_size.value = [@parent.history_size, 1].max
    @migemo_cmd.text = @parent.migemo_cmd
    @use_migemo.active = @parent.use_migemo
  end

  def hide
    @tab_page = @tab.page
    super
  end

  def save
    @zaif_data.save_config
    @modified = false
  end

  private

  def delete_item(tree)
    itr = tree.selection.selected
    return unless (itr)

    tree.model.remove(itr)
    @modified = true
  end

  def account_delete_item
    delete_item(@account_tree)
    account_init_value
  end

  def category_delete_item
    delete_item(@category_tree)
    category_init_value
  end

  def get_account_new_id
    id = 0
    @account_tree.model.each {|m, p, itr|
      id = itr[COLUMN_ACCOUNT_ID] if (itr[COLUMN_ACCOUNT_ID] > id)
    }
    id + 1
  end

  def find_account_id(id)
    val = nil
    @account_tree.model.each {|m, p, itr|
      val = itr[COLUMN_ACCOUNT_ID] if (itr[COLUMN_ACCOUNT_ID] == id)
    }
    val
  end

  def get_category_new_id
    id = 0
    @category_tree.model.each {|m, p, itr|
      id = itr[COLUMN_CATEGORY_ID] if (itr[COLUMN_CATEGORY_ID] > id)
    }
    id + 1
  end

  def find_category_id(id)
    val = nil
    @category_tree.model.each {|m, p, itr|
      val = itr[COLUMN_CATEGORY_ID] if (itr[COLUMN_CATEGORY_ID] == id)
    }
    val
  end

  def account_new_item
    if (@account_name.text.length < 1)
      @parent.err_message(_("口座名を設定してください"), self)
      return false
    end

    if (find_account_id(@account_id.value))
      if (@parent.conf_message("id #{@account_id.value.to_i} は使用済みです。\n新しい id を自動設定しますか？", self))
        @account_id.value = get_category_new_id
      else
        return
      end
    end

    @account_id.value = get_account_new_id
    row = @account_tree.model.append
    account_set_val(row)
    @account_tree.selection.select_iter(row)
    @account_tree.scroll_to_cell(row.path, nil, false, 0, 0)
  end

  def account_apply_val(row, col, val)
    return if (val == row[col])
    case col
    when COLUMN_ACCOUNT
      if (val.length < 1)
        @parent.err_message("口座名を設定してください", self)
        return false
      end
    when COLUMN_ACCOUNT_ID
      if (find_account_id(val))
        @parent.err_message("id #{val} は使用済みです。", self)
        return false
      end
    end
    @modified = true
    true
  end

  def category_apply_val(row, col, val)
    return if (val == row[col])
    case col
    when COLUMN_CATEGORY
      if (val.length < 1)
        @parent.err_message(_("分類名を設定してください"), self)
        return false
      end
    when COLUMN_CATEGORY_ID
      if (find_category_id(val))
        @parent.err_message("id #{val} は使用済みです。", self)
        return false
      end
    end
    @modified = true
    true
  end

  def account_set_val(row)
    row[COLUMN_ACCOUNT] = @account_name.text
    row[COLUMN_CREDIT] = @account_credit.active?
    row[COLUMN_ACCOUNT_ID] = @account_id.value
    @modified = true
  end

  def category_new_item(itr = nil)
    if (@category_name.text.length < 1)
      @parent.err_message(_("分類名を設定してください"), self)
      return false
    end

    if (find_category_id(@category_id.value))
      if (@parent.conf_message("id #{@category_id.value.to_i} は使用済みです。\n新しい id を自動設定しますか？", self))
        @category_id.value = get_category_new_id
      else
        return
      end
    end
    row = @category_tree.model.append(itr)
    category_set_val(row)
    @category_tree.expand_row(itr.path, false) if (itr)
    @category_tree.selection.select_iter(row)
    @category_tree.scroll_to_cell(row.path, nil, false, 0, 0)
    category_init_value
  end

  def category_new_child
    itr = @category_tree.selection.selected
    return unless (itr)

    category_new_item(itr)
  end

  def category_new_sibling
    itr = @category_tree.selection.selected
    return unless (itr)

    category_new_item(itr.parent)
  end

  def category_set_val(row)
    row[COLUMN_CATEGORY] = @category_name.text
    row[COLUMN_EXPENSE] = @category_expense.active?
    row[COLUMN_INCOME] = @category_income.active?
    row[COLUMN_CATEGORY_ID] = @category_id.value
    @modified = true
  end

  def create_btns(data, pad = 0)
    hbox = Gtk::Box.new(:horizontal, 0)

    data.each {|b|
      label = nil
      stock = nil
      if (b[1].is_a?(Symbol))
        stock = b[1]
      else
        label = b[1]
      end
      btn = Gtk::Button.new(:label => label, :stock_id => stock)
      btn.signal_connect("clicked") {|w|
        send(b[2])
      }
      hbox.send(b[3], btn, :expand => false, :fill => false, :padding => pad)
      instance_variable_set(b[0], btn)
    }

    hbox
  end

  def create_root_btns
    create_btns([
                  [:@setup_ok_btn, Gtk::Stock::OK, :ok, :pack_end],
                  [:@setup_cancel_btn, Gtk::Stock::CANCEL, :cancel, :pack_end]
                ], 10)
  end

  def create_category_btns
    create_btns([
                  [:@category_root_btn, _("ルート"), :category_new_item, :pack_start],
                  [:@category_child_btn, _("  子  "), :category_new_child, :pack_start],
                  [:@category_sibling_btn, _(" 兄弟 "), :category_new_sibling, :pack_start],
                  [:@category_delete_btn, Gtk::Stock::DELETE, :category_delete_item, :pack_end]
                ])
  end

  def create_account_btns
    create_btns([
                  [:@account_new_btn, Gtk::Stock::ADD, :account_new_item, :pack_start],
                  [:@account_delete_btn, Gtk::Stock::DELETE, :account_delete_item, :pack_end]
                ])
  end

  def create_category_table(box)
    category_tree_model = Gtk::TreeStore.new(String, TrueClass, TrueClass, Integer)
    tree_view = TreeView.new(category_tree_model)

    [
      [_("分類"), COLUMN_CATEGORY, :text],
      [_("支出"), COLUMN_EXPENSE,  :active],
      [_("収入"), COLUMN_INCOME,   :active],
      ["id", COLUMN_CATEGORY_ID,   :text, true],
    ].each {|(title, id, type, align)|
      case type
      when :text
        renderer = Gtk::CellRendererText.new
        renderer.xalign = 1.0 if (align)
        renderer.editable = true
        renderer.signal_connect('edited') {|cell, path, str|
          iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
          str = str.to_i if (align)
          iter[id] = str if (category_apply_val(iter, id, str))
          category_init_value
        }
      when :active
        renderer = Gtk::CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect('toggled') {|cell, path|
          iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
          iter[id] = ! iter[id]
          @modified = true
        }
      end
      column = Gtk::TreeViewColumn.new(title, renderer, type => id)
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    tree_view.set_size_request(200, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.reorderable = true
    tree_view.model.signal_connect("row-deleted") {|w, path1, path2, arg3|
      @modified = true
    }

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  def create_account_table(box)
    account_tree_model = Gtk::ListStore.new(String, TrueClass, Integer)
    tree_view = TreeView.new(account_tree_model)
    @account_renderer = []
    [
      [_("口座"),       COLUMN_ACCOUNT,    :text],
      [_("クレジット"), COLUMN_CREDIT,     :active],
      ["id",            COLUMN_ACCOUNT_ID, :text, true],
    ].each {|(title, id, attribute, numeric)|
      case attribute
      when :text
        renderer = Gtk::CellRendererText.new
        renderer.xalign = 1.0 if (numeric)
        renderer.editable = true
        renderer.signal_connect('edited') {|cell, path, str|
          iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
          str = str.to_i if (numeric)
          iter[id] = str if (account_apply_val(iter, id, str))
          account_init_value
        }
      when :active
        renderer = Gtk::CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect('toggled') {|cell, path|
          iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
          iter[id] = ! iter[id]
          @modified = true
        }
      end
      column = Gtk::TreeViewColumn.new(title, renderer, attribute => id)
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    tree_view.set_size_request(200, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.reorderable = true
    tree_view.model.signal_connect("row-deleted") {|w, path1, path2, arg3|
      @modified = true
    }

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)

    tree_view
  end

  def add_option(vbox, lable_str, *widget)
    hbox = Gtk::Box.new(:horizontal, 0)
    widget.each {|w|
      if (w.instance_of?(Gtk::Entry))
        hbox.pack_start(w, :expand => true, :fill => true, :padding => 4)
        hbox.hexpand = true
      else
        hbox.pack_start(w, :expand => false, :fill => false, :padding => 4)
      end
      w.set_margin_top(PAD)
      w.set_margin_bottom(PAD)
    }

    if (lable_str)
      vbox.attach(MyLabel.new(lable_str), 0, @row, 1, 1)
      vbox.attach(hbox, 1, @row, 1, 1)
    else
      vbox.attach(hbox, 0, @row, 2, 1)
    end
    @row += 1
  end

  def create_option_page
    hbox = Gtk::Box.new(:horizontal, 1)

    vbox = Gtk::Grid.new

    @row = 0
    @path = Gtk::Entry.new
    @path.signal_connect("changed") {|w| @path_modified = true}
    add_option(vbox, _("データ保存先:"), @path)

    @calc_subtotal_every_time = Gtk::CheckButton.new(_("その日時の残高を表示する"))
    add_option(vbox, nil, @calc_subtotal_every_time)

    @conf_quit = Gtk::CheckButton.new(_("終了時に確認する"))
    add_option(vbox, nil, @conf_quit)

    @conf_save = Gtk::CheckButton.new(_("終了時に保存確認する"))
    add_option(vbox, nil, @conf_save)

    @show_delete_button = Gtk::CheckButton.new(_("削除ボタンを表示する"))
    add_option(vbox, nil, @show_delete_button)

    @show_clear_button = Gtk::CheckButton.new(_("クリアボタンを表示する"))
    add_option(vbox, nil, @show_clear_button)

    @show_progress_bar = Gtk::CheckButton.new(_("プログレスバーを表示する"))
    add_option(vbox, nil, @show_progress_bar)

    @use_migemo = Gtk::CheckButton.new(_("migemo を使う"))
    add_option(vbox, nil, @use_migemo)

    @migemo_cmd = Gtk::Entry.new
    add_option(vbox, _("migemo コマンド:"), @migemo_cmd)

    hbox.pack_start(Gtk::Frame.new.add(vbox), :expand => true, :fill => true, :padding => PAD)

    vbox = Gtk::Grid.new

    @row = 0
    @start_of_year = Gtk::SpinButton.new(1, 12, 1)
    @start_of_year.xalign = 1
    add_option(vbox, _("年度の始まり:"), @start_of_year, Gtk::Label.new(_('月'), {:use_underline => false}))

    @consumption_tax = Gtk::SpinButton.new(0, 100, 1)
    @consumption_tax.xalign = 1
    add_option(vbox, _("消費税:"), @consumption_tax, Gtk::Label.new('%', {:use_underline => false}))

    @rb_commalize_n = Gtk::RadioButton.new(:label => _("3"))
    add_option(vbox, _("数値区切桁:"), @rb_commalize_n, Gtk::RadioButton.new(:member => @rb_commalize_n, :label => _("4")))

    @rb_commalize_sep = Gtk::RadioButton.new(_(","))
    add_option(vbox, _("数値区切文字:"), @rb_commalize_sep, Gtk::RadioButton.new(:member => @rb_commalize_sep, :label => _(".")))

    @graph_include_income = Gtk::CheckButton.new(_("支出グラフの計算に収入を含める"))
    add_option(vbox, nil, @graph_include_income)

    @graph_include_expense = Gtk::CheckButton.new(_("収入グラフの計算に支出を含める"))
    add_option(vbox, nil, @graph_include_expense)

    @hide_zero = Gtk::CheckButton.new(_("表中で 0 を表示しない"))
    add_option(vbox, nil, @hide_zero)

    @history_size = Gtk::SpinButton.new(1, HIST_SIZE_MAX, 1)
    @history_size.xalign = 1
    add_option(vbox, _("履歴の数:"), @history_size)

    hbox.pack_start(Gtk::Frame.new.add(vbox), :expand => false, :fill => false, :padding => PAD)

    hbox
  end

  def create_category_page
    vbox = Gtk::Box.new(:vertical, 0)
    hbox = Gtk::Box.new(:horizontal, 0)

    @category_name = Gtk::Entry.new
    @category_expense = Gtk::CheckButton.new
    @category_income = Gtk::CheckButton.new
    @category_id = Gtk::SpinButton.new(1, 1000, 1)


    hbox.pack_start(MyLabel.new(_("分類名")), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@category_name, :expand => true, :fill => true, :padding => 0)

    hbox.pack_start(MyLabel.new("支出"), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@category_expense, :expand => false, :fill => false, :padding => 0)

    hbox.pack_start(MyLabel.new("収入"), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@category_income, :expand => false, :fill => false, :padding => 0)

    hbox.pack_start(MyLabel.new("id"), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@category_id, :expand => false, :fill => false, :padding => 0)

    @category_tree = create_category_table(vbox)

    vbox.pack_end(create_category_btns, :expand => false, :fill => false, :padding => 0)

    @category_child_btn.sensitive = false
    @category_sibling_btn.sensitive = false
    @category_delete_btn.sensitive = false

    @category_tree.selection.signal_connect("changed") {|w|
      @category_child_btn.sensitive = w.selected
      @category_sibling_btn.sensitive = w.selected
      @category_delete_btn.sensitive = w.selected
    }

    vbox.pack_end(hbox, :expand => false, :fill => false, :padding => 0)
  end

  def create_account_page
    vbox = Gtk::Box.new(:vertical, 0)
    hbox = Gtk::Box.new(:horizontal, 0)

    @account_name = Gtk::Entry.new
    @account_credit = Gtk::CheckButton.new(_("クレジット"))
    @account_id = Gtk::SpinButton.new(1, 1000, 1)

    hbox.pack_start(MyLabel.new(_("口座名")), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@account_name, :expand => true, :fill => true, :padding => 0)
    hbox.pack_start(@account_credit, :expand => false, :fill => false, :padding => 10)
    hbox.pack_start(MyLabel.new("id"), :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@account_id, :expand => false, :fill => false, :padding => 0)

    @account_tree = create_account_table(vbox)
    @account_tree.signal_connect("cursor-changed") {|w|
      itr = w.selection.selected
    }

    @account_tree.selection.signal_connect("changed") {|w|
      @account_delete_btn.sensitive = w.selected
    }

    vbox.pack_end(create_account_btns, :expand => false, :fill => false, :padding => 0)
    @account_delete_btn.sensitive = false
    vbox.pack_end(hbox, :expand => false, :fill => false, :padding => 0)
  end


  def category_init_value
    @category_name.text = ""
    @category_id.value = get_category_new_id
  end


  def account_init_value
    @account_name.text = ""
    @account_credit.active = false
    @account_id.value = get_account_new_id
  end

  def category_append_tree_item(parent, category)
    row = @category_tree.model.append(parent)
    row[COLUMN_CATEGORY] = category.to_s
    row[COLUMN_EXPENSE] = category.expense
    row[COLUMN_INCOME] = category.income
    row[COLUMN_CATEGORY_ID] = category.to_i - Zaif_config::ID_OFFSET
    category.each_child {|c|
      category_append_tree_item(row, c)
    }
  end

  def category_show_data
    @category_tree.model.clear
    @zaif_data.get_root_category.each_child {|c|
      category_append_tree_item(nil, c)
    }
    @category_tree.expand_all
    category_init_value
  end

  def account_show_data
    @account_tree.model.clear
    @zaif_data.get_accounts.each {|a|
      row = @account_tree.model.append
      row[COLUMN_ACCOUNT] = a.to_s
      row[COLUMN_CREDIT] = a.credit
      row[COLUMN_ACCOUNT_ID] = a.to_i - Zaif_config::ID_OFFSET
    }
    account_init_value
  end
end
