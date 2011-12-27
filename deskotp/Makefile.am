gnomedatadir = $(datadir)

pixmapdir = $(gnomedatadir)/pixmaps
pixmap_DATA = application-x-graif.png

desktopdir = $(datadir)/applications
desktop_in_files = graif.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

graif.desktop: graif.desktop.in
	sed -e 's!@pixmapdir@!$(pixmapdir)!;' < $< > $@

DISTCLEANFILES = $(desktop_DATA)

EXTRA_DIST = graif.desktop.in application-x-graif.png
