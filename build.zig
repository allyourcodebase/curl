const std = @import("std");

const version: std.SemanticVersion = .{ .major = 8, .minor = 13, .patch = 0 };

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("curl", .{});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    const enable_ssl = b.option(bool, "enable-ssl", "Enable SSL support (default: true)") orelse true;
    const use_sectransp = dependentBoolOption(b, "use-sectransp", "Enable Apple OS native SSL/TLS (Secure Transport)", false, enable_ssl, false);
    const use_schannel = dependentBoolOption(b, "use-schannel", "Enable Windows native SSL/TLS (Schannel)", false, enable_ssl, false);
    const use_mbedtls = dependentBoolOption(b, "use-mbedtls", "Enable mbedTLS for SSL/TLS", false, enable_ssl, false);
    const use_bearssl = dependentBoolOption(b, "use-bearssl", "Enable BearSSL for SSL/TLS", false, enable_ssl, false);
    const use_wolfssl = dependentBoolOption(b, "use-wolfssl", "Enable wolfSSL for SSL/TLS", false, enable_ssl, false);
    const use_gnutls = dependentBoolOption(b, "use-gnutls", "Enable GnuTLS for SSL/TLS", false, enable_ssl, false);
    const use_rustls = dependentBoolOption(b, "use-rustls", "Enable Rustls for SSL/TLS", false, enable_ssl, false);
    const openssl_default = !(target.result.os.tag == .windows or use_sectransp or use_schannel or use_mbedtls or use_bearssl or use_wolfssl or use_gnutls or use_rustls);
    const use_openssl = dependentBoolOption(b, "use-openssl", "Enable OpenSSL for SSL/TLS", openssl_default, enable_ssl, false);

    const default_ssl_backend = b.option(enum {
        wolfssl,
        gnutls,
        mbedtls,
        openssl,
        schannel,
        @"secure-transport",
    }, "default-ssl-backend", "Override default TLS backend in MultiSSL builds.");

    // Dependencies
    const use_brotli = b.option(bool, "brotli", "Use brotli (default: false)") orelse false;
    const use_gsasl = b.option(bool, "gsasl", "Use libgsasl (default: false)") orelse false;
    const use_gssapi = b.option(bool, "gssapi", "Use GSSAPI implementation (default: false)") orelse false;
    const use_libpsl = b.option(bool, "libpsl", "Use libpsl (default: true)") orelse true;
    const use_libssh2 = b.option(bool, "libssh2", "Use libssh2 (default: true)") orelse true;
    const use_libssh = b.option(bool, "libssh", "Use libssh (default: false)") orelse false;
    const use_libuv = b.option(bool, "libuv", "Use libuv for event-based tests (default: false)") orelse false;
    const use_wolfssh = b.option(bool, "wolfssh", "Use wolfSSH (default: false)") orelse false;
    const use_zlib = b.option(bool, "zlib", "Use zlib (default: true)") orelse true;
    const use_zstd = b.option(bool, "zstd", "Use zstd (default: false)") orelse false;
    const enable_ares = b.option(bool, "ares", "Enable c-ares support (default: false)") orelse false;
    const use_apple_idn = b.option(bool, "apple-idn", "Use Apple built-in IDN support (default: false)") orelse false;
    const use_libidn2 = b.option(bool, "libidn2", "Use libidn2 for IDN support (default: true)") orelse true;
    const use_librtmp = b.option(bool, "librtmp", "Enable librtmp from rtmpdump (default: false)") orelse false;
    const use_msh3 = b.option(bool, "msh3", "Use msh3/msquic library for HTTP/3 support (default: false)") orelse false;
    const use_nghttp2 = b.option(bool, "nghttp2", "Use nghttp2 library (default: true)") orelse true;
    const use_ngtcp2 = b.option(bool, "ngtcp2", "Use ngtcp2 and nghttp3 libraries for HTTP/3 support (default: false)") orelse false;
    const use_quiche = b.option(bool, "quiche", "Use quiche library for HTTP/3 support (default: false)") orelse false;
    const use_win32_idn = b.option(bool, "win32-idn", "Use WinIDN for IDN support (default: false)") orelse false;
    const use_win32_ldap = b.option(bool, "win32-ldap", "Use Windows LDAP implementation (default: true)") orelse true;

    // Enabling features

    var enable_windows_sspi = b.option(bool, "windows-sspi", "Enable SSPI on Windows (default: use-schannel)") orelse use_schannel;
    const enable_ipv6 = b.option(bool, "enable-ipv6", "Enable IPv6 support (default: true)") orelse true;
    const enable_threaded_resolver = dependentBoolOption(b, "threaded-resolver", "Enable threaded DNS lookup", true, !enable_ares, false);
    const enable_unicode = b.option(bool, "unicode", "Use the Unicode version of the Windows API functions (default: false)") orelse false;
    const enable_unix_sockets = b.option(bool, "unix-sockets", "Enable Unix domain sockets support (default: true)") orelse true;
    const ech = b.option(bool, "ech", "Enable ECH support (default: false)") orelse false;
    var httpsrr = b.option(bool, "httpsrr", "Enable HTTPS RR support (default: false)") orelse false;
    var use_openssl_quic = b.option(bool, "openssl-quic", "Use OpenSSL and nghttp3 libraries for HTTP/3 support (default: false)") orelse false;
    const disable_openssl_auto_load_config = b.option(bool, "disable-openssl-auto-load-config", "Disable automatic loading of OpenSSL configuration (default: false)") orelse false;

    // Disabling features
    var disable_altsvc = b.option(bool, "disable-altsvc", "Disable alt-svc support") orelse false;
    const disable_srp = b.option(bool, "disable-srp", "Disable TLS-SRP support") orelse false;
    const disable_cookies = b.option(bool, "disable-cookies", "Disable cookies support") orelse false;
    const disable_basic_auth = b.option(bool, "disable-basic-auth", "Disable Basic authentication") orelse false;
    const disable_bearer_auth = b.option(bool, "disable-bearer-auth", "Disable Bearer authentication") orelse false;
    const disable_digest_auth = b.option(bool, "disable-digest-auth", "Disable Digest authentication") orelse false;
    const disable_kerberos_auth = b.option(bool, "disable-kerberos-auth", "Disable Kerberos authentication") orelse false;
    const disable_negotiate_auth = b.option(bool, "disable-negotiate-auth", "Disable negotiate authentication") orelse false;
    const disable_aws = b.option(bool, "disable-aws", "Disable aws-sigv4") orelse false;
    var disable_dict = b.option(bool, "disable-dict", "Disable DICT") orelse false;
    const disable_doh = b.option(bool, "disable-doh", "Disable DNS-over-HTTPS") orelse false;
    var disable_file = b.option(bool, "disable-file", "Disable FILE") orelse false;
    var disable_ftp = b.option(bool, "disable-ftp", "Disable FTP") orelse false;
    const disable_getoptions = b.option(bool, "disable-getoptions", "Disable curl_easy_options API for existing options to curl_easy_setopt") orelse false;
    var disable_gopher = b.option(bool, "disable-gopher", "Disable Gopher") orelse false;
    const disable_headers_api = b.option(bool, "disable-headers-api", "Disable headers-api support") orelse false;
    var disable_hsts = b.option(bool, "disable_hsts", "Disable HSTS support") orelse false;
    const disable_http = b.option(bool, "disable-http", "Disable HTTP") orelse false;
    const disable_http_auth = b.option(bool, "disable-http-auth", "Disable all HTTP authentication methods") orelse false;
    var disable_imap = b.option(bool, "disable-imap", "Disable IMAP") orelse false;
    var disable_ldap = b.option(bool, "disable-ldap", "Disable LDAP") orelse false;
    var disable_ldaps = b.option(bool, "disable-ldaps", "Disable LDAPS") orelse disable_ldap;
    const disable_libcurl_option = b.option(bool, "disable-libcurl-option", "Disable --libcurl option from the curl tool") orelse false;
    const disable_mime = b.option(bool, "disable-mime", "Disable MIME support") orelse false;
    const disable_form_api = dependentBoolOption(b, "disable-form-api", "Disable form-api", false, !disable_mime, true);
    var disable_mqtt = b.option(bool, "disable-mqtt", "Disable MQTT") orelse false;
    const disable_bindlocal = b.option(bool, "disable-bindlocal", "Disable local binding support") orelse false;
    const disable_netrc = b.option(bool, "disable-netrc", "Disable netrc parser") orelse false;
    const disable_ntlm = b.option(bool, "disable-ntlm", "Disable NTLM support") orelse false;
    const disable_parsedate = b.option(bool, "disable-parsedate", "Disable date parsing") orelse false;
    var disable_pop3 = b.option(bool, "disable-pop3", "Disable POP3") orelse false;
    const disable_progress_meter = b.option(bool, "disable-progress-meter", "Disable built-in progress meter") orelse false;
    const disable_proxy = b.option(bool, "disable_proxy", "Disable proxy support") orelse false;
    var disable_ipfs = b.option(bool, "disable-ipfs", "Disable IPFS") orelse false;
    var disable_rtsp = b.option(bool, "disable-rtsp", "Disable RTSP") orelse false;
    const disable_sha512_256 = b.option(bool, "disable-sha512-256", "Disable SHA-512/256 hash algorithm") orelse false;
    const disable_shuffle_dns = b.option(bool, "disable-shuffle-dns", "Disable shuffle DNS feature") orelse false;
    var disable_smb = b.option(bool, "disable-smb", "Disable SMB") orelse false;
    var disable_smtp = b.option(bool, "disable-smtp", "Disable SMTP") orelse false;
    const disable_socketpair = b.option(bool, "disable-socketpair", "Disable use of socketpair for curl_multi_poll") orelse false;
    const disable_websockets = b.option(bool, "disable-websockets", "Disable WebSocket") orelse false;
    var disable_telnet = b.option(bool, "disable-telnet", "Disable Telnet") orelse false;
    var disable_tftp = b.option(bool, "disable-tftp", "Disable TFTP") orelse false;
    const disable_verbose_strings = b.option(bool, "disable-verbose-strings", "Disable verbose strings") orelse false;
    const http_only = b.option(bool, "http-only", "Disable all protocols except HTTP (This overrides all disable-* options)") orelse false;

    // CA bundle options

    var ca_bundle = b.option([]const u8, "ca-bundle", "Path to the CA bundle. Set 'none' to disable or 'auto' for auto-detection. Defaults to 'auto'.") orelse "auto";
    const ca_fallback = b.option(bool, "ca-fallback", "Use built-in CA store of TLS backend. Defaults to OFF") orelse false;
    var ca_path = b.option([]const u8, "ca-path", "Location of default CA path. Set 'none' to disable or 'auto' for auto-detection. Defaults to 'auto'.") orelse "auto";
    const ca_embed = b.option([]const u8, "ca-embed", "Path to the CA bundle to embed in the curl tool");

    const disable_ca_search = b.option(bool, "disable-ca-search", "Disable unsafe CA bundle search in PATH on Windows") orelse false;
    const ca_search_safe = b.option(bool, "ca-search-safe", "Enable safe CA bundle search (within the curl tool directory) on Windows") orelse false;

    const use_ssls_export = b.option(bool, "ssls-export", "Enable experimental SSL session import/export") orelse false;

    const hidden_symbols = b.option(bool, "hidden-symbols", "Hide libcurl internal symbols (=hide all symbols that are not officially external)") orelse true;

    const c_flags: []const []const u8 = if (hidden_symbols) &.{"-fvisibility=hidden"} else &.{};

    const curl = b.addLibrary(.{
        .linkage = linkage,
        .name = "libcurl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .strip = strip,
            .pic = pic,
        }),
    });
    curl.installHeadersDirectory(upstream.path("include"), ".", .{});
    curl.root_module.addCMacro("BUILDING_LIBCURL", "1");
    if (linkage == .static) curl.root_module.addCMacro("CURL_STATICLIB", "1");
    if (hidden_symbols) curl.root_module.addCMacro("CURL_HIDDEN_SYMBOLS", "1");
    curl.root_module.addCMacro("HAVE_CONFIG_H", "1");
    curl.root_module.addIncludePath(upstream.path("include"));
    curl.root_module.addIncludePath(upstream.path("lib"));
    curl.root_module.addCSourceFiles(.{ .root = upstream.path("lib"), .files = sources, .flags = c_flags });
    b.installArtifact(curl);

    const exe = b.addExecutable(.{
        .name = "curl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .strip = strip,
            .pic = pic,
        }),
    });
    b.installArtifact(exe);
    exe.root_module.linkLibrary(curl);
    exe.root_module.addCMacro("HAVE_CONFIG_H", "1");
    if (linkage == .static) exe.root_module.addCMacro("CURL_STATICLIB", "1");
    exe.root_module.addIncludePath(upstream.path("include"));
    exe.root_module.addIncludePath(upstream.path("lib"));
    exe.root_module.addIncludePath(upstream.path("src"));
    exe.root_module.addCSourceFiles(.{ .root = upstream.path("src"), .files = exe_sources, .flags = c_flags });
    exe.root_module.addCSourceFiles(.{ .root = upstream.path("lib"), .files = tool_lib_sources, .flags = c_flags });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run curl");
    run_step.dependOn(&run_cmd.step);

    if (enable_unicode and target.result.isMinGW()) {
        // Zig should take care of setting `-municode` (unverified)
    }

    if (enable_unicode) {
        curl.root_module.addCMacro("UNICODE", "1");
        curl.root_module.addCMacro("_UNICODE", "1");
        // Zig should take care of setting `-municode` (unverified)
        curl.root_module.addCMacro("WIN32_LEAN_AND_MEAN", "1");
        // Zig should take care of defining `_WIN32_WINNT` (unverified)
    }

    if (target.result.os.tag == .linux) {
        curl.root_module.addCMacro("_GNU_SOURCE", "1"); // Required for sendmmsg()
    }

    if (enable_ares) {
        // https://github.com/c-ares/c-ares
        curl.root_module.linkSystemLibrary("cares", .{});
    }

    if (disable_http) {
        disable_ipfs = true;
        disable_rtsp = true;
        disable_altsvc = true;
        disable_hsts = true;
    }

    if (http_only) {
        disable_dict = true;
        disable_file = true;
        disable_ftp = true;
        disable_gopher = true;
        disable_imap = true;
        disable_ldap = true;
        disable_ldaps = true;
        disable_mqtt = true;
        disable_pop3 = true;
        disable_ipfs = true;
        disable_rtsp = true;
        disable_smb = true;
        disable_smtp = true;
        disable_telnet = true;
        disable_tftp = true;
    }

    if (enable_threaded_resolver) {
        curl.root_module.addCMacro("HAVE_PTHREAD_H", "1");
        curl.root_module.linkSystemLibrary("pthread", .{});
    }

    var use_core_foundation_and_core_services = false;

    if (enable_ipv6 and target.result.os.tag != .windows) {
        // TODO HAVE_SOCKADDR_IN6_SIN6_SCOPE_ID
        // TODO HAVE_SOCKADDR_IN6_SIN6_ADDR

        if (target.result.os.tag.isDarwin() and !enable_ares) {
            use_core_foundation_and_core_services = true;
            curl.root_module.linkFramework("SystemConfiguration", .{});
        }
    }

    if (target.result.os.tag == .aix) {
        curl.root_module.addCMacro("_ALL_SOURCE", "1");
    }
    if (target.result.os.tag == .haiku) {
        curl.root_module.linkSystemLibrary("network", .{});
    }

    if (target.result.os.tag != .windows and !target.result.os.tag.isDarwin()) {
        // TODO curl.root_module.linkSystemLibrary("socket", .{});
    }

    if (target.result.os.tag == .windows) {
        curl.root_module.linkSystemLibrary("ws2_32", .{});
        curl.root_module.linkSystemLibrary("bcrypt", .{});

        if (use_schannel) { // Assumes `NOT WINDOWS_STORE`
            curl.root_module.linkSystemLibrary("advapi32", .{});
            curl.root_module.linkSystemLibrary("crypt32", .{});
        }
    }

    if (use_openssl_quic and !use_openssl) {
        std.log.warn("OpenSSL QUIC has been requested, but without enabling OpenSSL. Will not enable QUIC.", .{});
        use_openssl_quic = false;
    }
    const enabled_ssl_options_count =
        @as(usize, @intFromBool(use_schannel)) +
        @as(usize, @intFromBool(use_sectransp)) +
        @as(usize, @intFromBool(use_openssl)) +
        @as(usize, @intFromBool(use_mbedtls)) +
        @as(usize, @intFromBool(use_bearssl)) +
        @as(usize, @intFromBool(use_wolfssl)) +
        @as(usize, @intFromBool(use_gnutls)) +
        @as(usize, @intFromBool(use_rustls));

    const with_multi_sll = enabled_ssl_options_count > 1;
    if (enabled_ssl_options_count == 0) {
        disable_hsts = true;
    }

    var have_boring_ssl = false; // TODO
    _ = &have_boring_ssl;
    var have_awslc = false; // TODO
    _ = &have_awslc;

    if (default_ssl_backend) |ssl_backend| {
        const default_ssl_backend_enabled = switch (ssl_backend) {
            .wolfssl => use_wolfssl,
            .gnutls => use_gnutls,
            .mbedtls => use_mbedtls,
            .openssl => use_openssl,
            .schannel => use_schannel,
            .@"secure-transport" => use_sectransp,
        };
        if (!default_ssl_backend_enabled) {
            std.debug.panic("default-ssl-backend '{s}' not enabled.", .{@tagName(ssl_backend)});
        }
    }

    if (use_schannel) {
        enable_windows_sspi = true;
    }
    if (use_sectransp) {
        use_core_foundation_and_core_services = true;
        curl.root_module.linkFramework("Security", .{});
    }

    if (use_openssl) {
        // TODO BoringSSL, AWS-LC, LibreSSL, and quictls
        if (b.systemIntegrationOption("openssl", .{})) {
            curl.root_module.linkSystemLibrary("openssl", .{});
        } else {
            if (b.lazyDependency("openssl", .{
                .target = target,
                .optimize = optimize,
            })) |dependency| {
                curl.root_module.linkLibrary(dependency.artifact("openssl"));
            }
        }
        // TODO -DOPENSSL_SUPPRESS_DEPRECATED
        // TODO HAVE_BORINGSSL
        // TODO HAVE_AWSLC
    }
    if (use_mbedtls) {
        if (b.systemIntegrationOption("mbedtls", .{})) {
            curl.root_module.linkSystemLibrary("mbedtls", .{});
        } else {
            if (b.lazyDependency("mbedtls", .{
                .target = target,
                .optimize = optimize,
            })) |dependency| {
                curl.root_module.linkLibrary(dependency.artifact("mbedtls"));
            }
        }
    }
    if (use_bearssl) {
        // TODO
        curl.linkSystemLibrary("bearssl");
    }
    if (use_wolfssl) {
        // TODO
        curl.root_module.linkSystemLibrary("wolfssl", .{});
    }
    if (use_gnutls) {
        // TODO
        curl.root_module.linkSystemLibrary("gnutls", .{});
        curl.root_module.linkSystemLibrary("nettle", .{});
    }
    if (use_rustls) {
        // TODO
        curl.root_module.linkSystemLibrary("rustls", .{});
    }

    if (use_core_foundation_and_core_services) {
        curl.root_module.linkFramework("CoreFoundation", .{});
        curl.root_module.linkFramework("CoreServices", .{});
    }

    if (use_zlib) {
        if (b.systemIntegrationOption("zlib", .{})) {
            curl.root_module.linkSystemLibrary("z", .{});
        } else {
            if (b.lazyDependency("zlib", .{
                .target = target,
                .optimize = optimize,
            })) |dependency| {
                curl.root_module.linkLibrary(dependency.artifact("z"));
            }
        }
    }

    if (use_brotli) {
        if (b.systemIntegrationOption("brotli", .{})) {
            curl.root_module.linkSystemLibrary("brotli", .{});
        } else {
            if (b.lazyDependency("brotli", .{
                .target = target,
                .optimize = optimize,
            })) |dependency| {
                curl.root_module.linkLibrary(dependency.artifact("brotli"));
            }
        }
    }

    if (use_zstd) {
        if (b.systemIntegrationOption("zstd", .{})) {
            curl.root_module.linkSystemLibrary("zstd", .{});
        } else {
            if (b.lazyDependency("zstd", .{
                .target = target,
                .optimize = optimize,
            })) |dependency| {
                curl.root_module.linkLibrary(dependency.artifact("zstd"));
            }
        }
    }

    if (use_wolfssl) {
        // TODO HAVE_WOLFSSL_DES_ECB_ENCRYPT
        // TODO HAVE_WOLFSSL_BIO
        // TODO HAVE_WOLFSSL_FULL_BIO
    }

    if (use_openssl or use_wolfssl) {
        // TODO HAVE_SSL_SET0_WBIO
        if (!disable_srp) {
            // TODO HAVE_OPENSSL_SRP
        }
    }

    if (ech) {
        if (use_openssl or use_wolfssl or use_rustls) {
            if (use_wolfssl) {
                // TODO HAVE_WOLFSSL_CTX_GENERATEECHCONFIG
            }
            if (use_openssl) {
                // TODO HAVE_SSL_SET1_ECH_CONFIG_LIST
            }
            httpsrr = true;
        } else {
            std.debug.panic("ECH requires ECH-enablded OpenSSL, BoringSSL, AWS-LC or wolfSSL", .{});
        }
    }

    if (use_nghttp2) {
        curl.root_module.linkSystemLibrary("nghttp2", .{});
    }

    if (use_ngtcp2) {
        if (use_openssl or use_wolfssl) {
            if (use_wolfssl) {
                // ngtcp2_crypto_wolfssl
            } else if (have_boring_ssl or have_awslc) {
                // ngtcp2_crypto_boringssl
            } else {
                // ngtcp2_crypto_quictls
            }
        } else if (use_gnutls) {
            // ngtcp2_crypto_gnutls
        } else {
            std.debug.panic("ngtcp2 requires OpenSSL, wolfSSL or GnuTLS", .{});
        }
        // ngtcp2
        // nghttp3
    }

    if (use_quiche) {
        if (use_ngtcp2) {
            std.debug.panic("Only one HTTP/3 backend can be selected", .{});
        }
        // Quiche
        if (!have_boring_ssl) {
            std.debug.panic("quiche requires BoringSSL", .{});
        }
        // TODO HAVE_QUICHE_CONN_SET_QLOG_FD
    }

    if (use_msh3) {
        if (use_ngtcp2 or use_quiche) {
            std.debug.panic("Only one HTTP/3 backend can be selected", .{});
        }
        if (target.result.os.tag != .windows) {
            if (!use_openssl) {
                std.debug.panic("msh3/msquic requires OpenSSL fork with QUIC API", .{});
            }
        }
        // MSH3
    }

    if (use_openssl_quic) {
        if (use_ngtcp2 or use_quiche or use_msh3) {
            std.debug.panic("Only one HTTP/3 backend can be selected", .{});
        }
        curl.root_module.linkSystemLibrary("nghttp3", .{});
    }

    if (with_multi_sll and (use_ngtcp2 or use_quiche or use_msh3 or use_openssl_quic)) {
        std.debug.panic("MultiSSL cannot be enabled with HTTP/3 and vice versa.", .{});
    }

    // if (!disable_srp and (have_gnutls_srp and have_openssl_srp)) {
    //     // set(USE_TLS_SRP 1)
    // }

    var have_lber_h = false;
    var have_ldap_ssl = false;

    if (!disable_ldap) {
        if (target.result.os.tag == .windows and use_win32_ldap) {
            curl.root_module.linkSystemLibrary("wldap32", .{});
            if (disable_ldaps) {
                have_ldap_ssl = true;
            }
        } else {
            curl.root_module.linkSystemLibrary("ldap", .{});
            have_lber_h = true;
            // TODO HAVE_LDAP_URL_PARSE
            // TODO HAVE_LDAP_INIT_FD
            // TODO HAVE_LDAP_SSL_H
            if (disable_ldaps) {
                have_ldap_ssl = true;
            }
        }
    }

    if (disable_ldap and !disable_ldaps) {
        // std.log.info("LDAP needs to be enabled to support LDAPS", .{});
        disable_ldaps = true;
    }

    if (use_win32_idn and target.result.os.tag == .windows) {
        curl.root_module.linkSystemLibrary("normaliz", .{});
    }

    if (use_apple_idn and target.result.os.tag.isDarwin()) {
        // TODO symbol check
        curl.root_module.linkSystemLibrary("icucore", .{});
        curl.root_module.linkSystemLibrary("iconv", .{});
    }

    if (use_libidn2 and !use_apple_idn and !use_win32_idn) {
        curl.root_module.linkSystemLibrary("idn2", .{});
    }

    if (use_libpsl) {
        curl.root_module.linkSystemLibrary("psl", .{});
    }

    if (use_libssh2) {
        curl.root_module.linkSystemLibrary("ssh2", .{});
    }

    if (use_libssh and !use_libssh2) {
        curl.root_module.linkSystemLibrary("ssh", .{});
    }

    if (use_wolfssh and !use_libssh2 and !use_libssh) {
        if (use_wolfssl) {
            curl.root_module.linkSystemLibrary("wolfssh", .{});
        } else {
            std.log.warn("wolfSSH requires wolfSSL. Skipping.", .{});
        }
    }

    if (use_gsasl) {
        curl.root_module.linkSystemLibrary("gsasl", .{});
    }

    if (use_gssapi) {
        @panic("TODO: add support for gssapi");
    }

    if (use_libuv) {
        // TODO requires ENABLE_DEBUG
        curl.root_module.linkSystemLibrary("uv", .{});
    }

    if (use_librtmp) {
        curl.linkSystemLibrary("rtmp");
        if (target.result.os.tag == .windows) curl.root_module.linkSystemLibrary("winmm", .{});
    }

    //
    // CA handling
    //

    const ca_bundle_autodetect = std.mem.eql(u8, ca_bundle, "auto") and target.query.isNative() and target.result.os.tag != .windows;
    var ca_bundle_set = !std.mem.eql(u8, ca_bundle, "none") and !std.mem.eql(u8, ca_bundle, "auto");

    const ca_path_autodetect = std.mem.eql(u8, ca_path, "auto") and target.query.isNative() and target.result.os.tag != .windows;
    var ca_path_set = !std.mem.eql(u8, ca_path, "none") and !std.mem.eql(u8, ca_path, "auto");

    if (ca_bundle_set and ca_path_autodetect) {
        // Skip auto-detection of unset CA path because CA bundle is set explicitly
    } else if (ca_path_set and ca_bundle_autodetect) {
        // Skip auto-detection of unset CA bundle because CA path is set explicitly
    } else if (ca_bundle_autodetect or ca_path_autodetect) {
        // First try auto-detecting a CA bundle, then a CA path

        if (ca_bundle_autodetect) {
            for ([_][]const u8{
                "/etc/ssl/certs/ca-certificates.crt",
                "/etc/pki/tls/certs/ca-bundle.crt",
                "/usr/share/ssl/certs/ca-bundle.crt",
                "/usr/local/share/certs/ca-root-nss.crt",
                "/etc/ssl/cert.pem",
            }) |search_ca_bundle_path| {
                std.fs.accessAbsolute(search_ca_bundle_path, .{}) catch continue;
                // std.log.info("Found CA bundle: {s}", .{search_ca_bundle_path});
                ca_bundle = search_ca_bundle_path;
                ca_bundle_set = true;
                break;
            }
        }

        if (ca_path_autodetect and !ca_path_set) {
            const search_ca_path: []const u8 = "/etc/ssl/certs";
            const ca_dir = try std.fs.openDirAbsolute(search_ca_path, .{ .iterate = true });
            var ca_dir_it = ca_dir.iterate();
            while (try ca_dir_it.next()) |item| {
                if (item.name.len != 10) continue;
                if (!std.mem.endsWith(u8, item.name, ".0")) continue;
                for (item.name[0..8]) |c| {
                    if (!std.ascii.isDigit(c)) continue;
                    if (!std.ascii.isLower(c)) continue;
                }
                // std.log.info("Found CA path: {s}", .{search_ca_path});
                ca_path = search_ca_path;
                ca_path_set = true;
                break;
            }
        }

        var ca_embed_set = false;
        if (ca_embed) |embed_path| {
            if (std.fs.accessAbsolute(embed_path, .{})) |_| {
                ca_embed_set = true;
                // std.log.info("Found CA bundle to embed: {s}", .{embed_path});
            } else |err| {
                std.debug.panic("CA bundle to embed is missing: {s} ({})", .{ embed_path, err });
            }
        }
    }

    const curl_config = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("lib/curl_config.h.cmake") },
        .include_path = "curl_config.h",
    }, .{
        .CURL_CA_BUNDLE = if (std.mem.eql(u8, ca_bundle, "auto")) null else ca_bundle,
        .CURL_CA_FALLBACK = ca_fallback,
        .CURL_CA_PATH = if (std.mem.eql(u8, ca_path, "auto")) null else ca_path,
        .CURL_DEFAULT_SSL_BACKEND = if (default_ssl_backend) |backend| @tagName(backend) else null,
        .CURL_DISABLE_ALTSVC = disable_altsvc,
        .CURL_DISABLE_COOKIES = disable_cookies,
        .CURL_DISABLE_BASIC_AUTH = disable_basic_auth,
        .CURL_DISABLE_BEARER_AUTH = disable_bearer_auth,
        .CURL_DISABLE_DIGEST_AUTH = disable_digest_auth,
        .CURL_DISABLE_KERBEROS_AUTH = disable_kerberos_auth,
        .CURL_DISABLE_NEGOTIATE_AUTH = disable_negotiate_auth,
        .CURL_DISABLE_AWS = disable_aws,
        .CURL_DISABLE_DICT = disable_dict,
        .CURL_DISABLE_DOH = disable_doh,
        .CURL_DISABLE_FILE = disable_file,
        .CURL_DISABLE_FORM_API = disable_form_api,
        .CURL_DISABLE_FTP = disable_ftp,
        .CURL_DISABLE_GETOPTIONS = disable_getoptions,
        .CURL_DISABLE_GOPHER = disable_gopher,
        .CURL_DISABLE_HEADERS_API = disable_headers_api,
        .CURL_DISABLE_HSTS = disable_hsts,
        .CURL_DISABLE_HTTP = disable_http,
        .CURL_DISABLE_HTTP_AUTH = disable_http_auth,
        .CURL_DISABLE_IMAP = disable_imap,
        .CURL_DISABLE_LDAP = disable_ldap,
        .CURL_DISABLE_LDAPS = disable_ldaps,
        .CURL_DISABLE_LIBCURL_OPTION = disable_libcurl_option,
        .CURL_DISABLE_MIME = disable_mime,
        .CURL_DISABLE_BINDLOCAL = disable_bindlocal,
        .CURL_DISABLE_MQTT = disable_mqtt,
        .CURL_DISABLE_NETRC = disable_netrc,
        .CURL_DISABLE_NTLM = disable_ntlm,
        .CURL_DISABLE_PARSEDATE = disable_parsedate,
        .CURL_DISABLE_POP3 = disable_pop3,
        .CURL_DISABLE_PROGRESS_METER = disable_progress_meter,
        .CURL_DISABLE_PROXY = disable_proxy,
        .CURL_DISABLE_IPFS = disable_ipfs,
        .CURL_DISABLE_RTSP = disable_rtsp,
        .CURL_DISABLE_SHA512_256 = disable_sha512_256,
        .CURL_DISABLE_SHUFFLE_DNS = disable_shuffle_dns,
        .CURL_DISABLE_SMB = disable_smb,
        .CURL_DISABLE_SMTP = disable_smtp,
        .CURL_DISABLE_WEBSOCKETS = disable_websockets,
        .CURL_DISABLE_SOCKETPAIR = disable_socketpair,
        .CURL_DISABLE_TELNET = disable_telnet,
        .CURL_DISABLE_TFTP = disable_tftp,
        .CURL_DISABLE_VERBOSE_STRINGS = disable_verbose_strings,
        .CURL_DISABLE_CA_SEARCH = disable_ca_search,
        .CURL_CA_SEARCH_SAFE = ca_search_safe,
        .CURL_EXTERN_SYMBOL = if (hidden_symbols) "__attribute__((__visibility__(\"default\")))" else null,
        .USE_WIN32_CRYPTO = target.result.os.tag == .windows, // Assumes 'NOT WINDOWS_STORE'
        .USE_WIN32_LDAP = target.result.os.tag == .windows and use_win32_ldap and !disable_ldap, // Assumes 'NOT WINDOWS_STORE'
        .USE_IPV6 = enable_ipv6,
        .HAVE_ALARM = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_ARC4RANDOM = switch (target.result.os.tag) {
            .dragonfly,
            .netbsd,
            .freebsd,
            .solaris,
            .openbsd,
            .macos,
            .ios,
            .tvos,
            .watchos,
            .visionos,
            .wasi,
            => true,
            .linux => target.result.abi.isGnu() and target.result.os.isAtLeast(.linux, .{ .major = 2, .minor = 36, .patch = 0 }) orelse false,
            else => false,
        },
        .HAVE_ARPA_INET_H = target.result.os.tag != .windows,
        .HAVE_ATOMIC = true,
        .HAVE_FNMATCH = target.result.os.tag != .windows,
        .HAVE_BASENAME = true,
        .HAVE_BOOL_T = true,
        .HAVE_BUILTIN_AVAILABLE = null,
        .HAVE_CLOCK_GETTIME_MONOTONIC = target.result.os.tag != .windows,
        .HAVE_CLOCK_GETTIME_MONOTONIC_RAW = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_CLOSESOCKET = target.result.os.tag == .windows,
        .HAVE_CLOSESOCKET_CAMEL = null,
        .HAVE_DIRENT_H = true,
        .HAVE_OPENDIR = true,
        .HAVE_FCNTL = target.result.os.tag != .windows,
        .HAVE_FCNTL_H = true,
        .HAVE_FCNTL_O_NONBLOCK = target.result.os.tag != .windows,
        .HAVE_FREEADDRINFO = target.result.os.tag != .wasi,
        .HAVE_FSEEKO = target.result.os.tag != .windows,
        .HAVE_DECL_FSEEKO = target.result.os.tag != .windows,
        .HAVE_FTRUNCATE = true,
        .HAVE_GETADDRINFO = target.result.os.tag != .wasi,
        .HAVE_GETADDRINFO_THREADSAFE = target.result.os.tag != .wasi,
        .HAVE_GETEUID = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETPPID = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETHOSTBYNAME_R = target.result.os.tag != .windows and !target.result.os.tag.isDarwin() and target.result.os.tag != .wasi,
        .HAVE_GETHOSTBYNAME_R_3 = null,
        .HAVE_GETHOSTBYNAME_R_5 = null,
        .HAVE_GETHOSTBYNAME_R_6 = target.result.os.tag != .windows and !target.result.os.tag.isDarwin() and target.result.os.tag != .wasi,
        .HAVE_GETHOSTNAME = target.result.os.tag != .wasi,
        .HAVE_GETIFADDRS = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETPASS_R = null,
        .HAVE_GETPEERNAME = target.result.os.tag != .wasi,
        .HAVE_GETSOCKNAME = target.result.os.tag != .wasi,
        .HAVE_IF_NAMETOINDEX = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETPWUID = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETPWUID_R = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETRLIMIT = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_GETTIMEOFDAY = true,
        .HAVE_GLIBC_STRERROR_R = target.result.isGnuLibC(),
        .HAVE_GMTIME_R = target.result.os.tag != .windows,
        .HAVE_GSSAPI = null,
        .HAVE_GSSAPI_GSSAPI_GENERIC_H = null,
        .HAVE_GSSAPI_GSSAPI_H = null,
        .HAVE_GSSGNU = null,
        .HAVE_IFADDRS_H = target.result.os.tag != .windows,
        .HAVE_INET_NTOP = target.result.os.tag != .windows,
        .HAVE_INET_PTON = target.result.os.tag != .windows,
        .HAVE_SA_FAMILY_T = target.result.os.tag != .windows,
        .HAVE_ADDRESS_FAMILY = target.result.os.tag == .windows,
        .HAVE_IOCTLSOCKET = target.result.os.tag == .windows,
        .HAVE_IOCTLSOCKET_CAMEL = null,
        .HAVE_IOCTLSOCKET_CAMEL_FIONBIO = null,
        .HAVE_IOCTLSOCKET_FIONBIO = target.result.os.tag == .windows,
        .HAVE_IOCTL_FIONBIO = target.result.os.tag != .windows,
        .HAVE_IOCTL_SIOCGIFADDR = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_IO_H = target.result.os.tag == .windows,
        .HAVE_LBER_H = have_lber_h,
        .HAVE_LDAP_SSL = have_ldap_ssl,
        .HAVE_LDAP_SSL_H = null,
        .HAVE_LDAP_URL_PARSE = null,
        .HAVE_LIBGEN_H = true,
        .HAVE_LIBIDN2 = use_libidn2 and !use_apple_idn and !use_win32_idn,
        .HAVE_IDN2_H = use_libidn2 and !use_apple_idn and !use_win32_idn,
        .HAVE_LIBZ = use_zlib,
        .HAVE_BROTLI = use_brotli,
        .HAVE_ZSTD = use_zstd,
        .HAVE_LOCALE_H = true,
        .HAVE_LONGLONG = true,
        .HAVE_SUSECONDS_T = target.result.os.tag != .windows,
        .HAVE_MSG_NOSIGNAL = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_NETDB_H = target.result.os.tag != .windows,
        .HAVE_NETINET_IN_H = target.result.os.tag != .windows,
        .HAVE_NETINET_IN6_H = null,
        .HAVE_NETINET_TCP_H = target.result.os.tag != .windows,
        .HAVE_NETINET_UDP_H = target.result.os.tag != .windows,
        .HAVE_LINUX_TCP_H = target.result.os.tag == .linux,
        .HAVE_NET_IF_H = target.result.os.tag != .windows,
        .HAVE_OLD_GSSMIT = null,
        .HAVE_PIPE = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_EVENTFD = switch (target.result.os.tag) {
            .windows, .wasi => false,
            .linux => if (target.result.isMuslLibC())
                true
            else
                target.result.os.isAtLeast(.linux, .{ .major = 2, .minor = 8, .patch = 0 }),
            else => !target.result.os.tag.isDarwin(),
        },
        .HAVE_POLL = target.result.os.tag != .windows,
        .HAVE_POLL_H = target.result.os.tag != .windows,
        .HAVE_POSIX_STRERROR_R = switch (target.result.os.tag) {
            .windows => false,
            .linux => target.result.isMuslLibC(),
            else => true,
        },
        .HAVE_PWD_H = target.result.os.tag != .windows,
        .HAVE_SSL_SET0_WBIO = null, // TODO
        .HAVE_RECV = true,
        .HAVE_SELECT = true,
        .HAVE_SCHED_YIELD = target.result.os.tag != .windows,
        .HAVE_SEND = true,
        .HAVE_SENDMSG = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_SENDMMSG = switch (target.result.os.tag) {
            .windows, .wasi => false,
            .linux => if (target.result.isMuslLibC())
                true
            else
                target.result.os.isAtLeast(.linux, .{ .major = 2, .minor = 14, .patch = 0 }),
            else => !target.result.os.tag.isDarwin(),
        },
        .HAVE_FSETXATTR = target.result.os.tag != .windows and !target.result.os.tag.isDarwin() and target.result.os.tag != .wasi,
        .HAVE_FSETXATTR_5 = target.result.os.tag != .windows and !target.result.os.tag.isDarwin() and target.result.os.tag != .wasi,
        .HAVE_FSETXATTR_6 = null,
        .HAVE_SETLOCALE = true,
        .HAVE_SETMODE = target.result.os.tag == .windows or target.result.os.tag.isDarwin(),
        .HAVE__SETMODE = target.result.os.tag == .windows,
        .HAVE_SETRLIMIT = target.result.os.tag != .wasi,
        .HAVE_SETSOCKOPT_SO_NONBLOCK = null,
        .HAVE_SIGACTION = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_SIGINTERRUPT = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_SIGNAL = target.result.os.tag != .wasi,
        .HAVE_SIGSETJMP = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_SNPRINTF = true,
        .HAVE_SOCKADDR_IN6_SIN6_SCOPE_ID = true, // TODO
        .HAVE_SOCKET = target.result.os.tag != .wasi,
        .HAVE_PROTO_BSDSOCKET_H = null,
        .HAVE_SOCKETPAIR = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_STDATOMIC_H = true,
        .HAVE_STDBOOL_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STRCASECMP = target.result.os.tag != .windows,
        .HAVE_STRCMPI = null,
        .HAVE_STRDUP = true,
        .HAVE_STRERROR_R = target.result.os.tag != .windows,
        .HAVE_STRICMP = null,
        .HAVE_STRINGS_H = true,
        .HAVE_STROPTS_H = target.result.isMuslLibC(),
        .HAVE_MEMRCHR = target.result.os.tag != .windows and !target.result.os.tag.isDarwin() and target.result.os.tag != .wasi,
        .HAVE_STRUCT_SOCKADDR_STORAGE = true,
        .HAVE_STRUCT_TIMEVAL = true,
        .HAVE_SYS_EVENTFD_H = target.result.os.tag != .windows and !target.result.os.tag.isDarwin(),
        .HAVE_SYS_FILIO_H = target.result.os.tag.isDarwin(),
        .HAVE_SYS_IOCTL_H = target.result.os.tag != .windows,
        .HAVE_SYS_PARAM_H = true,
        .HAVE_SYS_POLL_H = target.result.os.tag != .windows,
        .HAVE_SYS_RESOURCE_H = target.result.os.tag != .windows and target.result.os.tag != .wasi,
        .HAVE_SYS_SELECT_H = target.result.os.tag != .windows,
        .HAVE_SYS_SOCKET_H = target.result.os.tag != .windows,
        .HAVE_SYS_SOCKIO_H = target.result.os.tag.isDarwin(),
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TIME_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_SYS_UN_H = target.result.os.tag != .windows,
        .HAVE_SYS_UTIME_H = target.result.os.tag == .windows,
        .HAVE_TERMIOS_H = target.result.os.tag != .windows,
        .HAVE_TERMIO_H = target.result.isGnuLibC(),
        .HAVE_UNISTD_H = true,
        .HAVE_UTIME = true,
        .HAVE_UTIMES = target.result.os.tag != .windows,
        .HAVE_UTIME_H = true,
        .HAVE_WRITABLE_ARGV = target.result.os.tag != .windows,
        .HAVE_TIME_T_UNSIGNED = null,
        .NEED_REENTRANT = null,
        .CURL_OS = b.fmt("\"{s}\"", .{target.result.zigTriple(b.allocator) catch @panic("OOM")}),
        .SIZEOF_INT_CODE = b.fmt("#define SIZEOF_INT {d}", .{target.result.cTypeByteSize(.int)}),
        .SIZEOF_LONG_CODE = b.fmt("#define SIZEOF_LONG {d}", .{target.result.cTypeByteSize(.long)}),
        .SIZEOF_LONG_LONG_CODE = b.fmt("#define SIZEOF_LONG_LONG {d}", .{target.result.cTypeByteSize(.longlong)}),
        .SIZEOF_OFF_T_CODE = b.fmt("#define SIZEOF_OFF_T {d}", .{8}),
        .SIZEOF_CURL_OFF_T_CODE = b.fmt("#define SIZEOF_CURL_OFF_T {d}", .{8}),
        .SIZEOF_CURL_SOCKET_T_CODE = b.fmt("#define SIZEOF_CURL_SOCKET_T {d}", .{@as(i64, if (target.result.os.tag == .windows) 8 else 4)}),
        .SIZEOF_SIZE_T_CODE = b.fmt("#define SIZEOF_SIZE_T {d}", .{target.result.ptrBitWidth() / 8}),
        .SIZEOF_TIME_T_CODE = b.fmt("#define SIZEOF_TIME_T {d}", .{8}),
        .PACKAGE = "",
        .PACKAGE_BUGREPORT = "curl",
        .PACKAGE_NAME = "a suitable curl mailing list: https://curl.se/mail/",
        .PACKAGE_STRING = "curl",
        .PACKAGE_TARNAME = "curl",
        .PACKAGE_VERSION = b.fmt("{}", .{version}),
        .STDC_HEADERS = true,
        .USE_ARES = enable_ares,
        .USE_THREADS_POSIX = target.result.os.tag != .windows and !target.result.os.tag.isDarwin(),
        .USE_THREADS_WIN32 = enable_threaded_resolver and target.result.os.tag == .windows,
        .USE_GNUTLS = use_gnutls,
        .USE_SECTRANSP = use_sectransp,
        .USE_SSLS_EXPORT = use_ssls_export,
        .USE_MBEDTLS = use_mbedtls,
        .USE_BEARSSL = use_bearssl,
        .USE_RUSTLS = use_rustls,
        .USE_WOLFSSL = use_wolfssl,
        .HAVE_WOLFSSL_DES_ECB_ENCRYPT = use_wolfssl and false, // TODO
        .HAVE_WOLFSSL_BIO = use_wolfssl and false, // TODO
        .HAVE_WOLFSSL_FULL_BIO = use_wolfssl and false, // TODO
        .USE_LIBSSH = use_libssh and !use_libssh2,
        .USE_LIBSSH2 = use_libssh2,
        .USE_WOLFSSH = use_wolfssh and use_wolfssl and !use_libssh2 and !use_libssh,
        .USE_LIBPSL = use_libpsl,
        .USE_OPENLDAP = !disable_ldap and !use_win32_ldap, // TODO
        .USE_OPENSSL = use_openssl,
        .USE_AMISSL = null, // AMIGA
        .USE_LIBRTMP = use_librtmp,
        .USE_GSASL = use_gsasl,
        .USE_LIBUV = use_libuv,
        .HAVE_UV_H = use_libuv,
        .CURL_DISABLE_OPENSSL_AUTO_LOAD_CONFIG = disable_openssl_auto_load_config,
        .USE_NGHTTP2 = use_nghttp2,
        .USE_NGTCP2 = use_ngtcp2,
        .USE_NGHTTP3 = use_ngtcp2, // same condition
        .USE_QUICHE = use_quiche,
        .USE_OPENSSL_QUIC = use_openssl_quic,
        .HAVE_QUICHE_CONN_SET_QLOG_FD = null, // TODO
        .USE_MSH3 = use_msh3,
        .USE_UNIX_SOCKETS = target.result.os.tag == .windows or enable_unix_sockets,
        .USE_WIN32_LARGE_FILES = target.result.os.tag == .windows,
        .USE_WINDOWS_SSPI = enable_windows_sspi,
        .USE_SCHANNEL = use_schannel,
        .USE_WATT32 = null, // DOS
        .CURL_WITH_MULTI_SSL = with_multi_sll,
        .VERSION = b.fmt("{}", .{version}),
        ._FILE_OFFSET_BITS = 64,
        ._LARGE_FILES = null, // OS/400
        ._THREAD_SAFE = null, // AIX 4.3
        .@"const" = null,
        .size_t = null,
        .ssize_t = null,
        .HAVE_MACH_ABSOLUTE_TIME = target.result.os.tag.isDarwin(),
        .USE_WIN32_IDN = target.result.os.tag == .windows and use_win32_idn,
        .USE_APPLE_IDN = target.result.os.tag.isDarwin() and use_apple_idn,
        .HAVE_OPENSSL_SRP = null, // TODO
        .HAVE_GNUTLS_SRP = null, // TODO
        .USE_TLS_SRP = null, // TODO
        .USE_HTTPSRR = httpsrr,
        .USE_ECH = ech,
        .HAVE_WOLFSSL_CTX_GENERATEECHCONFIG = null, // TODO
        .HAVE_SSL_SET1_ECH_CONFIG_LIST = null, // TODO
    });
    curl.addConfigHeader(curl_config);
    exe.root_module.addConfigHeader(curl_config);

    // b.getInstallStep().dependOn(&b.addInstallHeaderFile(curl_config.getOutput(), "curl_config.h").step);
}

pub fn artifact(dependency: *std.Build.Dependency, kind: std.Build.Step.Compile.Kind) *std.Build.Step.Compile {
    std.debug.assert(kind == .exe or kind == .lib);
    var result: ?*std.Build.Step.Compile = null;
    for (dependency.builder.install_tls.step.dependencies.items) |dep_step| {
        const inst = dep_step.cast(std.Build.Step.InstallArtifact) orelse continue;

        if (!std.mem.eql(u8, inst.artifact.name, "curl")) continue;
        if (inst.artifact.kind != kind) continue;

        std.debug.assert(result == null);
        result = inst.artifact;
    }
    return result.?;
}

fn dependentBoolOption(
    b: *std.Build,
    name_raw: []const u8,
    description_raw: []const u8,
    value: bool,
    depends: bool,
    force: bool,
) bool {
    const option = b.option(bool, name_raw, description_raw);
    if (depends) {
        return option orelse value;
    } else {
        if (option != null) {
            std.debug.panic("option '{s}' is not available.", .{name_raw});
        }
        return force;
    }
}

const lib_vauth_sources: []const []const u8 = &.{
    "vauth/cleartext.c",
    "vauth/cram.c",
    "vauth/digest.c",
    "vauth/digest_sspi.c",
    "vauth/gsasl.c",
    "vauth/krb5_gssapi.c",
    "vauth/krb5_sspi.c",
    "vauth/ntlm.c",
    "vauth/ntlm_sspi.c",
    "vauth/oauth2.c",
    "vauth/spnego_gssapi.c",
    "vauth/spnego_sspi.c",
    "vauth/vauth.c",
};

const lib_vauth_headers: []const []const u8 = &.{
    "vauth/digest.h",
    "vauth/ntlm.h",
    "vauth/vauth.h",
};

const lib_vtls_sources: []const []const u8 = &.{
    "vtls/bearssl.c",
    "vtls/cipher_suite.c",
    "vtls/gtls.c",
    "vtls/hostcheck.c",
    "vtls/keylog.c",
    "vtls/mbedtls.c",
    "vtls/mbedtls_threadlock.c",
    "vtls/openssl.c",
    "vtls/rustls.c",
    "vtls/schannel.c",
    "vtls/schannel_verify.c",
    "vtls/sectransp.c",
    "vtls/vtls.c",
    "vtls/vtls_scache.c",
    "vtls/vtls_spack.c",
    "vtls/wolfssl.c",
    "vtls/x509asn1.c",
};

const lib_vtls_headers: []const []const u8 = &.{
    "vtls/bearssl.h",
    "vtls/cipher_suite.h",
    "vtls/gtls.h",
    "vtls/hostcheck.h",
    "vtls/keylog.h",
    "vtls/mbedtls.h",
    "vtls/mbedtls_threadlock.h",
    "vtls/openssl.h",
    "vtls/rustls.h",
    "vtls/schannel.h",
    "vtls/schannel_int.h",
    "vtls/sectransp.h",
    "vtls/vtls.h",
    "vtls/vtls_int.h",
    "vtls/vtls_scache.h",
    "vtls/vtls_spack.h",
    "vtls/wolfssl.h",
    "vtls/x509asn1.h",
};

const lib_vquic_sources: []const []const u8 = &.{
    "vquic/curl_msh3.c",
    "vquic/curl_ngtcp2.c",
    "vquic/curl_osslq.c",
    "vquic/curl_quiche.c",
    "vquic/vquic.c",
    "vquic/vquic-tls.c",
};

const lib_vquic_headers: []const []const u8 = &.{
    "vquic/curl_msh3.h",
    "vquic/curl_ngtcp2.h",
    "vquic/curl_osslq.h",
    "vquic/curl_quiche.h",
    "vquic/vquic.h",
    "vquic/vquic_int.h",
    "vquic/vquic-tls.h",
};

const lib_vssh_sources: []const []const u8 = &.{
    "vssh/libssh.c",
    "vssh/libssh2.c",
    "vssh/curl_path.c",
    "vssh/wolfssh.c",
};

const lib_vssh_headers: []const []const u8 = &.{
    "vssh/curl_path.h",
    "vssh/ssh.h",
};

const lib_sources: []const []const u8 = &.{
    "altsvc.c",
    "amigaos.c",
    "asyn-ares.c",
    "asyn-thread.c",
    "base64.c",
    "bufq.c",
    "bufref.c",
    "cf-h1-proxy.c",
    "cf-h2-proxy.c",
    "cf-haproxy.c",
    "cf-https-connect.c",
    "cf-socket.c",
    "cfilters.c",
    "conncache.c",
    "cshutdn.c",
    "connect.c",
    "content_encoding.c",
    "cookie.c",
    "curl_addrinfo.c",
    "curl_des.c",
    "curl_endian.c",
    "curl_fnmatch.c",
    "curl_get_line.c",
    "curl_gethostname.c",
    "curl_gssapi.c",
    "curl_memrchr.c",
    "curl_multibyte.c",
    "curl_ntlm_core.c",
    "curl_range.c",
    "curl_rtmp.c",
    "curl_sasl.c",
    "curl_sha512_256.c",
    "curl_sspi.c",
    "curl_threads.c",
    "curl_trc.c",
    "cw-out.c",
    "cw-pause.c",
    "dict.c",
    "doh.c",
    "dynbuf.c",
    "dynhds.c",
    "easy.c",
    "easygetopt.c",
    "easyoptions.c",
    "escape.c",
    "file.c",
    "fileinfo.c",
    "fopen.c",
    "formdata.c",
    "ftp.c",
    "ftplistparser.c",
    "getenv.c",
    "getinfo.c",
    "gopher.c",
    "hash.c",
    "hash_offt.c",
    "headers.c",
    "hmac.c",
    "hostasyn.c",
    "hostip.c",
    "hostip4.c",
    "hostip6.c",
    "hostsyn.c",
    "hsts.c",
    "http.c",
    "http1.c",
    "http2.c",
    "http_aws_sigv4.c",
    "http_chunks.c",
    "http_digest.c",
    "http_negotiate.c",
    "http_ntlm.c",
    "http_proxy.c",
    "httpsrr.c",
    "idn.c",
    "if2ip.c",
    "imap.c",
    "inet_ntop.c",
    "inet_pton.c",
    "krb5.c",
    "ldap.c",
    "llist.c",
    "macos.c",
    "md4.c",
    "md5.c",
    "memdebug.c",
    "mime.c",
    "mprintf.c",
    "mqtt.c",
    "multi.c",
    "multi_ev.c",
    "netrc.c",
    "nonblock.c",
    "noproxy.c",
    "openldap.c",
    "parsedate.c",
    "pingpong.c",
    "pop3.c",
    "progress.c",
    "psl.c",
    "rand.c",
    "rename.c",
    "request.c",
    "rtsp.c",
    "select.c",
    "sendf.c",
    "setopt.c",
    "sha256.c",
    "share.c",
    "slist.c",
    "smb.c",
    "smtp.c",
    "socketpair.c",
    "socks.c",
    "socks_gssapi.c",
    "socks_sspi.c",
    "speedcheck.c",
    "splay.c",
    "strcase.c",
    "strdup.c",
    "strequal.c",
    "strerror.c",
    "strparse.c",
    "system_win32.c",
    "telnet.c",
    "tftp.c",
    "timediff.c",
    "timeval.c",
    "transfer.c",
    "url.c",
    "urlapi.c",
    "version.c",
    "version_win32.c",
    "warnless.c",
    "ws.c",
};

const lib_headers: []const []const u8 = &.{
    "altsvc.h",
    "amigaos.h",
    "arpa_telnet.h",
    "asyn.h",
    "bufq.h",
    "bufref.h",
    "cf-h1-proxy.h",
    "cf-h2-proxy.h",
    "cf-haproxy.h",
    "cf-https-connect.h",
    "cf-socket.h",
    "cfilters.h",
    "conncache.h",
    "connect.h",
    "content_encoding.h",
    "cookie.h",
    "curl_addrinfo.h",
    "curl_base64.h",
    "curl_ctype.h",
    "curl_des.h",
    "curl_endian.h",
    "curl_fnmatch.h",
    "curl_get_line.h",
    "curl_gethostname.h",
    "curl_gssapi.h",
    "curl_hmac.h",
    "curl_krb5.h",
    "curl_ldap.h",
    "curl_md4.h",
    "curl_md5.h",
    "curl_memory.h",
    "curl_memrchr.h",
    "curl_multibyte.h",
    "curl_ntlm_core.h",
    "curl_printf.h",
    "curl_range.h",
    "curl_rtmp.h",
    "curl_sasl.h",
    "curl_setup.h",
    "curl_setup_once.h",
    "curl_sha256.h",
    "curl_sha512_256.h",
    "curl_sspi.h",
    "curl_threads.h",
    "curl_trc.h",
    "curlx.h",
    "cw-out.h",
    "dict.h",
    "doh.h",
    "dynbuf.h",
    "dynhds.h",
    "easy_lock.h",
    "easyif.h",
    "easyoptions.h",
    "escape.h",
    "file.h",
    "fileinfo.h",
    "fopen.h",
    "formdata.h",
    "ftp.h",
    "ftplistparser.h",
    "functypes.h",
    "getinfo.h",
    "gopher.h",
    "hash.h",
    "headers.h",
    "hostip.h",
    "hsts.h",
    "http.h",
    "http1.h",
    "http2.h",
    "http_aws_sigv4.h",
    "http_chunks.h",
    "http_digest.h",
    "http_negotiate.h",
    "http_ntlm.h",
    "http_proxy.h",
    "httpsrr.h",
    "idn.h",
    "if2ip.h",
    "imap.h",
    "inet_ntop.h",
    "inet_pton.h",
    "llist.h",
    "macos.h",
    "memdebug.h",
    "mime.h",
    "mqtt.h",
    "multihandle.h",
    "multiif.h",
    "netrc.h",
    "nonblock.h",
    "noproxy.h",
    "parsedate.h",
    "pingpong.h",
    "pop3.h",
    "progress.h",
    "psl.h",
    "rand.h",
    "rename.h",
    "request.h",
    "rtsp.h",
    "select.h",
    "sendf.h",
    "setopt.h",
    "setup-os400.h",
    "setup-vms.h",
    "setup-win32.h",
    "share.h",
    "sigpipe.h",
    "slist.h",
    "smb.h",
    "smtp.h",
    "sockaddr.h",
    "socketpair.h",
    "socks.h",
    "speedcheck.h",
    "splay.h",
    "strcase.h",
    "strdup.h",
    "strerror.h",
    "strparse.h",
    "strtok.h",
    "strtoofft.h",
    "system_win32.h",
    "telnet.h",
    "tftp.h",
    "timediff.h",
    "timeval.h",
    "transfer.h",
    "url.h",
    "urlapi-int.h",
    "urldata.h",
    "version_win32.h",
    "warnless.h",
    "ws.h",
};

const sources = lib_sources ++ lib_vauth_sources ++ lib_vtls_sources ++ lib_vquic_sources ++ lib_vssh_sources;
const headers = lib_headers ++ lib_vauth_headers ++ lib_vtls_headers ++ lib_vquic_headers ++ lib_vssh_headers;

/// libcurl sources to include in curltool lib we use for test binaries
const tool_lib_sources: []const []const u8 = &.{
    "base64.c",
    "dynbuf.c",
    "timeval.c",
};

const curlx_sources: []const []const u8 = &.{
    "base64.c",
    "curl_multibyte.c",
    "dynbuf.c",
    "nonblock.c",
    "strparse.c",
    "strcase.c",
    "timediff.c",
    "timeval.c",
    "version_win32.c",
    "warnless.c",
};

const curlx_headers: []const []const u8 = &.{
    "curl_ctype.h",
    "curl_multibyte.h",
    "curl_setup.h",
    "dynbuf.h",
    "nonblock.h",
    "strtoofft.h",
    "timediff.h",
    "version_win32.h",
    "warnless.h",
};

const exe_sources: []const []const u8 = &.{
    "slist_wc.c",
    "terminal.c",
    "tool_bname.c",
    "tool_cb_dbg.c",
    "tool_cb_hdr.c",
    "tool_cb_prg.c",
    "tool_cb_rea.c",
    "tool_cb_see.c",
    "tool_cb_soc.c",
    "tool_cb_wrt.c",
    "tool_cfgable.c",
    "tool_dirhie.c",
    "tool_doswin.c",
    "tool_easysrc.c",
    "tool_filetime.c",
    "tool_findfile.c",
    "tool_formparse.c",
    "tool_getparam.c",
    "tool_getpass.c",
    "tool_help.c",
    "tool_helpers.c",
    "tool_ipfs.c",
    "tool_libinfo.c",
    "tool_listhelp.c",
    "tool_main.c",
    "tool_msgs.c",
    "tool_operate.c",
    "tool_operhlp.c",
    "tool_paramhlp.c",
    "tool_parsecfg.c",
    "tool_progress.c",
    "tool_setopt.c",
    "tool_sleep.c",
    "tool_ssls.c",
    "tool_stderr.c",
    "tool_strdup.c",
    "tool_urlglob.c",
    "tool_util.c",
    "tool_vms.c",
    "tool_writeout.c",
    "tool_writeout_json.c",
    "tool_xattr.c",
    "var.c",
};

const exe_header: []const []const u8 = &.{
    "slist_wc.h",
    "terminal.h",
    "tool_binmode.h",
    "tool_bname.h",
    "tool_cb_dbg.h",
    "tool_cb_hdr.h",
    "tool_cb_prg.h",
    "tool_cb_rea.h",
    "tool_cb_see.h",
    "tool_cb_soc.h",
    "tool_cb_wrt.h",
    "tool_cfgable.h",
    "tool_dirhie.h",
    "tool_doswin.h",
    "tool_easysrc.h",
    "tool_filetime.h",
    "tool_findfile.h",
    "tool_formparse.h",
    "tool_getparam.h",
    "tool_getpass.h",
    "tool_help.h",
    "tool_helpers.h",
    "tool_ipfs.h",
    "tool_libinfo.h",
    "tool_main.h",
    "tool_msgs.h",
    "tool_operate.h",
    "tool_operhlp.h",
    "tool_paramhlp.h",
    "tool_parsecfg.h",
    "tool_progress.h",
    "tool_sdecls.h",
    "tool_setopt.h",
    "tool_setup.h",
    "tool_sleep.h",
    "tool_ssls.h",
    "tool_stderr.h",
    "tool_strdup.h",
    "tool_urlglob.h",
    "tool_util.h",
    "tool_version.h",
    "tool_vms.h",
    "tool_writeout.h",
    "tool_writeout_json.h",
    "tool_xattr.h",
    "var.h",
};
