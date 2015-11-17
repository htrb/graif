# -*- coding: utf-8 -*-
# $Id: search_dialog.rb,v 1.11 2010-01-09 01:50:00 hito Exp $

class SearchWidget
  def initialize
    @vbox = Gtk::Grid.new
    @vbox.set_margin_start(PAD)
    @vbox.set_margin_end(PAD)

    @memo = Memo_entry.new
    @memo.activates_default = true
    @rb_memo = Gtk::RadioButton.new(:label => _("メモ: "))

    @account = AccountComboBox.new
    @rb_account = Gtk::RadioButton.new(:member => @rb_memo, :label => _("口座: "))

    @category = CategoryComboBox.new(Zaif_category::ALL)
    @rb_category = Gtk::RadioButton.new(:member => @rb_memo, :label => _("分類: "))

    @search_type = @rb_memo.group.size - 1

    [
      [@rb_memo, @memo, true],
      [@rb_account, @account, false],
      [@rb_category, @category, false]
    ].each_with_index {|(widget, val, pack), i|
      @vbox.attach(widget, 0, i, 1, 1)
      @vbox.attach(val,    1, i, 1, 1)
      val.set_margin_top(PAD)
      val.set_margin_bottom(PAD)
      if (pack)
        val.halign = :fill
      else
        val.halign = :start
      end
      val.sensitive = false
      val.hexpand = pack
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

  def update
    @account.update
    @category.update
  end
end

class SearchDialog < Gtk::Dialog
  def initialize(parent)
    super(:title => "検索",
          :parent => parent,
          :flags => Gtk::DialogFlags::MODAL,
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
