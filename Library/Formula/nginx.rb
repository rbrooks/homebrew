require 'formula'

class Nginx < Formula
  homepage 'http://nginx.org/'
  url 'http://nginx.org/download/nginx-1.2.8.tar.gz'
  sha1 'b8c193d841538c3c443d262a2ab815a9ce1faaf6'

  devel do
    url 'http://nginx.org/download/nginx-1.3.16.tar.gz'
    sha1 '773321c9c9c273e9a2da0ddfd07e8af271d09ca7'
  end

  UPLOAD_MODULE_VERSION = '2.2.0'
  UPLOAD_PROGRESS_VERSION = 'v0.9.0'

  head 'svn://svn.nginx.org/nginx/trunk/'

  env :userpaths

  depends_on 'pcre'

  option 'with-passenger', 'Compile with support for Phusion Passenger module'
  option 'with-webdav', 'Compile with support for WebDAV module'
  option 'with-debug', 'Compile with support for debug log'
  option 'with-upload-module', 'Compile with support for Upload and Upload-Progress modules.'

  option 'with-spdy', 'Compile with support for SPDY module' if build.devel?

  skip_clean 'logs'

  # Changes default port to 8080
  def patches
    DATA
  end

  def download_upload_modules
    modules_dir = File.join(prefix, 'modules')
    upload_mod_name = "nginx_upload_module-#{UPLOAD_MODULE_VERSION}"
    progress_mod_name = "masterzen-nginx-upload-progress-module-#{UPLOAD_PROGRESS_VERSION}"
    @upload_mod_dir = File.join(modules_dir, upload_mod_name)
    @progress_mod_dir = File.join(modules_dir, progress_mod_name)

    FileUtils.mkdir_p modules_dir

    `curl http://www.grid.net.ru/nginx/download/#{upload_mod_name}.tar.gz | tar -xzf - && mv nginx_upload_module-* #{@upload_mod_dir}`
    `curl -L https://github.com/masterzen/nginx-upload-progress-module/tarball/#{UPLOAD_PROGRESS_VERSION} | tar -xzf - && mv masterzen-* #{@progress_mod_dir}`
  end

  def passenger_config_args
    passenger_root = `passenger-config --root`.chomp

    if File.directory?(passenger_root)
      return "--add-module=#{passenger_root}/ext/nginx"
    end

    puts "Unable to install nginx with passenger support. The passenger"
    puts "gem must be installed and passenger-config must be in your path"
    puts "in order to continue."
    exit
  end

  def install
    args = ["--prefix=#{prefix}",
            "--with-http_ssl_module",
            "--with-pcre",
            "--with-ipv6",
            "--sbin-path=#{bin}/nginx",
            "--with-cc-opt=-I#{HOMEBREW_PREFIX}/include",
            "--with-ld-opt=-L#{HOMEBREW_PREFIX}/lib",
            "--conf-path=#{etc}/nginx/nginx.conf",
            "--pid-path=#{var}/run/nginx.pid",
            "--lock-path=#{var}/run/nginx.lock",
            "--http-client-body-temp-path=#{var}/run/nginx/client_body_temp",
            "--http-proxy-temp-path=#{var}/run/nginx/proxy_temp",
            "--http-fastcgi-temp-path=#{var}/run/nginx/fastcgi_temp",
            "--http-uwsgi-temp-path=#{var}/run/nginx/uwsgi_temp",
            "--http-scgi-temp-path=#{var}/run/nginx/scgi_temp",
            "--http-log-path=#{var}/log/nginx",
            "--with-http_gzip_static_module"
          ]

    args << passenger_config_args if build.include? 'with-passenger'
    args << "--with-http_dav_module" if build.include? 'with-webdav'
    args << "--with-debug" if build.include? 'with-debug'

    if build.include? 'with-upload-module'
      download_upload_modules

      args << "--add-module=#{@upload_mod_dir}"
      args << "--add-module=#{@progress_mod_dir}"
    end

    if build.devel? or build.head?
      args << "--with-http_spdy_module" if build.include? 'with-spdy'
    end

    if build.head?
      system "./auto/configure", *args
    else
      system "./configure", *args
    end
    system "make"
    system "make install"
    man8.install "objs/nginx.8"
    (var/'run/nginx').mkpath

    # nginx’s docroot is #{prefix}/html, this isn't useful, so we symlink it
    # to #{HOMEBREW_PREFIX}/var/www. The reason we symlink instead of patching
    # is so the user can redirect it easily to something else if they choose.
    prefix.cd do
      dst = HOMEBREW_PREFIX/"var/www"
      if not dst.exist?
        dst.dirname.mkpath
        mv "html", dst
      else
        rm_rf "html"
        dst.mkpath
      end
      Pathname.new("#{prefix}/html").make_relative_symlink(dst)
    end

    # for most of this formula’s life the binary has been placed in sbin
    # and Homebrew used to suggest the user copy the plist for nginx to their
    # ~/Library/LaunchAgents directory. So we need to have a symlink there
    # for such cases
    if (HOMEBREW_CELLAR/'nginx').subdirs.any?{|d| (d/:sbin).directory? }
      sbin.mkpath
      sbin.cd do
        (sbin/'nginx').make_relative_symlink(bin/'nginx')
      end
    end
  end

  def caveats; <<-EOS.undent
    Docroot is: #{HOMEBREW_PREFIX}/var/www

    The default port has been set to 8080 so that nginx can run without sudo.

    If you want to host pages on your local machine to the wider network you
    can change the port to 80 in: #{HOMEBREW_PREFIX}/etc/nginx/nginx.conf

    You will then need to run nginx as root: `sudo nginx`.
    EOS
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_prefix}/bin/nginx</string>
            <string>-g</string>
            <string>daemon off;</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
      </dict>
    </plist>
    EOS
  end
end

__END__
--- a/conf/nginx.conf
+++ b/conf/nginx.conf
@@ -33,7 +33,7 @@
     #gzip  on;

     server {
-        listen       80;
+        listen       8080;
         server_name  localhost;

         #charset koi8-r;
