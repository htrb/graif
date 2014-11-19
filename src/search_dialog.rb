# -*- coding: utf-8 -*-
# $Id: search_dialog.rb,v 1.11 2010-01-09 01:50:00 hito Exp $

class SearchWidget
  def initialize
    @vbox =Gtk::Box.new(:vertical, 0)

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
      hbox = Gtk::Box.new(:horizontal, 0)
      hbox.pack_start(widget, :expand => false, :fill => false, :padding => 0)
      hbox.pack_start(val, :expand => pack, :fill => pack, :padding => 0)
      @vbox.pack_start(hbox, :expand => false, :fill => false, :padding => 4)
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
    super(:title => "検索",
          :parent => parent,
          :flags => Gtk::Dialog::Flags::MODAL,
          :buttons => [
            [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
            [Gtk::Stock::OK, Gtk::ResponseType::OK]
          ]
         )

    signal_connect("delete-event") {|w, e|
      w.hide
      w.signal_emit_stop("delete-event")
    }

    @search_item = SearchWidget.new

    self.child.pack_start(@search_item.widget, :expand => false, :fill => false, :padding => 10)
    set_default_response(Gtk::ResponseType::OK)
  end

  def run(&block)
    show_all
    super {|r|
      yield(r == Gtk::ResponseType::OK, @search_item.type, @search_item.word)
    }
    hide
  end

  def update
    @category.update(0)
    @account.update(0)
  end
end
