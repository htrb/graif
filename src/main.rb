# -*- coding: utf-8 -*-

=begin

Copyright (C) 2005-2006, Hiroyuki Ito. ZXB01226@nifty.com

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
USA.

=end

# $Id: main.rb,v 1.31 2011/09/25 12:57:52 hito Exp $

Encoding.default_external = Encoding::UTF_8

require 'gtk3'
require 'date'
require 'fileutils'
require 'optparse'

APP_VERSION = "0.19"
APP_NAME = "graif"
APP_AUTHORS = ["H.Ito"]
COPY_RIGHT = "Copyright © 2005-2010 #{APP_AUTHORS[0]}"
WEBSITE = "http://homepage3.nifty.com/slokar/graif/"

PKGDATADIR = "/usr/share/graif"
ICON_FILE = "#{PKGDATADIR}/icon.png"

APP_PATH = "#{ENV['HOME']}/.#{APP_NAME}"
PLUGIN_PATH = "#{APP_PATH}/plugins"
HIST_FILE = "#{APP_PATH}/history"
CONFIG_FILE = "#{APP_PATH}/#{APP_NAME}.cfg"
LOCK_FILE  = "#{APP_PATH}/graif.lock"
CONF_PATH = "/apps/#{APP_NAME}"
HIST_SIZE = 100
HIST_SIZE_MAX = 10000
MIGEMO_CMD = "cmigemo -q -d /usr/share/cmigemo/utf-8/migemo-dict"
MIGEMO_OUTPUT_UTF8 = true
MIGEMO_KCODE = Encoding::UTF_8
# MIGEMO_OUTPUT_UTF8 = false

COMMALIZE = [3, ","]

COLUMN_DATA_TITLE = 0
COLUMN_DATA_ID    = 1
COLUMN_DATA_TYPE  = 2
COLUMN_DATA_EDIT  = 3
PAD = 4

require "util"
require "raif"
require "setting_panel"
require "search_dialog"
require "goto_dialog"
require "dialog"
require "setup_window"
require "graph"
require "receipt_dialog"
require "plugins"
require "config"
require "raif_ui"

def _(s)
  s
end


def CommalizeSetiing(n, s)
  COMMALIZE[0] = n if (n.kind_of?(Integer))
  COMMALIZE[1] = s if (s.kind_of?(String))
end

def Commalize(val)
  return val.to_s if (COMMALIZE[0] < 1 || val.abs < 1000)
  val.to_s.reverse.scan(/\d{1,#{COMMALIZE[0]}}[+-]?/).join(COMMALIZE[1]).reverse
end

unless (FileTest.exist?(APP_PATH))
  Dir::mkdir(APP_PATH)
  Dir::mkdir(PLUGIN_PATH)
  Dir.chdir(PKGDATADIR) {
    Dir.glob("config.xml").each {|file|
      FileUtils.cp(file, APP_PATH)
    }
  }
end

Icon = GdkPixbuf::Pixbuf.new(:file => "#{PKGDATADIR}/pig.xpm")

date = nil

OptionParser.new {|opt|
  opt.on('-d', '--date=date') {|v|
    begin
      date = Date.parse(v)
    rescue
    end
  }

  begin
    opt.parse!(ARGV)
  rescue OptionParser::InvalidOption
  end
}

Raif = Raif_ui.new(ARGV[0])

def err_message(str, parent = Raif, type = Gtk::MessageType::ERROR, title = "Error")
  Raif.err_message(str, parent, type, title)
end

Gtk::main if (Raif.init(date))
