# -*- coding: utf-8 -*-
# $Id: setting_panel.rb,v 1.44 2010-02-25 06:59:16 hito Exp $

require 'thread'

class SettingPanel < Gtk::Notebook
  PAD = 2
  attr_writer :calc_subtotal_every_time

  def initialize (zaif_data, parent)
    super()
    @zaif_data = zaif_data
    @year = nil
    @month = nil
    @date = nil
    @calc_subtotal_every_time = false
    @parent = parent
    @today = Time.now

    [
      [_("支出"), create_expenses_page],
      [_("収入"), create_income_page],
      [_("移動"), create_move_page],
      [_("調整"), create_adjustment_page]
    ].each {|(title, method)|
      append_page(method, MyLabel.new(title))
    }
#    update_account_selection(0)
#    update_category_selection(0)
  end

  def date(y, m, d)
    @year = y
    @month = m
    @date = d
  end

  def create_expenses_page
    vbox = Gtk::VBox.new

    receipt_btn = Gtk::Button.new(_('レシート入力'))
    receipt_btn.signal_connect('clicked') {|w|
      @parent.show_receipt_dialog(@expenses_page_time.to_s, @expenses_page_exceptional.active?)
    }
    @expenses_page_time = create_time_input(vbox, receipt_btn)
    @expenses_page_category, @expenses_page_exceptional = create_category_input(Zaif_category::EXPENSE, vbox)
    @expenses_page_amount, @expenses_page_subtotal, @expenses_page_account = create_amount_input(vbox)
    @expenses_page_memo = create_memo_input(vbox)
    vbox
  end

  def create_income_page
    vbox = Gtk::VBox.new

    @income_page_time = create_time_input(vbox)
    @income_page_category, @income_page_exceptional = create_category_input(Zaif_category::INCOME, vbox)
    @income_page_amount, @income_page_subtotal, @income_page_account = create_amount_input(vbox)
    @income_page_memo = create_memo_input(vbox)
    vbox
  end

  def create_move_page
    vbox = Gtk::VBox.new
    hbox = Gtk::HBox.new

    @move_page_from = AccountComboBox.new
    @move_page_to = AccountComboBox.new

    @move_page_amount, tmp, tmp2 = create_amount_input(hbox, false, 0)
    hbox.pack_start(@move_page_from, false, false, PAD)
    hbox.pack_start(MyLabel.new("->"), false, false, 0)
    hbox.pack_start(@move_page_to, false, false, PAD)

    @move_page_time = create_time_input(vbox)
    vbox.pack_start(hbox, false, false, PAD)
    @move_page_sign, @move_page_fee = create_fee_input(vbox)
    @move_page_memo = create_memo_input(vbox)
    vbox
  end

  def create_adjustment_page
    vbox = Gtk::VBox.new
    hbox = Gtk::HBox.new

    subtotal = Gtk::Button.new(_("小計"))

    @adjustment_page_missing = Gtk::Entry.new
    @adjustment_page_missing.width_chars = 12
    @adjustment_page_missing.editable = false
    @adjustment_page_missing.can_focus = false
    @adjustment_page_missing.xalign = 1

    hbox.pack_start(subtotal, false, false, 10)
    hbox.pack_start(MyLabel.new(_("不明額")), false, false, PAD)
    hbox.pack_start(@adjustment_page_missing, false, false, PAD)

    @adjustment_page_time = create_time_input(vbox)
    @adjustment_page_amount, @adjustment_page_subtotal, @adjustment_page_account = create_amount_input(vbox)
    vbox.pack_start(hbox, false, false, PAD)
    @adjustment_page_memo = create_memo_input(vbox)

    subtotal.signal_connect("clicked") {|w|
      break if (! @adjustment_page_account.active)
      sum = @zaif_data.get_account_summation(@adjustment_page_account.active,
                                             @year, @month, @date,
                                             @adjustment_page_time.to_s)
      val = @adjustment_page_amount.value
      if (!val || val == 0)
        @adjustment_page_amount.value = sum
        val = sum
      end
      @adjustment_page_missing.text = Commalize(val - sum)
    }

    vbox
  end

  def create_amount_input(paernt, account = true, pad = PAD)
    hbox = Gtk::HBox.new
    entry = IntegerEntry.new
    entry.width_chars = 10
    if (account)
      cmb = AccountComboBox.new
      subtotal = Gtk::Entry.new
      subtotal.can_focus = false
      subtotal.editable = false
      subtotal.width_chars = 10
      subtotal.xalign = 1

      cmb.signal_connect("changed") {|w|
        update_subtotals
      }
    end

    hbox.pack_start(MyLabel.new(_("金額")), false, false, PAD)
    hbox.pack_start(cmb, false, false, PAD) if (account)
    hbox.pack_start(entry, true, true, PAD)
    if (account)
      hbox.pack_start(Gtk::Label.new(_(" 残高:")), false, false, PAD)
      hbox.pack_start(subtotal, false, false, PAD)
    end
    paernt.pack_start(hbox, false, false, pad)

    [entry, subtotal, cmb]
  end

  def create_time_input(paernt, btn = nil)
    hbox = Gtk::HBox.new
    t = TimeInput.new(PAD)
    hbox.pack_start(t, false, false, PAD)
    hbox.pack_end(btn, false, false, PAD) if (btn)
    paernt.pack_start(hbox, false, false, PAD)
    t
  end

  def create_category_input(type, paernt)
    hbox = Gtk::HBox.new

    cmb = CategoryComboBox.new(type, false)
    label = MyLabel.new(_("分類"))

    chk = Gtk::CheckButton.new("特別")

    hbox.pack_start(label, false, false, PAD)
    hbox.pack_start(cmb, false, false, PAD)
    hbox.pack_start(chk, false, false, PAD)
    paernt.pack_start(hbox, false, false, PAD)

    [cmb, chk]
  end

  def create_memo_input(paernt)
    hbox = Gtk::HBox.new
    entry = Memo_entry.new
    label = MyLabel.new(_("メモ"))

    hbox.pack_start(label, false, false, PAD)
    hbox.pack_start(entry, true, true, PAD)
    paernt.pack_start(hbox, false, false, PAD)

    entry
  end

  def create_fee_input(paernt)
    hbox = Gtk::HBox.new
    cmb = Gtk::ComboBox.new
    entry = IntegerEntry.new
    label = MyLabel.new(_("手数料"))

    entry.width_chars = 7
    cmb.append_text(" - ")
    cmb.append_text(" + ")
    cmb.active = 0

    hbox.pack_start(label, false, PAD)
    hbox.pack_start(cmb, false, false, PAD)
    hbox.pack_start(entry, false, false, PAD)
    paernt.pack_start(hbox, false, false, PAD)

    [cmb, entry]
  end

=begin
  def update_account_selection(active = false)
    [
      @expenses_page_account,
      @income_page_account,
      @move_page_from,
      @move_page_to,
      @adjustment_page_account,
    ].each {|cmb|
      cmb.update
      cmb.active = active if (active)
    }
  end

  def update_category_selection(active = false)
    @expenses_page_category.update
    @income_page_category.update
    @expenses_page_category.active = active if (active)
    @income_page_category.active = active if (active)
  end
=end

  def init_value(type = nil, init_time = true)
    t = Time.new
    time = sprintf("%02d:%02d", t.hour, t.min)
    type = self.page + 1 if (!type)
    init_item = Zaif_item.new(type,
                              false,
                              time,
                              0,
                              false,
                              "",
                              false,
                              0,
                              0,
                              false)
    set_value(init_item, false, init_time)
  end

  def update_subtotal(subtotal, account, time)
    return if (@year.nil? || @month.nil? || @date.nil?)
    if (@calc_subtotal_every_time)
      sum = @zaif_data.get_account_summation(account.active,
                                             @year, @month, @date,
                                             time.to_s)
      subtotal.text = Commalize(sum)
    else
      month = @zaif_data.get_month_data(@today.year, @today.month)
      if (month)
        s = month.subtotals[account.active]
        if (s)
          subtotal.text = Commalize(s)
        else
          subtotal.text = ""
        end
      end
    end
  end

  def update_subtotals
    [
      [@expenses_page_subtotal, @expenses_page_account, @expenses_page_time],
      [@income_page_subtotal, @income_page_account, @income_page_time],
      [@adjustment_page_subtotal, @adjustment_page_account, @adjustment_page_time]
    ].each {|(subtotal, account, time)|
      update_subtotal(subtotal, account, time)
    }
  end

  def set_value(item, change_page = true, init_time = true)
    self.page = item.type - 1 if (change_page)
    case item.type
    when Zaif_item::TYPE_EXPENSE
      @expenses_page_time.set(item.time) if (init_time)
      @expenses_page_category.active = item.category if (item.category)
      @expenses_page_amount.value = item.amount
      @expenses_page_account.active = item.account if (item.account)
      @expenses_page_memo.text = item.memo.to_s
      @expenses_page_exceptional.active = item.exceptional
    when Zaif_item::TYPE_INCOME
      @income_page_time.set(item.time) if (init_time)
      @income_page_category.active = item.category if (item.category)
      @income_page_amount.value = item.amount
      @income_page_account.active = item.account if (item.account)
      @income_page_memo.text = item.memo.to_s
      @income_page_exceptional.active = item.exceptional
    when Zaif_item::TYPE_MOVE
      @move_page_from.active = item.account if (item.account)
      @move_page_to.active = item.account_to if (item.account_to)
      @move_page_amount.value = item.amount
      @move_page_time.set(item.time) if (init_time)
      @move_page_sign.active = (item.fee_sign + 1) / 2
      @move_page_fee.value = item.fee
      @move_page_memo.text = item.memo.to_s
    when Zaif_item::TYPE_ADJUST
      @adjustment_page_time.set(item.time) if (init_time)
      @adjustment_page_amount.value = item.amount
      @adjustment_page_missing.text = ""
      @adjustment_page_account.active = item.account if (item.account)
      @adjustment_page_memo.text = item.memo.to_s
    end
    update_subtotals
  end

  def update_item(y, m, d, item)
    return if (self.page != item.type - 1)

    case item.type
    when Zaif_item::TYPE_EXPENSE
      val = @expenses_page_amount.value
      if (!val)
        @expenses_page_amount.grab_focus
        return false
      end
      return false if (!val)
      @expenses_page_memo.completion_model_add_item
      @zaif_data.update_item(y, m, d, item,
                             @expenses_page_account.active,
                             @expenses_page_time.to_s,
                             val,
                             @expenses_page_category.active,
                             @expenses_page_memo.text,
                             nil, nil, nil, @expenses_page_exceptional.active?)
    when Zaif_item::TYPE_INCOME
      val = @income_page_amount.value
      if (!val)
        @income_page_amount.grab_focus
        return false
      end
      @income_page_memo.completion_model_add_item
      @zaif_data.update_item(y, m, d, item,
                             @income_page_account.active,
                             @income_page_time.to_s,
                             val,
                             @income_page_category.active,
                             @income_page_memo.text,
                             nil, nil, nil, @income_page_exceptional.active?)
    when Zaif_item::TYPE_MOVE
      val = @move_page_amount.value
      if (!val)
        @move_page_amount.grab_focus
        return false
      end
      fee = @move_page_fee.value
      if (!fee)
        @move_page_fee.grab_focus
        return false
      end
      @move_page_memo.completion_model_add_item
      @zaif_data.update_item(y, m, d, item,
                             @move_page_from.active,
                             @move_page_time.to_s,
                             val,
                             nil,
                             @move_page_memo.text,
                             @move_page_to.active,
                             fee,
                             @move_page_sign.active * 2 - 1,
                             false)
    when Zaif_item::TYPE_ADJUST
      val = @adjustment_page_amount.value
      if (!val)
        @adjustment_page_amount.grab_focus
        return false
      end
      @adjustment_page_memo.completion_model_add_item
      @zaif_data.update_item(y, m, d, item,
                             @adjustment_page_account.active,
                             @adjustment_page_time.to_s,
                             val,
                             nil,
                             @adjustment_page_memo.text,
                             nil, nil, nil, false)
    end
  end

  def create_item
    today = Time.now
    @today = today if (@today.month != today.month)

    case self.page + 1
    when Zaif_item::TYPE_EXPENSE
      val = @expenses_page_amount.value
      if (!val)
        @expenses_page_amount.grab_focus
        return false
      end
      @expenses_page_memo.completion_model_add_item
      Zaif_item.new(self.page + 1,
                    @expenses_page_account.active,
                    @expenses_page_time.to_s,
                    val,
                    @expenses_page_category.active,
                    @expenses_page_memo.text,
                    nil, nil, nil,
                    @expenses_page_exceptional.active?)
    when Zaif_item::TYPE_INCOME
      val = @income_page_amount.value
      if (!val)
        @income_page_amount.grab_focus
        return false
      end
      @income_page_memo.completion_model_add_item
      Zaif_item.new(self.page + 1,
                    @income_page_account.active,
                    @income_page_time.to_s,
                    val,
                    @income_page_category.active,
                    @income_page_memo.text,
                    nil, nil, nil,
                    @income_page_exceptional.active?)
    when Zaif_item::TYPE_MOVE
      val = @move_page_amount.value
      if (!val)
        @move_page_amount.grab_focus
        return false
      end
      fee = @move_page_fee.value
      if (!fee)
        @move_page_fee.grab_focus
        return false
      end
      @move_page_memo.completion_model_add_item
      Zaif_item.new(self.page + 1,
                    @move_page_from.active,
                    @move_page_time.to_s,
                    val,
                    nil,
                    @move_page_memo.text,
                    @move_page_to.active,
                    fee,
                    @move_page_sign.active * 2 - 1,
                    false)
    when Zaif_item::TYPE_ADJUST
      val = @adjustment_page_amount.value
      if (!val)
        @adjustment_page_amount.grab_focus
        return false
      end
      @adjustment_page_memo.completion_model_add_item
      Zaif_item.new(self.page + 1,
                    @adjustment_page_account.active,
                    @adjustment_page_time.to_s,
                    val,
                    nil,
                    @adjustment_page_memo.text,
                    nil, nil, nil, false)
    end
  end
end
