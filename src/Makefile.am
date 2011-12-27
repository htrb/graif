bin_SCRIPTS = graif

SOURCES = config.rb goto_dialog.rb plugins.rb raif_ui.rb		\
	  setting_panel.rb test.rb dialog.rb graph.rb main.rb raif.rb	\
	  receipt_dialog.rb search_dialog.rb setup_window.rb util.rb

EXTRA_DIST = make_graif $(SOURCES)

$(bin_SCRIPTS): $(SOURCES) make_graif Makefile
	$(RUBY_BIN) make_graif $(RUBY_FULL_PATH) $(pkgdatadir) $(pkglibdir) $(PACKAGE_VERSION) main.rb > $(bin_SCRIPTS)
	chmod 755 $(bin_SCRIPTS)

clean:
	rm -f $(bin_SCRIPTS)
