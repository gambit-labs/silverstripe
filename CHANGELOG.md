## Changelog

v0.3.0
 - HTTPS support! Just mount a `.crt` and a `.key` file, enable it and you're done
 - HTTP 2.0 support! If you have HTTPS enabled, you may use the much faster HTTP standard.
 - Upgraded to nginx 1.11.2 from 1.6.2
 - Securer than before:
   - A lot of new options added to `/etc/nginx/ssl.conf`
   - It's possible to add a file called `dhparam.pem` to `/certs`. Then nginx will use that for encrypting messages before the TLS handshake takes place.
   - Now protected against SS-2015-013
   - Only index.php, install.php, framework/main.php are allowed to execute on the server
   - `install.php` is removed when `mysite/_config.php` is configured properly in a project.
 - Reduced image size with ~135 MB
 - Now it's possible to patch the official SilverStripe repositories just by dropping a file in `_patches/3.4.0` for instance if you want to patch 3.4.0
 - Switched to the MySQL native driver
 - All unnecessary SilverStripe files (like web.config) are removed
 - Allows overrides in `/etc/nginx/silverstripe.d/*.conf`
 - It's now possible to use another PHP server than the built-in one via the `PHP_SERVER` variable.
 - Includes the latest SilverStripe release: `4.0.0-alpha1`
 - gzip compression enabled by default.
 - Now possible to override the nginx config per-repo, by including `*.nginxconf` files in the root of the source code.
 - Added a new development mode: Readwrite mode.
   - Modifies source-controlled repo and let's you test things live with ease
 - Lots of bugfixes
 - Documentation improvements
 - Performance variables:
   - `NGINX_WORKER_PROCESSES`: How many worker processes nginx should have. Default: 1
   - `NGINX_WORKER_CONNECTIONS`: How many connections one process can handle at the same time: Default: 1024
   - `PHP_MAX_EXECUTION_TIME`: Maximum amount of time PHP is allowed to execute. Default: 300 (seconds)
   - `PHP_MAX_UPLOAD_SIZE`: Maximum upload size in megabytes. Default: 32

v0.2.0
 - Initial release on Github; all basic functionality is there.
