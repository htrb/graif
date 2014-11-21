# -*- coding: utf-8 -*-
# $Id: receipt_dialog.rb,v 1.45 2011/09/25 12:57:52 hito Exp $

class ReceiptDialog < DialogWindow
    COLUMN_DATA = [
                   [_('分類'), :COLUMN_CATEGORY, String,  false],
                   [_('価格'), :COLUMN_EXPENSE,  Integer, true],
                   [_('割引'), :COLUMN_ADJUST,   Integer, true],
                   [_('税'),   :COLUMN_TAX,      Integer, false],
                   [_('小計'), :COLUMN_SUBTOTAL, Integer, false],
                   [_('メモ'), :COLUMN_MEMO,     String,  true], 
                  ].each_with_index {|data, i|
    const_set(data[COLUMN_DATA_ID], i)
    data[COLUMN_DATA_ID] = i
  }

  COLUMN_CATEGORY_ID = COLUMN_DATA.size

  def initialize(parent, data, calendar)
    super(parent, data)
    self.modal = true
    self.transient_for = parent
    self.title = "Receipt"

    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_W, Gdk::Keyval::KEY_w
        cancel if ((e.state & Gdk::ModifierType::CONTROL_MASK).to_i != 0)
      end
    }

    @calendar = calendar
    @zaif_data = data
    @exceptional = 
    @vbox =Gtk::Box.new(:vertical, 0)
    create_input_panel(@vbox)
    @tree_view = create_table(@vbox)
    create_setting_panel(@vbox)
    create_root_btns(@vbox)
    clear_table
    add(@vbox)
  end

  def create_table(box)
    tree_view = TreeView.new(Gtk::TreeStore.new(*COLUMN_DATA.map {|data| data[COLUMN_DATA_TYPE]}.push(Integer)))
    COLUMN_DATA.each {|data|
      title = data[COLUMN_DATA_TITLE]
      id = data[COLUMN_DATA_ID]
      type = data[COLUMN_DATA_TYPE]
      editable = data[COLUMN_DATA_EDIT]

      column = nil
      case id
      when COLUMN_CATEGORY
        renderer = Gtk::CellRendererCombo.new
        model = CategoryTreeModel.new(Zaif_category::EXPENSE)
        renderer.model = model
        renderer.has_entry = false
        renderer.editable = true
        renderer.text_column = CategoryTreeModel::COLUMN_NAME
        renderer.signal_connect('editing-started') {|cell, editable, path, str|
          editable.signal_connect('editing-done') {
            sel = editable.active_iter
            if (sel)
              iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
              iter[COLUMN_CATEGORY_ID] = sel[CategoryTreeModel::COLUMN_ITEM].to_i
              iter[COLUMN_CATEGORY] = sel[CategoryTreeModel::COLUMN_ITEM].to_s
              update_table
            end
          }
        }
      when COLUMN_MEMO
        renderer = Gtk::CellRendererText.new
        if (editable)
          renderer.editable = true
          renderer.signal_connect('edited') {|cell, path, str|
            iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
            if (path.to_s != '0')
              iter[id] = str
            end
          }
        end
      else
        renderer = Gtk::CellRendererText.new
        renderer.xalign = 1.0
        if (editable)
          renderer.editable = true
          renderer.signal_connect('edited') {|cell, path, str|
            iter = tree_view.model.get_iter(Gtk::TreePath.new(path))
            if (path.to_s != '0')
              val = str.to_i
              val = (iter[COLUMN_EXPENSE] * val / 100.0).ceil if (id == COLUMN_ADJUST && str[-1] == ?%)
              iter[id] = val
              update_table
            end
          }
        end
      end

      if (type == Integer)
        column = TreeViewColumnNumeric.new(title, renderer, id)
      else
        column = Gtk::TreeViewColumn.new(title, renderer, :text => id)
      end

      column.clickable = false
      column.resizable = true
      tree_view.append_column(column)
    }

    tree_view.set_size_request(200, 200)
    tree_view.selection.mode = Gtk::SelectionMode::SINGLE

    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.hscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.vscrollbar_policy = Gtk::PolicyType::AUTOMATIC
    scrolled_window.add(tree_view)
    box.pack_start(scrolled_window)

    tree_view.selection.signal_connect('changed') {|w|
      itr = w.selected
      if (itr && itr.path.to_s != '0')
        @delete_btn.sensitive = true
      else
        @delete_btn.sensitive = false
      end
    }
    tree_view
  end

  def show(t, exceptional)
    @time.set(t)
    @tax = @parent.consumption_tax / 100.0
    @exceptional.active = exceptional
    @tax_label.text = _("税率: ") + "#{@tax*100}%"
    @collect_same_category.active = (@parent.get_gconf_bool('/general/receipt_collect_same_category'))
    super()
  end

  def clear_table
    @tree_view.model.clear
    append_summary_row
    @total.text = ""
  end

  def append_summary_row
    row = @tree_view.model.append(nil)
    row[COLUMN_CATEGORY] = '合計'
    row[COLUMN_EXPENSE] = 0
    row[COLUMN_ADJUST] = 0
    row[COLUMN_TAX] = 0
    row[COLUMN_SUBTOTAL] = 0
  end

  def add_margin(w)
    w.set_margin_top(PAD)
    w.set_margin_bottom(PAD)
  end

  def add_hmargin(w)
    w.set_margin_start(PAD)
    w.set_margin_end(PAD)
  end

  def create_input_panel(box)
    frame = Gtk::Frame.new
    frame.set_shadow_type(Gtk::ShadowType::OUT)
    vbox = Gtk::Grid.new
    add_hmargin(vbox)

    hbox = Gtk::Box.new(:horizontal, 0)
    @category_cmb = CategoryComboBox.new(Zaif_category::EXPENSE, false)
    add_margin(@category_cmb)
    label = MyLabel.new(_("分類"))
    vbox.attach(label, 0, 0, 1, 1)
    vbox.attach(@category_cmb, 1, 0, 1, 1)

    label = MyLabel.new(_("メモ"))
    @memo_input = Memo_entry.new
    @memo_input.width_chars = 10
    @memo_input.hexpand = true
    add_margin(@memo_input)
    vbox.attach(label, 2, 0, 1, 1)
    vbox.attach(@memo_input, 3, 0, 2, 1)

    hbox = Gtk::Box.new(:horizontal, 0)
    label = MyLabel.new(_("価格"))
    @expense_input = NumericEntry.new
    @expense_input.width_chars = 8
    add_margin(@expense_input)
    vbox.attach(label, 0, 1, 1, 1)
    vbox.attach(@expense_input, 1, 1, 1, 1)

    label = MyLabel.new(_("割引"))
    @adjust_input = NumericEntry.new
    @adjust_input.width_chars = 8
    @adjust_input.hexpand = false

    @adjust_percent = Gtk::CheckButton.new('%')
    @adjust_percent.hexpand = true
    vbox.attach(label, 2, 1, 1, 1)
    vbox.attach(@adjust_input, 3, 1, 1, 1)
    vbox.attach(@adjust_percent, 4, 1, 1, 1)

    frame.add(vbox)

    box.pack_start(frame, :expand => false, :fill => false, :padding => 0)

    create_item_btns(box)
    @delete_btn.sensitive = false
  end

  def append_item
    expense = @expense_input.value.to_i
    if (expense > 0)
      row = @tree_view.model.append(@tree_view.model.iter_first)
      row[COLUMN_CATEGORY] = @category_cmb.active_item.to_s
      row[COLUMN_EXPENSE] = expense
      adj = @adjust_input.value.to_i
      row[COLUMN_ADJUST] =
        if (@adjust_percent.active?)
          (expense * adj / 100.0).ceil
        else
          adj.to_i
        end
      row[COLUMN_MEMO] = @memo_input.text
      row[COLUMN_CATEGORY_ID] =  @category_cmb.active
      @memo_input.completion_model_add_item
      @expense_input.text = ""
      @adjust_input.text = ""
      @memo_input.text = ""
      update_table
    end
  end

  def delete_item
    iter = @tree_view.selection.selected
    @tree_view.model.remove(iter)
    update_table
  end

  def create_setting_panel(vbox)
    frame = Gtk::Frame.new
    frame.set_shadow_type(Gtk::ShadowType::OUT)
    box = Gtk::Grid.new
    add_margin(box)
    add_hmargin(box)

    hbox = Gtk::Box.new(:horizontal, 0)
    @time = TimeInput.new
    box.attach(@time, 0, 0, 1, 3)

    label = MyLabel.new(_("消費税"))
    @tax_inside = Gtk::RadioButton.new(_("内税"))
    @tax_outside = Gtk::RadioButton.new(@tax_inside, _("外税"))
    @tax_inside.active = true
    @tax_inside.signal_connect('toggled') {|w|
      update_table
    }
    hbox.pack_start(@tax_outside, :expand => false, :fill => false, :padding => PAD)
    hbox.pack_start(@tax_inside, :expand => false, :fill => false, :padding => PAD)
    add_margin(hbox)

    box.attach(label, 1, 0, 1, 1)
    box.attach(hbox, 2, 0, 1, 1)

    hbox = Gtk::Box.new(:horizontal, 0)
    @account = AccountComboBox.new
    add_margin(@account)
    label = MyLabel.new(_("口座"))
    box.attach(label, 1, 1, 1, 1)
    box.attach(@account, 2, 1, 1, 1)

    @exceptional = Gtk::CheckButton.new("特別")
    add_hmargin(@exceptional)
    add_margin(@exceptional)
    box.attach(@exceptional, 3, 1, 1, 1)
    @tax_label = MyLabel.new("")
    box.attach(@tax_label, 4, 1, 1, 1)

    hbox = Gtk::Box.new(:horizontal, 0)
    @total = Gtk::Entry.new
    @total.editable = false
    @total.can_focus = false
    @total.xalign = 1
    @total.width_chars = 10
    add_margin(@total)
    label = MyLabel.new(_("合計"))
    box.attach(label, 1, 2, 1, 1)
    box.attach(@total, 2, 2, 1, 1)

    @collect_same_category = Gtk::CheckButton.new(_("同じ分類をまとめる"))
    add_hmargin(@collect_same_category)
    box.attach(@collect_same_category, 3, 2, 2, 1)

    frame.add(box)
    vbox.pack_start(frame, :expand => false, :fill => false, :padding => 0)
  end

  def create_btns(data, pad = 0)
    hbox = Gtk::Box.new(:horizontal, 0)

    data.each {|(val, stock, method, pack)|
      btn = Gtk::Button.new(:label => nil, :mnemonic => nil, :stock_id => stock)
      btn.signal_connect("clicked") {|w|
        send(method)
      }
      hbox.send(pack, btn, :expand => false, :fill => false, :padding => PAD)
      instance_variable_set(val, btn)
    }

    hbox
  end

  def create_item_btns(vbox)
    hbox = create_btns([
                        [:@clear_btn, Gtk::Stock::CLEAR, :clear_table, :pack_start],
                        [:@setup_cancel_btn, Gtk::Stock::NEW, :append_item, :pack_end],
                        [:@delete_btn, Gtk::Stock::DELETE, :delete_item, :pack_end],
                       ], 10)
    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => PAD)
  end

  def create_root_btns(vbox)
    hbox = create_btns([
                        [:@setup_ok_btn, Gtk::Stock::OK, :ok, :pack_end],
                        [:@setup_cancel_btn, Gtk::Stock::CANCEL, :cancel, :pack_end]
                       ], 10)
    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => PAD)
  end

  def update_table
    sum_expense = 0
    sum_tax = 0
    sum_adjutsment = 0
    sum = 0
    item = []
    @tree_view.model.each {|model, path, itr|
      next if (path.to_s == '0')
      expense = itr[COLUMN_EXPENSE]
      if (expense == 0)
        adj = 0
      else
        adj = itr[COLUMN_ADJUST]
      end

      if(@tax_inside.active?)
        subtotal = expense - adj
        tax = (subtotal * @tax / (1 + @tax))
      else
        tax = ((expense - adj) * @tax)
        subtotal = expense - adj + tax.to_i
      end

      tax = 0 if (tax < 0)

      item.push([path, tax])

      itr[COLUMN_EXPENSE] = expense
      itr[COLUMN_ADJUST] = adj
      itr[COLUMN_TAX] = tax.to_i
      itr[COLUMN_SUBTOTAL] = subtotal
      sum_adjutsment += adj
      sum_tax += tax.to_i
      sum_expense += expense
      sum += subtotal
    }
    @tree_view.model.iter_first[COLUMN_EXPENSE] = sum_expense
    @tree_view.model.iter_first[COLUMN_ADJUST] = sum_adjutsment
    @tree_view.model.iter_first[COLUMN_TAX] = sum_tax
    @tree_view.model.iter_first[COLUMN_SUBTOTAL] = sum
    adjust_tax(item, sum_tax, sum_expense - sum_adjutsment) if (@tax_outside.active?)
    @tree_view.expand_all
    @total.text = Commalize(@tree_view.model.iter_first[COLUMN_SUBTOTAL])
  end

  def adjust_tax(item, tax, total)
    sum_tax = 0
    sum = 0

    diff = (total * @tax).to_i - tax.to_i
    return if (diff <= 0)

    n = 0
    item.sort{|a, b| b[1] %1 <=> a[1] % 1}.each {|i|
      itr = @tree_view.model.get_iter(i[0])
      if (n < diff)
        itr[COLUMN_TAX] = (i[1].to_i + 1)
        itr[COLUMN_SUBTOTAL] = (itr[COLUMN_SUBTOTAL] + 1)
        n += 1
      end
      sum_tax += itr[COLUMN_TAX]
      sum += itr[COLUMN_SUBTOTAL]
    }
    @tree_view.model.iter_first[COLUMN_TAX] = sum_tax
    @tree_view.model.iter_first[COLUMN_SUBTOTAL] = sum
  end

  def ok
    n = if (@collect_same_category.active?)
          add_collect
        else
          add_all
        end
    if (n > 0)
      @parent.set_date_items(@calendar.year, @calendar.month + 1, @calendar.day)
      @parent.update_summary_windows(@calendar.year, @calendar.month + 1)
      @calendar.mark
      @parent.updated
    end
    hide
  end

  def add_all
    n = 0
    @tree_view.model.each {|model, path, itr|
      subtotal = itr[COLUMN_SUBTOTAL]
      next if (subtotal == 0 || path.to_s == '0')
      item = Zaif_item.new(Zaif_item::TYPE_EXPENSE,
                           @account.active,
                           @time.to_s,
                           subtotal,
                           itr[COLUMN_CATEGORY_ID],
                           itr[COLUMN_MEMO],
                           nil,
                           nil,
                           nil,
                           @exceptional.active?)
      if (item)
        @zaif_data.add_item(@calendar.year, @calendar.month + 1, @calendar.day, item)
        n += 1
      end
    }
    n
  end

  def add_collect
    item = {}
    @tree_view.model.each {|model, path, itr|
      subtotal = itr[COLUMN_SUBTOTAL]
      next if (subtotal == 0 || path.to_s == '0')

      memo = itr[COLUMN_MEMO].strip
      if (item[itr[COLUMN_CATEGORY_ID]].nil?)
        item[itr[COLUMN_CATEGORY_ID]] = [[subtotal, memo]]
      else
        item[itr[COLUMN_CATEGORY_ID]].push([subtotal, memo])
      end
    }
    n = 0
    item.each {|k, v|
      subtotal = 0
      memo = ""
      if (v.length > 1)
        v.each_with_index {|d, i|
          memo += ", " if (i > 0)
          subtotal += d[0]
          memo += "#{d[1]}(#{Commalize(d[0])})"
        }
      else
        subtotal = v[0][0]
        memo = v[0][1]
      end
      item = Zaif_item.new(Zaif_item::TYPE_EXPENSE,
                           @account.active,
                           @time.to_s,
                           subtotal,
                           k,
                           memo,
                           nil,
                           nil,
                           nil,
                           @exceptional.active?)
      if (item)
        @zaif_data.add_item(@calendar.year, @calendar.month + 1, @calendar.day, item)
        n += 1
      end
    }
    n
  end

  def cancel
    hide
  end

  def hide
    @parent.set_gconf('/general/receipt_collect_same_category', @collect_same_category.active?)
    super
  end

  def update
    @category_cmb.update(0)
    @tree_view.get_column(COLUMN_CATEGORY).cell_renderers[0].model.update
  end
end
