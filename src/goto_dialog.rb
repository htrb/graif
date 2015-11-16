# -*- coding: utf-8 -*-
# $Id: goto_dialog.rb,v 1.7 2011/09/25 12:57:52 hito Exp $

class GotoDialog < Gtk::Dialog
  def initialize(parent)
    super(:title => "移動",
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

    @year = Gtk::SpinButton.new(1900, 3000, 1)
    @month = Gtk::SpinButton.new(0, 13, 1)
    @year.xalign = 1
    @month.xalign = 1
    @year.orientation = :vertical
    @month.orientation = :vertical

    @month.signal_connect("value-changed") {|w|
      if (w.value > 12)
        @year.spin(Gtk::SpinButton::Type::STEP_FORWARD, 1)
        w.value = 1
      elsif(w.value < 1)
        @year.spin(Gtk::SpinButton::Type::STEP_BACKWARD, 1)
        w.value = 12
      end
    }

    return_key_pressed = proc {|w, e|
      case (e.keyval)
      when Gdk::Keyval::KEY_Return
        response(Gtk::ResponseType::OK)
      end
    }

    hbox = Gtk::Box.new(:horizontal, 0)
    [
      [@year, '年'],
      [@month, '月'],
    ].each {|(widget, title)|
      hbox.pack_start(widget, :expand => false, :fill => false, :padding => 10)
      hbox.pack_start(Gtk::Label.new(title, {:use_underline => false}), :expand => false, :fill => false, :padding => 0)
      widget.signal_connect("key-press-event", &return_key_pressed)
    }
    self.child.pack_start(hbox, :expand => false, :fill => false, :padding => 10)
  end

  def run(y, m, &block)
    @year.value = y
    @month.value = m
    @month.grab_focus
    show_all
    super() {|r|
      yield(r == Gtk::ResponseType::OK, @year.value.to_i, @month.value.to_i)
    }
    hide
  end
end
