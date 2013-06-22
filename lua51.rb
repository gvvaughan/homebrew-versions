require 'formula'

class Lua51 < Formula
  homepage 'http://www.lua.org/'
  url 'http://www.lua.org/ftp/lua-5.1.5.tar.gz'
  sha1 'b3882111ad02ecc6b972f8c1241647905cb2e3fc'

  fails_with :llvm do
    build 2326
    cause "Lua itself compiles with LLVM, but may fail when other software tries to link."
  end

  option :universal
  option 'with-completion', 'Enables advanced readline support'
  option 'without-sigaction', 'Revert to ANSI signal instead of improved POSIX sigaction'

  def patches
    p = []
    # Be sure to build a dylib, or else runtime modules will pull in another static copy of liblua = crashy
    # See: https://github.com/mxcl/homebrew/pull/5043
    # Also, take care of versioned file suffixes to support parallel installation with other releases
    p << 'https://gist.github.com/gvvaughan/5832455/raw/ad53d564bb0abb68a7cd9f27b4ef82e2bb2bd3ae/lua-5.1-homebrew.diff'
    # sigaction provided by posix signalling power patch from
    # http://lua-users.org/wiki/LuaPowerPatches
    unless build.without? 'sigaction'
      p << 'http://lua-users.org/files/wiki_insecure/power_patches/5.1/sig_catch.patch'
    end
    # completion provided by advanced readline power patch from
    # http://lua-users.org/wiki/LuaPowerPatches
    if build.with? 'completion'
      p << 'http://luajit.org/patches/lua-5.1.4-advanced_readline.patch'
    end
    p
  end

  def install
    ENV.universal_binary if build.universal?

    # Use our CC/CFLAGS to compile.
    inreplace 'src/Makefile' do |s|
      s.remove_make_var! 'CC'
      s.change_make_var! 'CFLAGS', "#{ENV.cflags} $(MYCFLAGS)"
      s.change_make_var! 'MYLDFLAGS', ENV.ldflags
      s.sub! 'MYCFLAGS_VAL', "-fno-common -DLUA_USE_LINUX"
    end

    # Fix path in the config header
    inreplace 'src/luaconf.h', '/usr/local', HOMEBREW_PREFIX

    # Fix paths in the .pc
    inreplace 'etc/lua.pc' do |s|
      s.gsub! "prefix= /usr/local", "prefix=#{HOMEBREW_PREFIX}"
      s.gsub! "INSTALL_MAN= ${prefix}/man/man1", "INSTALL_MAN= ${prefix}/share/man/man1"
    end

    # this ensures that this symlinking for lua starts at lib/lua/5.1 and not
    # below that, thus making luarocks work
    (HOMEBREW_PREFIX/"lib/lua"/version.to_s.split('.')[0..1].join('.')).mkpath

    system "make", "macosx", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"
    system "make", "install", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"

    (lib+"pkgconfig").install 'etc/lua.pc'
  end
end

