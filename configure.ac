dnl Process this file with autoconf to produce a configure script.

AC_INIT(graif, 1.1.0, ZXB01226@nifty.com, graif)

AC_CONFIG_SRCDIR(src/main.rb)
AM_INIT_AUTOMAKE

AC_PROG_INSTALL

# check ruby
AC_CHECK_PROG(RUBY, ruby, yes, no)
if test "$RUBY" = "yes"
then
  RUBY_BIN=ruby
fi

if test "x$RUBY_BIN" = "x"
then
  AC_MSG_ERROR("Cannot find Ruby.")
fi

RUBY_FULL_PATH=`which $RUBY_BIN`
AC_SUBST(RUBY_BIN)
AC_SUBST(RUBY_FULL_PATH)

# check Ruby-GTK3
echo -n "checking for Ruby-GTK3... "
if $RUBY_BIN -e 'begin require "gtk3"; rescue Gtk::InitError; 0; end'
then
  echo yes
else
  AC_MSG_ERROR(Cannot find ruby-gnome2.)
fi

AC_CONFIG_FILES([Makefile debian/Makefile desktop/Makefile data/Makefile src/Makefile icons/Makefile plugins/Makefile])
AC_OUTPUT
