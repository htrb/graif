# -*- coding: utf-8 -*-
# $Id: search_dialog.rb,v 1.11 2010-01-09 01:50:00 hito Exp $

class SearchWidget
  def initialize
    @vbox =Gtk::VBox.new

    @memo = Memo_entry.new
    @memo.activates_default = true
    @rb_memo = Gtk::RadioButton.new(_("メモ: "))

    @account = AccountComboBox.new
    @rb_account = Gtk::RadioButton.new(@rb_memo, _("口座: "))

    @category = CategoryComboBox.new(Zaif_category::ALL)
    @rb_category = Gtk::RadioButton.new(@rb_memo, _("分類: "))

    @search_type = @rb_memo.group.size - 1

    [
      [@rb_memo, @memo, true],
      [@rb_account, @account, false],
      [@rb_category, @category, false]
    ].each {|(widget, val, pack)|
      hbox = Gtk::HBox.new
      hbox.pack_start(widget, false, false, 0)
      hbox.pack_start(val, pack, pack, 0)
      @vbox.pack_start(hbox, false, false, 4)
      val.sensitive = false
      widget.signal_connect("toggled") {|w|
        if (w.active?)
          @search_type = w.group.index(w)
        end
        val.sensitive = w.active?
      }
      val.signal_connect("changed") {|w|
        widget.active = true
      }
    }
    @rb_account.active = true
    @rb_memo.active = true
  end

  def widget
    @vbox
  end

  def type
    case (@search_type)
    when 0
      :@category
    when 1
      :@account
    when 2
      :@memo
     end
  end

  def word
    case (@search_type)
    when 0
      @category.active_item
    when 1
      @account.active_item
    when 2
      @memo.completion_model_add_item
      @memo.text
    end
  end
end

class SearchDialog < Gtk::Dialog
  def initialize(parent)
    super("検索",
          parent,
          Gtk::Dialog::MODAL,
          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
          [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK]
          )

    signal_connect("delete-event") {|w, e|
      w.hide
      w.signal_emit_stop("delete-event")
    }

    @search_item = SearchWidget.new

    self.vbox.pack_start(@search_item.widget, false, false, 10)
    set_default_response(Gtk::Dialog::RESPONSE_OK)
  end

  def run(&block)
    show_all
    super {|r|
      yield(r == Gtk::Dialog::RESPONSE_OK, @search_item.type, @search_item.word)
    }
    hide
  end

  def update
    @category.update(0)
    @account.update(0)
  end
end
