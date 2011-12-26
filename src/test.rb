require 'gtk2'

def build_tree(tree, model, model2)

    root = model.append(nil)
    root.set_value(0, "Root")

    for i in 1..4
       sub = model.append(root)
       sub.set_value(0, "Foo#{i}")
       for i in 1..2
         sub2 = model.append(sub)
         sub2.set_value(0, "Bar#{i}")
#         sub2.set_value(1, model2.iter_first[0])
       end
    end
    @window.show_all
end

# Initialize Gtk
Gtk.init

# Create the main window:
@window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
@window.set_size_request(400, 400)
@window.signal_connect("delete_event") { Gtk.main_quit }
@window.set_border_width(5)
@window.set_title("TreeStore Example");

vbox2 = Gtk::VBox.new(false, 0)
scroller = Gtk::ScrolledWindow.new
scroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
@window.add(vbox2)
vbox2.pack_start(scroller, true, true, 0)
vbox2.pack_start($acombo, false, false, 0)

model = Gtk::TreeStore.new(String, String)
tree = Gtk::TreeView.new(model)

render1 = Gtk::CellRendererText.new
render1.editable = true

render2 = Gtk::CellRendererCombo.new
model2 = Gtk::TreeStore.new(String, String)
render2.model = model2
render2.has_entry = false
render2.editable = true
row = nil
["aaa", "bb", "cc"].each {|c|
  row = model2.append(row)
  row[0] = c
  row[1] = c + "2"
}
render2.text_column = 0

render2.signal_connect('edited') do |cell, path, str|
  tree.model.get_iter(Gtk::TreePath.new(path))[1] = str
end

c1 = Gtk::TreeViewColumn.new("Headings", render1, {:text => 0})
c2 = Gtk::TreeViewColumn.new("Combo",    render2, {:text => 1})

tree.append_column(c1)
tree.append_column(c2)

scroller.add(tree)
build_tree(tree, model, model2)

tree.expand_all

e = Gtk::Entry.new

h = Gtk::EntryCompletion.new 
m = Gtk::ListStore.new(String)
h.set_model(m)

row = m.append
row[0] = "牛乳×、水"

row = m.append
row[0] = "asdfgh"

row = m.append
row[0] = "cdefg"

h.set_match_func{|completion, key, iter|
  iter[0][0, key.length] == key
}

h.popup_completion = true
h.inline_completion = false
h.set_text_column(0)

e.set_completion(h)

e.text = "牛乳×、水"

vbox2.pack_start(e, false, false)

@window.show_all
Gtk.main
