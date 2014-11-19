# -*- coding: utf-8 -*-
class RaifCSV < Plugin
  def main(d)
    dialog = Gtk::FileChooserDialog.new(:title => "Save CSV",
                                        :parent => @@parent,
                                        :action => :save,
                                        :buttons => [[Gtk::Stock::CANCEL, :cancel], [Gtk::Stock::SAVE, :accept]])
    dialog.set_do_overwrite_confirmation(true);

    path = get_conf("path", ENV['HOME'])

    dialog.current_name = sprintf("%04d%02d.csv", d[0], d[1])
    dialog.current_folder_uri = "file:///#{path}"

    r = dialog.run
    filename = dialog.filename
    dialog.destroy
    if (r == :accept) 
      begin
        save_conf("path", File.dirname(filename))
        save_csv(filename, d[0], d[1])
      rescue => ever
        err_message("#{filename} の保存中にエラーが発生しました。\n#{ever.to_s}")
      else
        message("#{filename} を保存しました。")
      end
    end
  end

  def save_csv(filename, y, m)
    File.open(filename, "w") {|f|
      get_data(y, m).each {|d, item|
        f.puts(item.csv2(y, m, d.date))
      }
    }
  end
end

RaifCSV.new("save_csv", "Save _CSV...")
