# $Id: plugins.rb,v 1.10 2008-01-02 02:51:35 hito Exp $

class Plugin
  attr_reader :title
  @@instances = []

  def Plugin::instances
    @@instances
  end

  def Plugin::init(parent, data, calendar)
    @@zaif_data = data
    @@parent = parent
    @@calendar = calendar

    Dir.glob("#{PLUGIN_PATH}/*.rb") {|file|
      require(file)
    }
  end

  def Plugin::update
    @@instances.each {|i|
      i.update
    }
  end

  def initialize(name, title)
    @title = name
    @title = title
    @@instances.push(self)
    @conf_path = "/plugins/#{name.gsub(' ', '_').downcase}"
    @category_combo_box = []
    @account_combo_box = []
    @category_tree_model = []
    @account_tree_model = []
  end

  def main
  end

  def update
    @category_combo_box.each {|c|
      c.update
    }
    @account_combo_box.each {|a|
      a.update
    }
    @category_tree_model.each {|c|
      c.update
    }
    @account_tree_model.each {|a|
      a.update
    }
  end

  def create_account_tree_model
    @account_tree_model.push(AccountTreeModel.new)
    @account_tree_model[-1]
  end

  def create_account_combo_box
    @account_combo_box.push(AccountComboBox.new)
    @accountcombobox[-1]
  end

  def create_expense_category_tree_model
    @category_tree_model.push(CategoryTreeModel.new(Zaif_category::EXPENSE))
    @category_tree_model[-1]
  end

  def create_income_category_tree_model
    @category_tree_model.push(CategoryTreeModel.new(Zaif_category::INCOME))
    @category_tree_model[-1]
  end

  def create_category_tree_model
    @category_tree_model.push(CategoryTreeModel.new(Zaif_category::ALL))
    @category_tree_model[-1]
  end

  def create_expense_category_combo_box
    @category_combo_box.push(CategoryComboBox.new(Zaif_category::EXPENSE))
    @categorycombobox[-1]
  end

  def create_income_category_combo_box
    @category_combo_box.push(CategoryComboBox.new(Zaif_category::INCOME))
    @categorycombobox[-1]
  end

  def create_category_combo_box
    @category_combo_box.push(CategoryComboBox.new(Zaif_category::ALL))
    @categorycombobox[-1]
  end

  def call(d)
    main(d)
    @@parent.set_date_items(@@calendar.year, @@calendar.month + 1, @@calendar.day)
  end

  def get_data(y, m)
    @@zaif_data.get_month_data(y, m)
  end

  def err_message(str, parent = Raif)
    @@parent.err_message(str, parent)
  end

  def message(str, parent = Raif)
    @@parent.message(str, parent)
  end

  def conf_message(str, parent = Raif, default = true)
    @@parent.conf_message(str, parent, default)
  end

  def get_conf(path, init = true)
    val = @@parent.get_gconf("#{@conf_path}/#{path}")
    (val.nil?) ? init : val
  end

  def save_conf(path, val)
    @@parent.set_gconf("#{@conf_path}/#{path}", val)
  end

  def add_new_item(y, m, d, item)
    return unless (item)

    @@parent.goto(y, m, d)
    @@zaif_data.add_item(y, m, d, item)
    @@calendar.mark
    @@parent.updated
    @@parent.update_summary_windows(@@calendar.year, @@calendar.month + 1)
  end

  def update_summary(y = @@calendar.year, m = @@calendar.month + 1, d = @@calendar.day)
    @@parent.set_date_items(y, m, d)
  end
end
