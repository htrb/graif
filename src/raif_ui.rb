# -*- coding: utf-8 -*-
# $Id: raif_ui.rb,v 1.162 2011/09/25 12:57:52 hito Exp $

class Raif_ui < Gtk::Window
  COLUMN_DATA = [
                 ['*',       :COLUMN_TYPE,     String],
                 [_('分類'), :COLUMN_CATEGORY, String],
                 [_('収入'), :COLUMN_INCOME,   Numeric],

                 [_('支出'), :COLUMN_EXPENSE,  Numeric],
                 [_('口座'), :COLUMN_ACCOUNT,  String],
                 [_('時刻'), :COLUMN_TIME,     String],

                 [_('メモ'), :COLUMN_MEMO,     String],
                ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_ITEM = COLUMN_DATA.size

  [
   :SEARCH_CANCEL,
   :SEARCH_FROM_TOP,
   :SEARCH_PREV_MONTH,
   :SEARCH_NEXT_MONTH,
  ].each_with_index {|sym, i|
    const_set(sym, i)
  }

  MyIcons = Gtk::IconFactory.new
  [
   ["bar_graph",   _('分類グラフ(_G)')],
   ["book_red",    _('分類集計(_C)')],
   ["book_blue",   _('口座集計(_A)')],
   ["book_green",  _('項目集計(_I)')],
   ["book_yellow", _('口座出入金集計(_O)')],
   ["book_open",   _('月データ一覧(_S)')],
   ["pig",           'graif'],
  ].each { |(icon, label)|
    const_set(icon.upcase, icon.to_sym)
    Gtk::Stock.add(icon.to_sym, label)
    MyIcons.add(icon, Gtk::IconSet.new(Gdk::Pixbuf.new("#{PKGDATADIR}/#{icon}.xpm")))
  }
  MyIcons.add_default

  def initialize(path)
    super(Gtk::WindowType::TOPLEVEL)

    @app_conf = GraifConfig.new(CONFIG_FILE)
    @setup_win = nil
    @zaif_data = nil
    @summary = nil
    @budget_win = nil
    @search_dialog = nil
    @receipt_dialog = nil

    @clipboard = Gtk::Clipboard.get('PRIMARY')

    @window_group = Gtk::WindowGroup#    @window_group.add(self)

    self.path = path
    set_icon(Icon)

    @search_word = nil
    @search_type = nil
    @zaif_data = Zaif_data.new
    @zaif_data.read_config

    hbox = Gtk::Box.new(:horizontal, 0)
    vbox = Gtk::Box.new(:vertical, 0)
    vbox_tab = Gtk::Box.new(:vertical, 0)

    create_ui(vbox)

    CategoryTreeModel.set_category(@zaif_data.get_root_category)
    AccountTreeModel.set_accouts(@zaif_data.get_accounts)

    @delete_btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => Gtk::Stock::DELETE)
    @modify_btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => Gtk::Stock::APPLY)
    @append_btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => Gtk::Stock::NEW)
    @clear_btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => Gtk::Stock::CLEAR)

    signal_connect('delete_event'){|w, e|
      close
      w.signal_emit_stop('delete-event')
    }
    signal_connect('destroy_event'){|w, e|
      close
      w.signal_emit_stop('destroy_event')
    }

    @tab = SettingPanel.new(@zaif_data, self)

    @tab.signal_connect('switch-page') {|w, page, n|
      w.init_value(n + 1, false)
      @tree_view.selection.unselect_all
    }

    @calendar = Gtk::Calendar.new
    @calendar.signal_connect('day-selected') {|w|
      @tab.date(w.year, w.month + 1, w.day)
      set_date_items(w.year, w.month + 1, w.day)
      set_action_sensitive("ViewGoBackAction", @calendar.back?)
      set_action_sensitive("ViewGoForwardAction", @calendar.forward?)
    }

    @calendar.signal_connect('month-changed') {|w|
      m = @zaif_data.get_month_data(w.year, w.month + 1)
      m.find_init
    }

    @tree_view = create_table

    @tree_view.selection.signal_connect('changed') {|w|
      itr = w.selected
      if (itr)
        item = itr.get_value(COLUMN_ITEM)
        @tab.set_value(item, true)
        w.select_iter(itr)

        set_action_sensitive("EditDeleteAction", true)
        set_action_sensitive("EditCopyAction", true)
        set_action_sensitive("EditCutAction", true)
        @delete_btn.sensitive = true
        @modify_btn.sensitive = true
      else
        set_action_sensitive("EditDeleteAction", false)
        set_action_sensitive("EditCopyAction", false)
        set_action_sensitive("EditCutAction", false)
        @delete_btn.sensitive = false
        @modify_btn.sensitive = false
      end
    }

    @tree_view.signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Left
        if ((e.state & Gdk::ModifierType::SHIFT_MASK).to_i != 0)
          @calendar.prev_month
        elsif ((e.state & Gdk::ModifierType::MOD1_MASK).to_i != 0)
          @calendar.back
        else
          @calendar.prev_day
        end
      when Gdk::Keyval::KEY_Right
        if ((e.state & Gdk::ModifierType::SHIFT_MASK).to_i != 0)
          @calendar.next_month
        elsif ((e.state & Gdk::ModifierType::MOD1_MASK).to_i != 0)
          @calendar.forward
        else
          @calendar.next_day
        end
      when Gdk::Keyval::KEY_Delete
        delete_item(@tree_view.selection.selected)
      end
    }

    @tree_view.signal_connect('button-press-event') {|w, e|
      return false unless (e.kind_of?(Gdk::EventButton))
      case (e.button)
      when 3
        @tree_view_menu.popup(nil, nil, 3, Gtk.current_event_time)
      when 8
        @calendar.back
      when 9
        @calendar.forward
      end
      false
    }

    Plugin.init(self, @zaif_data, @calendar)
    create_plugin_menu

    set_action_sensitive("ViewGoForwardAction", false)
    set_action_sensitive("ViewGoBackAction", false)
    set_action_sensitive("FileSaveAction", false)

    @delete_btn.signal_connect('clicked') {|w|
      delete_item(@tree_view.selection.selected)
    }

    @modify_btn.signal_connect('clicked') {|w|
      itr = @tree_view.selection.selected
      if (itr)
        item = itr.get_value(COLUMN_ITEM)
        if (@tab.update_item(@calendar.year, @calendar.month + 1, @calendar.day, item))
          set_date_items(@calendar.year, @calendar.month + 1, @calendar.day)
          update_summary_windows(@calendar.year, @calendar.month + 1)
          @calendar.mark
          set_action_sensitive("FileSaveAction", true)
        else
          err_message("入力内容に誤りがあります")
        end
      end
    }

    @append_btn.signal_connect('clicked') {|w|
      item = @tab.create_item
      if (item && @zaif_data.add_item(@calendar.year, @calendar.month + 1, @calendar.day, item))
        set_date_items(@calendar.year, @calendar.month + 1, @calendar.day)
        update_summary_windows(@calendar.year, @calendar.month + 1)
        @calendar.mark
        set_action_sensitive("FileSaveAction", true)
      else
        err_message("入力内容に誤りがあります")
      end
    }

    @clear_btn.signal_connect('clicked') {|w|
      @calendar.select_day(@calendar.day)
    }

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(@tree_view)

    @subtotal_panel = SubtotalPanel.new

    hbox_btn = create_btns

    vbox.pack_start(scrolled_window, :expand => true, :fill => true, :padding => 0)
    vbox.pack_start(@subtotal_panel, :expand => false, :fill => false, :padding => 0)

    vbox_tab.pack_start(@tab, :expand => true, :fill => true, :padding => 0)
    vbox_tab.pack_start(hbox_btn, :expand => false, :fill => false, :padding => 0)

    hbox.pack_start(@calendar, :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(vbox_tab, :expand => true, :fill => true, :padding => 0)
    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => 0)

    add(vbox)
  end

  def create_ui(vbox)
    @ui = Gtk::UIManager.new
    @action_group = Gtk::ActionGroup.new(APP_NAME);
    define_action_item(@action_group)
    @ui.insert_action_group(@action_group, 0)

    @accel_group = @ui.accel_group
    add_accel_group(@accel_group);

    if (FileTest.exist?("#{APP_PATH}/graif.xml"))
      @ui.add_ui("#{APP_PATH}/graif.xml")
    else
      @ui.add_ui("#{PKGDATADIR}/graif.xml")
    end

    w = @ui.get_widget("/MenuBar")
    vbox.pack_start(w, :expand => false, :fill => false, :padding => 0)

    w = @ui.get_widget("/Toolbar")
    vbox.pack_start(w, :expand => false, :fill => false, :padding => 0)

    @tree_view_menu = @ui.get_widget("/Popup")
  end

  def check_process
    if (File.exist?(LOCK_FILE))
      return false unless (conf_message("他の #{APP_NAME} が起動している可能性があります。\n新しく#{APP_NAME} を起動しますか？", self, false))
    end
    true
  end

  def init(date)
    return false unless (check_process)
    File.open(LOCK_FILE, "w").close

    main_size = get_gconf('/window/main_geomtry')
    self.parse_geometry(main_size) if (main_size)

    CommalizeSetiing(get_gconf_int('/general/commalize_num'),
                     get_gconf('/general/commalize_separator'))

    if (date)
      goto(date.year, date.month, date.day)
    else
      @calendar.select_day(@calendar.day)
    end
    @tree_view.grab_focus

    set_gconf('/process/pid', Process.pid)

    @tab.calc_subtotal_every_time = get_gconf_bool('/general/calc_subtotal_every_time')
    Memo_entry.load_history(HIST_FILE, history_size)
    show_all

    delete_btn_state(get_gconf_bool('/general/show_delete_button'))
    clear_btn_state(get_gconf_bool('/general/show_clear_button'))
    @show_progress_bar = get_gconf_bool('/general/show_progress_bar')
    set_hide_zero(hide_zero)

    Memo_entry.use_migemo(use_migemo, migemo_cmd)

    true
  end

  def set_action_sensitive(name, state)
    action = @action_group.get_action(name)
    action.sensitive = state if (action)
  end

  def define_action_item(action_group)
    [
     [
      "FileSaveAction",
      nil, #_('_Save data'),
      _('Save data'),
      proc{
        save(false)
      },
      Gtk::Stock::SAVE,
     ],
     [
      "FileQuitAction",
      nil, #_("_Quit"),
      _("Quit program"),
      proc{close},
      Gtk::Stock::QUIT,
     ],
     [
      "EditCutAction",
      nil, #_("_Cut"),
      _("Cut"),
      proc{do_cut},
      Gtk::Stock::CUT,
     ],
     [
      "EditCopyAction",
      nil, #_("_Copy"),
      _("Copy"),
      proc{do_copy},
      Gtk::Stock::COPY,
     ],
     [
      "EditPasteAction",
      nil, #_("_Paste"),
      _("Paste"),
      proc{do_paste},
      Gtk::Stock::PASTE,
     ],
     [
      "EditDeleteAction",
      nil, #_('_Delete'),
      _('Delete selected'),
      proc{delete_item},
      Gtk::Stock::DELETE,
     ],
     [
      "EditSearchAction",
      nil, #_("_Search"),
      _("Search"),
      proc{search_dialog},
      Gtk::Stock::FIND,
     ],
     [
      "EditSearchNextAction",
      _("_Search next"),
      _("Search next"),
      proc{search_forward},
     ],
     [
      "SettingPreferenceAction",
      nil, #_("_Preference"),
      _("Preference"),
      proc{show_setup_win},
      Gtk::Stock::PREFERENCES,
     ],
     [
      "SettingBudgetAction",
      _("予算入力(_B)"),
      '予算の設定を行ないます',
      proc{show_budget_win(@calendar.year, @calendar.month + 1)},
     ],
     [
      "ViewShowSummaryAction",
      _('集計(_S)'),
      _('集計を表示します'),
      proc{show_summary(@calendar.year, @calendar.month + 1)},
      BOOK_OPEN
     ],
     [
      "ViewGotoAction",
      _('移動(_T)'),
      '指定月に移動します',
      proc{show_goto_dialog(@calendar.year, @calendar.month + 1)},
      Gtk::Stock::JUMP_TO
     ],
     [
      "ViewPrevMonthAction",
      _('前月(_P)'),
      '前月に移動します',
      proc{@calendar.prev_month},
      Gtk::Stock::MEDIA_PREVIOUS
     ],
     [
      "ViewPrevDayAction",
      _('前日(_P)'),
      '前日に移動します',
      proc{@calendar.prev_day},
      Gtk::Stock::MEDIA_REWIND
     ],
     [
      "ViewTodayAction",
      _('本日(_T)'),
      '本日に移動します',
      proc{@calendar.today},
      Gtk::Stock::HOME
     ],
     [
      "ViewNextDayAction",
      _('翌日(_N)'),
      '翌日に移動します',
      proc{@calendar.next_day},
      Gtk::Stock::MEDIA_FORWARD
     ],
     [
      "ViewNextMonthAction",
      _('翌月(_P)'),
      '翌月に移動します',
      proc{@calendar.next_month},
      Gtk::Stock::MEDIA_NEXT
     ],
     [
      "ViewGoBackAction",
      _('戻る(_B)'),
      '戻る',
      proc{@calendar.back},
      Gtk::Stock::GO_BACK
     ],
     [
      "ViewGoForwardAction",
      _('進む(_F)'),
      '進む',
      proc{@calendar.forward},
      Gtk::Stock::GO_FORWARD
     ],
     [
      "HelpAboutAction",
      nil, #_("_About"),
      _("About this software"),
      proc{create_about},
      Gtk::Stock::ABOUT,
     ],
     [
      "FileMenuAction",
      nil, #_("_File"),
      _("File"),
      nil,
      Gtk::Stock::FILE,
     ],
     [
      "EditMenuAction",
      nil, #_("_Edit"),
      _("Edit"),
      nil,
      Gtk::Stock::EDIT,
     ],
     [
      "ViewMenuAction",
      _("_View"),
      _("View"),
      nil,
      nil,
     ],
     [
      "SettingMenuAction",
      _("_Settings"),
      _("Settings"),
      nil,
      nil,
     ],
     [
      "HelpMenuAction",
      nil, #_("_Help"),
      _("Help"),
      nil,
      Gtk::Stock::HELP,
     ],
     [
      "FilePluginMenuAction",
      _("_Plugin"),
      _("Plugin"),
      nil,
      nil,
     ],
    ].each { |item|
      action = Gtk::Action.new(item[0], :label => item[1], :tooltip => item[2], :stock_id => item[4])
      if (item[3])
        action.signal_connect("activate") {
          item[3].call
        }
      end
      action_group.add_action(action)
    }
    action_group.translation_domain = nil
  end

  def create_plugin_menu
    parent = @ui.get_widget("/MenuBar/FileMenu/FilePluginMenu")
    menu = Gtk::Menu.new
    parent.submenu = menu
    Plugin.instances.collect {|i|
      begin
        item = Gtk::MenuItem.new(i.title);
        item.signal_connect("activate") {
          i.call(@calendar.date)
        }
        menu.append(item)
      rescue => ever
        nil
      end
    }.compact
  end

  def add_group(win)
    @window_group.add(win)
  end
  
  def delete_btn_state(state)
    @delete_btn.visible = (state == true)
  end

  def clear_btn_state(state)
    @clear_btn.visible = (state == true)
  end

  def goto(y, m, d, item = nil)
    @calendar.year = y
    @calendar.month = m - 1
    @calendar.day = d
    select_item(item) if (item)
  end

  def save_win_size
    main_geom  = self.size.join('x')
    main_geom += self.position.collect{|v| sprintf('%+d', v)}.join('')
    set_gconf('/window/main_geomtry', main_geom)
  end

  def set_gconf(path, val)
    @app_conf["#{CONF_PATH}#{path}"] = val.to_s unless (val.nil?)
  end

  def get_gconf(path)
    @app_conf["#{CONF_PATH}#{path}"]
  end

  def get_gconf_bool(path)
    @app_conf["#{CONF_PATH}#{path}"] == "true"
  end

  def get_gconf_int(path)
    @app_conf["#{CONF_PATH}#{path}"].to_i
  end

  def progress_bar?
    @show_progress_bar
  end

  def start_of_year
    m = get_gconf_int('/general/start_of_year')
    if (!m.is_a?(Numeric) || m < 1 || m > 12)
      1
    else
      m.to_i
    end
  end

  def history_size
    m = get_gconf('/general/history_size')
    if (m)
      m.to_i
    else
      HIST_SIZE
    end
  end

  def history_size=(val)
    set_gconf('/general/history_size', val)
  end

  def consumption_tax
    m = get_gconf_int('/general/consumption_tax')
    if (!m.is_a?(Numeric) || m < 0 || m > 100)
      5
    else
      m.to_i
    end
  end

  def use_migemo
    get_gconf_bool('/general/use_migemo')
  end

  def use_migemo=(val)
    set_gconf('/general/use_migemo', val)
  end

  def hide_zero
    get_gconf_bool('/general/hide_zero')
  end

  def set_hide_zero(val)
    set_gconf('/general/hide_zero', val)
    TreeViewColumnNumeric.hide_zero = val
  end

  def hide_zero=(val)
    set_hide_zero(val)
  end

  def migemo_cmd
    cmd = get_gconf('/general/migemo_command')
    cmd = MIGEMO_CMD unless (cmd)
    cmd
  end

  def migemo_cmd=(val)
    set_gconf('/general/migemo_command', val)
  end

  def get_start_of_year(y, m)
    start = start_of_year
    if (m < start)
      y -= 1
    end
    m = start - 1
    [y, m]
  end

  def close
    save if (@zaif_data.modified || (@setup_win && @setup_win.modified))

    conf_quit = (get_gconf_bool('/general/conf_quit'))

    if (! conf_quit || conf_message(_('プログラムを終了しますか？'), self, false))
      Memo_entry.save_history(HIST_FILE, history_size)
      set_gconf('/process/pid', 0)
      @summary.hide if (@summary)
      save_win_size
      @app_conf.save
      Gtk::main_quit
      File.delete(LOCK_FILE)
    end
  end

  def path=(path)
    unless (path)
      if (get_gconf('/general/path'))
        path = get_gconf('/general/path')
      else
        path = APP_PATH
      end
    end

    save if (@zaif_data)

    Dir.mkdir(path) unless (File.exist?(path))
    Dir.chdir(path)

    set_gconf('/general/path', Dir.pwd)
  end

  def save(conf = nil)
    save_conf(conf)
    save_data(conf)
    set_action_sensitive("FileSaveAction", (@setup_win.modified || @zaif_data.modified)) if (@setup_win && @zaif_data)
  end

  def update
    @calendar.day = @calendar.day
  end

  def show_receipt_dialog(time, exceptional)
    @receipt_dialog = ReceiptDialog.new(self, @zaif_data, @calendar) if (@receipt_dialog.nil?)
    @receipt_dialog.show(time, exceptional)
  end

  def set_date_items(y, m, d)
    @tree_view.model.clear
    data = @zaif_data.get_day_data(y, m, d)
    income = 0
    expense = 0
    data.each {|i|
      row = @tree_view.model.append
      case (i.type)
      when Zaif_item::TYPE_EXPENSE
        row[COLUMN_TYPE] = '-'
        row[COLUMN_CATEGORY] =
          @zaif_data.get_category_by_id(i.category, true, false).to_s
        row[COLUMN_INCOME] = 0.0
        row[COLUMN_EXPENSE] = i.amount
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
        expense += i.amount
      when Zaif_item::TYPE_INCOME
        row[COLUMN_TYPE] = '+'
        row[COLUMN_CATEGORY] =
          @zaif_data.get_category_by_id(i.category, true, false).to_s
        row[COLUMN_INCOME] = i.amount
        row[COLUMN_EXPENSE] = 0.0
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
        income += i.amount
      when Zaif_item::TYPE_MOVE
        row[COLUMN_TYPE] = '='
        row[COLUMN_INCOME] = i.amount
        row[COLUMN_EXPENSE] = (-1 * i.fee_sign * i.fee)
        row[COLUMN_CATEGORY] = @zaif_data.get_account_by_id(i.account).to_s
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account_to).to_s
        # fix me
        if (i.fee_sign < 0)
          expense += i.fee
        else
          income += i.fee
        end
      when Zaif_item::TYPE_ADJUST
        row[COLUMN_TYPE] = '*'
        row[COLUMN_EXPENSE] = i.amount
        row[COLUMN_ACCOUNT] = @zaif_data.get_account_by_id(i.account).to_s
      end
      row[COLUMN_TYPE] = "(#{row[COLUMN_TYPE]})" if (i.exceptional)
      row[COLUMN_TIME] = i.time
      row[COLUMN_MEMO] = i.memo
      row[COLUMN_ITEM] = i
    }
    @tab.init_value(nil, false)
    @subtotal_panel.set(y, m, d, income, expense)
  end

  def update_summary_windows(y, m)
    @summary.update(y, m) if (@summary)
  end

  def updated
    set_action_sensitive("FileSaveAction", true)
  end


  def message(str, parent = self)
    err_message(str, parent, Gtk::MessageType::INFO, "Information")
  end

  def err_message(str, parent = self, type = Gtk::MessageType::ERROR, titie = "Error")
    mes = Gtk::MessageDialog.new(:parent => parent,
                                 :flags => Gtk::DialogFlags::MODAL,
                                 :type => type,
                                 :buttons_type => Gtk::ButtonsType::OK,
                                 :message => str.to_s)
    mes.title = title.to_s
    mes.run
    mes.destroy
  end

  def conf_message(str, parent = self, default = true, type = Gtk::MessageType::QUESTION)
    mes = Gtk::MessageDialog.new(:parent => parent,
                                 :flags => Gtk::DialogFlags::MODAL,
                                 :type => type,
                                 :buttons_type => Gtk::ButtonsType::YES_NO,
                                 :message => str)
    if (default)
      mes.set_default_response(Gtk::ResponseType::YES)
    else
      mes.set_default_response(Gtk::ResponseType::NO)
    end
    mes.title = "Confirm"
    r = mes.run
    mes.destroy
    r == Gtk::ResponseType::YES
  end

  private

  def show_summary(y, m)
    @summary = SummaryDialog.new(self, @zaif_data) if (@summary.nil?)
    @summary.show(y, m)
  end

  def show_budget_win(y, m)
    if (@budget_win.nil?)
      @budget_win = BudgetDialog.new(self, @zaif_data)
      @budget_win.signal_connect('hide') {|w|
        set_action_sensitive("FileSaveAction", true) if (@zaif_data.modified)
      }
    end
    @budget_win.show(y, m)
  end

  def show_setup_win
    if (@setup_win.nil?)
      @setup_win = SetupWindow.new(self, @zaif_data)
      @setup_win.signal_connect('hide') {|w|
        if (w.modified)
          AccountComboBox.update
          CategoryComboBox.update
          @tab.update_account_selection(0)
          @tab.update_category_selection(0)
          @search_dialog.update if (@search_dialog)
          @receipt_dialog.update if (@receipt_dialog)
          @calendar.select_day(@calendar.day)
          Plugin.update
          set_action_sensitive("FileSaveAction", true)
          update_summary_windows(@calendar.year, @calendar.month + 1)
        end
        @tab.calc_subtotal_every_time = (get_gconf_bool('/general/calc_subtotal_every_time'))
        @tab.update_subtotals
        Memo_entry::use_migemo(use_migemo, migemo_cmd)
        @show_progress_bar = (get_gconf_bool('/general/show_progress_bar'))
      }
    end
    @setup_win.show
  end

  def show_goto_dialog(y, m)
    if (@goto_dialog.nil?)
      @goto_dialog = GotoDialog.new(self)
    end
    @goto_dialog.run(y, m) {|r, yy, mm|
      goto(yy, mm, 1) if (r)
    }
  end

  def toolbar_my_item2(title, pr, icon)
    toolbar_my_item(title, title, pr, icon)
  end

  def do_paste
    if (focus.kind_of?(Gtk::Editable))
      focus.paste_clipboard
    elsif (focus == @tree_view)
      paste_clipboard
    end
  end

  def do_cut
    if (focus.kind_of?(Gtk::Editable))
      focus.cut_clipboard
    elsif (focus == @tree_view)
      cut_item(@tree_view.selection.selected)
    end
  end

  def do_copy
    if (focus.kind_of?(Gtk::Editable))
      focus.copy_clipboard
    elsif (focus == @tree_view)
      copy_item(@tree_view.selection.selected)
    end
  end

  def delete_item(itr = @tree_view.selection.selected)
    if (itr)
      item = itr.get_value(COLUMN_ITEM)
      @zaif_data.delete_item(@calendar.year, @calendar.month + 1, @calendar.day, item)
      set_date_items(@calendar.year, @calendar.month + 1, @calendar.day)
      update_summary_windows(@calendar.year, @calendar.month + 1)
      @calendar.mark
      set_action_sensitive("FileSaveAction", true)
    end
  end

  def copy_item(itr)
    if (itr)
      item = itr.get_value(COLUMN_ITEM)
      @clipboard.text = item.csv
    end
  end

  def cut_item(itr)
    copy_item(itr)
    delete_item(itr)
  end

  def paste_clipboard
    @clipboard.request_text{|clipboard, text|
      item = Zaif_item.new_from_csv(text)
      if (item && @zaif_data.add_item(@calendar.year, @calendar.month + 1, @calendar.day, item))
        set_date_items(@calendar.year, @calendar.month + 1, @calendar.day)
        update_summary_windows(@calendar.year, @calendar.month + 1)
        @calendar.mark
        set_action_sensitive("FileSaveAction", true)
      end
    }
  end

  def save_conf(conf = nil)
    if (conf.nil?)
      conf_save = (get_gconf_bool('/general/conf_save'))
    else
      conf_save = conf
    end

    if (@setup_win && @setup_win.modified && (! conf_save || conf_message(_('設定を保存しますか？'))))
      begin
        @setup_win.save
      rescue => ever
        err_message("設定保存時にエラーが発生しました。\n#{ever.to_s}\n設定が正常に保存されていない可能性があります。")
      end
    end
  end

  def save_data(conf = nil)
    if (conf.nil?)
      conf_save = (get_gconf_bool('/general/conf_save'))
    else
      conf_save = conf
    end

    if (@zaif_data && @zaif_data.modified && (! conf_save || conf_message(_('データを保存しますか？'))))
      begin
        @zaif_data.save_data
        @calendar.mark_clear
        set_action_sensitive("FileSaveAction", false)
      rescue => ever
        err_message("データ保存時にエラーが発生しました。\n#{ever.to_s}\nデータが正常に保存されていない可能性があります。")
      end
    end
  end

  def search_dialog
    response = false
    @search_dialog = SearchDialog.new(self) if (@search_dialog.nil?)
    @search_dialog.run {|r, type, word|
      response = r
      @search_type = type
      @search_word = word
    }

    return unless (response)

    if (@search_type && @search_word)
      month = @zaif_data.get_month_data(@calendar.year, @calendar.month + 1)
      month.find_init
      search_forward
    end
  end

  def search_forward
    search_dialog unless (@search_word && @search_type)
    type = @search_type
    response = SEARCH_FROM_TOP

    loop {
      month = @zaif_data.get_month_data(@calendar.year, @calendar.month + 1)
      d, i = month.find_next(@search_word, type)
      if (d && i)
        @calendar.day = d.date
        select_item(i)
        break
      else
        response =  search_message("'#{@search_word}' は見つかりませんでした。", response)
        case (response)
        when SEARCH_FROM_TOP
          month.find_init
        when SEARCH_PREV_MONTH
          @calendar.prev_month(false)
          month.find_init
        when SEARCH_NEXT_MONTH
          @calendar.next_month(false)
          month.find_init
        else
          break
        end
      end
    }
  end

  def search_message(str, resonse)
    mes = Gtk::MessageDialog.new(:parent => self,
                                 :flags => :modal,
                                 :type => :question,
                                 :buttons_type => :none,
                                 :message => str)
    mes.add_button(Gtk::Stock::CANCEL, SEARCH_CANCEL)
    mes.add_button("最初から", SEARCH_FROM_TOP)
    mes.add_button("前月", SEARCH_PREV_MONTH)
    mes.add_button("翌月", SEARCH_NEXT_MONTH)
    mes.set_default_response(resonse)
    mes.title = "Search"
    r = mes.run
    mes.destroy
    r
  end

  def create_table
    tree_view = TreeView.new(Gtk::ListStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Zaif_item)))
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
        renderer.xalign = 0.5 if (id == COLUMN_TYPE)
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end
      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new('', renderer)
    column.visible = false
    tree_view.append_column(column)

    tree_view.set_size_request(600, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE
    tree_view.enable_grid_lines = Gtk::TreeViewGridLines::VERTICAL

    tree_view
  end

  def select_item(item)
    @tree_view.model.each {|model, path, iter|
      @tree_view.selection.select_iter(iter) if (iter[COLUMN_ITEM] == item)
    }
  end

  def create_btns
    hbox = Gtk::Box.new(:horizontal, 0)

    @delete_btn.sensitive = false
    @modify_btn.sensitive = false

    [@delete_btn, @modify_btn, @append_btn].each {|btn|
      hbox.pack_end(btn, :expand => false, :fill => false, :padding => 0)
    }

    hbox.pack_end(@clear_btn, :expand => false, :fill => false, :padding => 20)
  end

  def create_about
    Gtk::AboutDialog.show(self,
                          :program_name => APP_NAME,
                          :version => APP_VERSION,
                          :copyright => COPY_RIGHT,
                          :comments => "#{APP_NAME} は zaif とデータ互換の家計簿ソフトです",
                          :authors => APP_AUTHORS,
                          :website => WEBSITE,
                          :license_type => :gpl_3_0,
                          :logo => Icon,
                          )
  end
end
