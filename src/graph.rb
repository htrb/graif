# -*- coding: utf-8 -*-
# $Id: graph.rb,v 1.56 2011/09/25 12:57:52 hito Exp $

class GraphWindow < DialogWindow
  def initialize(parent, data)
    super
    @graph = Graph.new
    set_size_request(600, 400)
    @year = Date.today.year
    @data = []

    @category_expense = CategoryComboBox.new(Zaif_category::EXPENSE, true)
    @category_expense.signal_connect("changed"){|w|
      draw(@year, true)
    }

    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::GDK_KEY_W, Gdk::Keyval::GDK_KEY_w
        hide if ((e.state & Gdk::Window::CONTROL_MASK).to_i != 0)
      end
    }

    @category_income = CategoryComboBox.new(Zaif_category::INCOME, true)
    @category_income.signal_connect("changed"){|w|
      draw(@year, true)
    }

    signal_connect('key-press-event') {|w, e|
      case (e.keyval)
      when Gdk::Keyval::GDK_KEY_W, Gdk::Keyval::GDK_KEY_w
        hide if ((e.state & Gdk::Window::CONTROL_MASK).to_i != 0)
      end
    }

    vbox = Gtk::VBox.new
    vbox.pack_start(@category_expense, false, false, 0)
    vbox.pack_start(@category_income, false, false, 0)
    vbox.pack_start(@graph, true, true, 0)
    vbox.pack_start(create_btns, false, false, 0)

    @category = @category_expense
    self.add(vbox)
  end

  def refresh
    draw(@year, true)
  end

  def show(y, m)
    super()
    @month = m
    
    if (@category_expense == @category)
      @category_income.visible = false
    else
      @category_expense.visible = false
    end
    draw(y)
  end

  def draw(y, redraw = false)
    if ((@refresh_btn.visible? || redraw || @data.size < 1 || y != @year) &&
        @category.active_item)
      category = []
      @category.active_item.each_child {|c|
        if (@graph_type.active == 0)
          next unless (c.expense)
        else
          next unless (c.income)
        end
        category.push(c.to_s)
      }
      if (@category.active_item.to_i != 0)
        category.push(@category.active_item.to_s)
      end
      @year = y
      y, start = @parent.get_start_of_year(y, @month)
      self.title = sprintf('%04d年度 (%d/%02d-%d/%02d)',
                           y,
                           y, start + 1,
                           (start == 0)? y: y + 1, (start == 0)? 12: start)
      if (@graph_type.active == 0)
        @graph.set_title("#{y}年度支出")
      else
        @graph.set_title("#{y}年度収入")
      end
      @graph.set_legend(category)
      get_data(y, start)
    end
    @graph.draw(@data, @parent.start_of_year)
  end

  def get_category_summary(category, summary)
    esum = summary[category.to_i][0].to_i
    isum = summary[category.to_i][1].to_i

    category.each_child {|c|
      es, is  = get_category_summary(c, summary)
      esum += es
      isum += is
    }
    [esum, isum]
  end

  def update(y = @year)
    @category.update(false, true)
    if (y == @year)
      @refresh_btn.visible = true
    end
  end

  def get_data(y = @year, start = 0)
    include_income = (@parent.get_gconf_bool('/general/graph_include_income'))
    include_expense = (@parent.get_gconf_bool('/general/graph_include_expense'))

    @refresh_btn.visible = false
    @data.clear
    item = @category.active_item
    id = item.to_i

    (1..12).each {|m|
      @progress.show_progress((m -1) / 12.0) if (@parent.progress_bar?)
      @data[m - 1] = []
      summary = @zaif_data.get_category_summary(y, m + start, @exceptional.active?)
      next unless (item)
      item.each_child {|c|
        if (@graph_type.active == 0)
          next unless (c.expense)
        else
          next unless (c.income)
        end
        e, i = get_category_summary(c, summary)
        if (@graph_type.active == 0)
          if (include_income)
            @data[m - 1].push(e - i)
          else
            @data[m - 1].push(e)
          end
        else
          if (include_expense)
            @data[m - 1].push(i - e)
          else
            @data[m - 1].push(i)
          end
        end
      }
      if (id != 0)
        if (@graph_type.active == 0)
          if (include_income)
            @data[m - 1].push(summary[id][0].to_i - summary[id][1].to_i)
          else
            @data[m - 1].push(summary[id][0].to_i)
          end
        else
          if (include_expense)
            @data[m - 1].push(summary[id][1].to_i - summary[id][0].to_i)
          else
            @data[m - 1].push(summary[id][1].to_i)
          end
        end
      end
    }
    @progress.end_progress
  end

  def show_toggle(y, m)
    if (self.visible?)
      hide
    else
      show(y, m)
    end
  end

  def show_prev
    draw(@year - 1)
  end

  def show_next
    draw(@year + 1)
  end

  def show_today
    draw(Date.today.year)
  end

  def create_btns
    hbox = Gtk::HBox.new

    [
      [Gtk::Stock::GO_BACK,    :show_prev,  :pack_start],
      [_(' 今年 '),            :show_today, :pack_start],
      [Gtk::Stock::GO_FORWARD, :show_next,  :pack_start],
      [Gtk::Stock::CLOSE,      :hide,       :pack_end],
      [Gtk::Stock::REFRESH,    :refresh,    :pack_end],
    ].each {|(title, method, pack)|
      btn = Gtk::Button.new(title)
      btn.signal_connect('clicked') {|w|
        send(method)
      }
      hbox.send(pack, btn, false, false, 0)
      @refresh_btn = btn if (method == :refresh)
    }

    @graph_type = Gtk::ComboBox.new
    ["支出", "収入"].each {|i|
      @graph_type.append_text(i)
    }
    @graph_type.active = 0
    @graph_type.signal_connect("changed") {|w|
      case w.active
      when 0
        @category_income.visible = false
        @category_expense.visible = true
        @category = @category_expense
      when 1
        @category_income.visible = true
        @category_expense.visible = false
        @category = @category_income
      end
      draw(@year, true)
    }
    hbox.pack_start(@graph_type, false, false, 10)

    @exceptional = Gtk::CheckButton.new("含特別")
    @exceptional.signal_connect("clicked"){|w|
      draw(@year, true)
    }
    hbox.pack_start(@exceptional, false, false, 0)
    @progress = MyProgressBar.new
    hbox.pack_start(@progress, true, true, 10)
    hbox
  end
end


class Graph < Gtk::DrawingArea
  COLOR_UNIT = 256
  COLOR = [
    [0xff, 0xff, 0xcc],
    [0xff, 0xcc, 0xff],
    [0xcc, 0xff, 0xff],
    [0xff, 0xcc, 0xcc],
    [0xcc, 0xcc, 0xff],
    [0xcc, 0xff, 0xcc],
    [0xcc, 0xcc, 0xcc],
    [0xff, 0xff, 0x99],
    [0xcc, 0xcc, 0x99],
    [0xff, 0xff, 0x33],
    [0xff, 0xcc, 0x99],
    [0xff, 0x99, 0xff],
    [0xcc, 0x99, 0xcc],
    [0xff, 0x33, 0xff],
    [0xff, 0x99, 0xcc],
    [0x99, 0xff, 0xff],
    [0x99, 0xcc, 0xcc],
    [0x33, 0xff, 0xff],
    [0x99, 0xff, 0xcc],
  ]
  LineWidth = 1
  Dash = [1, 2]

  def initialize
    @gc = nil

    super
    @min_x = 1
    @max_x = 12
    @inc_x = 1

    @min_y = 0
    @max_y = 100000
    @inc_y = 10

    @gauge_len = 5
    @num_margin = 4

    @bar_margin = 10
    @top_margin = 50
    @bottom_margin = 50
    @left_margin = 50
    @right_margin = 50

    @legend_margin = 20
    @legend_size = 16

    @bar_width = 1
    @width = 300
    @height = 300

    @data = nil
    @legend = nil

    @caption_x = _('月')
    @caption_y = _('金額')
    @title = ''

    signal_connect("expose_event") {|w, e|
      draw(@data) if (@data && @data.size > 0)
    }

    modify_fg(Gtk::STATE_NORMAL, self.style.black)
    modify_bg(Gtk::STATE_NORMAL, self.style.white)
  end

  def init
    @gc = Gdk::GC.new(self.window)
#   @gc.set_colormap(Gdk::Colormap::system)
    @gc.set_dashes(0, Dash)
    COLOR.collect! {|c|
      Gdk::Color::new(c[0] * COLOR_UNIT, c[1] * COLOR_UNIT, c[2] * COLOR_UNIT)
    }
  end

  def set_title(t)
    @title = t
  end

  def set_legend(legend)
    @legend = legend
  end

  def draw(data, start = nil)
    if (start)
      @min_x = start
      @max_x = @min_x + 11
    end

    @data = data
    auto_scale(data)
    redraw
  end

  def redraw
    init if (@gc.nil?)
    clear
    draw_frame
    @data.each_with_index {|d, i|
      draw_bar_graph(i + @min_x, d)
    }
  end

  def draw_bar_graph(x, data)
    x = get_x(x)
    y = get_y(0)
    psum = 0
    msum = 0

    data.each_with_index {|val, i|
      y1 = 0
      y2 = 0

      if (val > 0)
        y1 = @height * psum / (@max_y - @min_y)
        psum += val
        y2 = @height * psum / (@max_y - @min_y)
      elsif (val < 0)
        y2 = @height * msum / (@max_y - @min_y)
        msum += val
        y1 = @height * msum / (@max_y - @min_y)
      else
        next
      end
      draw_frame_rect(i,
                      x - @bar_width, y - y2,
                      x + @bar_width, y - y1)
    }
  end

  def draw_frame_rect(color, x1, y1, x2, y2)
    set_color(color)
    draw_rect(x1, y1, x2, y2, true)
    set_color(self.style.black)
    draw_rect(x1, y1, x2, y2)
  end

  def clear
    set_color(self.style.white)
    draw_rect(0, 0, allocation.width, allocation.height, true)
  end

  def draw_frame
    title = create_pango_layout(@title)
    draw_text(@left_margin + (@width - title.pixel_size[0]) / 2,
              (@top_margin - title.pixel_size[1]) / 2,
              title)
    draw_rect(@left_margin, @top_margin,
              @left_margin + @width, @top_margin + @height)
    y = get_y(0)
    draw_line(@left_margin, y, @left_margin + @width, y)
    prange = Range.new(0, @max_y)
    mrange = Range.new(0, -@min_y)
    prange.step(@inc_y) {|v|
      draw_gauge_y(v)
    }
    mrange.step(@inc_y) {|v|
      next if (v == 0)
      draw_gauge_y(-v)
    }

    Range.new(@min_x, @max_x).step(@inc_x) {|v|
      draw_gauge_x(v)
    }
    draw_legend
  end

  def draw_legend
    return if (@legend.nil?)
    y = @top_margin + @height
    x = @left_margin + @width + @legend_margin
    @legend.each_with_index {|l, i|
      legend = create_pango_layout(l)
      h = legend.pixel_size[1]
      y -= [h, @legend_size].max
      draw_text(x + @legend_size + @num_margin,
                y + ((@legend_size > h) ? (@legend_size - h) / 2: 0),
                legend)
      draw_frame_rect(i, x, y, x + @legend_size, y + @legend_size)
      y -= @legend_margin / 2
    }
  end

  def draw_gauge_y(v)
    y = get_y(v)
    set_line_style(Gdk::GC::LINE_ON_OFF_DASH)
    draw_line(@left_margin, y, @left_margin + @width, y)
    set_line_style(Gdk::GC::LINE_SOLID)
    num = create_pango_layout(Commalize(v))
    w, h =  num.pixel_size
    draw_text(@left_margin - w - @num_margin, y - h / 2, num)
    caption = create_pango_layout(@caption_y)
    draw_text(@num_margin, @top_margin + @height / 2, caption)
  end

  def draw_gauge_x(v)
    x = get_x(v)
    v -= 12 if (v > 12)
    draw_line(x, @top_margin, x, @top_margin + @gauge_len)
    draw_line(x, @top_margin + @height, x, @top_margin + @height - @gauge_len)
    num = create_pango_layout(Commalize(v))
    w, h =  num.pixel_size
    draw_text(x - w / 2, @top_margin + @height + @num_margin, num)
    caption = create_pango_layout(@caption_x)
    draw_text(@left_margin + (@width - caption.pixel_size[0]) / 2,
              @top_margin + @height + h + @legend_margin,
              caption)
  end

  def draw_rect(x1, y1, x2, y2, fill = false)
    self.window.draw_rectangle(@gc, fill, x1, y1, (x2 - x1).abs, (y2 - y1).abs)
  end

  def draw_line(x1, y1, x2, y2)
    self.window.draw_line(@gc, x1, y1, x2, y2)
  end

  def draw_text(x, y, text)
    set_color(self.style.black)
    self.window.draw_layout(@gc, x, y, text)
  end

  def set_line_style(style)
    @gc.set_line_attributes(LineWidth, style,
                            Gdk::GC::CAP_BUTT, Gdk::GC::JOIN_MITER)
  end
 
  def set_color(c)
    if (c.kind_of?(Numeric))
      @gc.set_rgb_fg_color(COLOR[c % COLOR.size])
    elsif (c.kind_of?(Gdk::Color))
      @gc.set_rgb_fg_color(c)
    end
  end

  def auto_scale(data)
    min, max = data.inject([0, 0]) {|val, d|
      msum, psum = d.inject([0, 0]) {|sum, v|
        if (v > 0)
          sum[1] += v
        else
          sum[0] += v
        end
        sum
      }
      val[0] = [val[0], msum].min
      val[1] = [val[1], psum].max
      val
    }
    margin = [max * 1.05 - max, min - min * 1.05].max
    @max_y = (((max + margin) / 1000).to_i + 1) * 1000
    @min_y = (min < 0) ? (((min - margin) / 1000).to_i - 1) * 1000 : 0

    @inc_y = 10 ** Math::log10(@max_y - @min_y).to_i
    n = ((@max_y - @min_y) / @inc_y).to_i
    if (n < 2)
      @inc_y /= 5
    elsif (n < 4)
      @inc_y /= 2
    end
    @inc_x = 1

    h = create_pango_layout(@title).pixel_size[1]
    @top_margin = [@top_margin, h].max

    h = create_pango_layout(@caption_x).pixel_size[1]
    @bottom_margin = (h + @num_margin) * 2 + @legend_margin

    maxs = create_pango_layout(Commalize(@max_y)).pixel_size[0]
    mins = create_pango_layout(Commalize(@min_y)).pixel_size[0]
    @left_margin =
      [maxs, mins].max + create_pango_layout(@caption_y).pixel_size[0] +
      @num_margin * 2 + @legend_margin
    @right_margin = 
      @legend.collect{|l| create_pango_layout(l).pixel_size[0]}.max.to_i +
      @legend_margin * 2 + @num_margin + @legend_size if (@legend)
    @width = [allocation.width - @left_margin - @right_margin, 100].max
    @height = [allocation.height - @top_margin - @bottom_margin, 100].max
    @bar_width = ((@width  - @bar_margin) / (@max_x - @min_x + 1) - @bar_margin) / 2
  end

  def get_y(y)
    (@top_margin + @height - 1.0 * (y - @min_y) * @height / (@max_y - @min_y)).round
  end

  def get_x(x)
    (1.0 * (x - @min_x) * (@width - @bar_margin) / (@max_x - @min_x + 1) +
       @left_margin + @bar_margin + @bar_width).round
  end
end
