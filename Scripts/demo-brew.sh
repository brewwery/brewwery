#!/bin/bash
#
# A scripted stand-in for `brew`, used only to take screenshots (Scripts/screenshots.sh).
#
# It describes a plausible developer Mac so marketing and documentation images are
# reproducible and never show a real machine's packages or paths. It performs no changes:
# every mutating subcommand just prints what Homebrew would.
#
case "$1" in
  --version)
    echo "Homebrew 7.0.1"
    ;;
  config)
    cat <<'OUT'
HOMEBREW_VERSION: 7.0.1
ORIGIN: https://github.com/Homebrew/brew
HOMEBREW_PREFIX: /opt/homebrew
macOS: 26.0-arm64
OUT
    ;;
  list)
    if [[ "$*" == *"--cask"* ]]; then
      cat <<'OUT'
{"casks":[
 {"token":"visual-studio-code","name":["Visual Studio Code"],"desc":"Open-source code editor","homepage":"https://code.visualstudio.com/","installed":"1.104.0"},
 {"token":"iterm2","name":["iTerm2"],"desc":"Terminal emulator as alternative to Apple's Terminal app","homepage":"https://iterm2.com/","installed":"3.6.2"},
 {"token":"docker-desktop","name":["Docker Desktop"],"desc":"App to build and share containerised applications and microservices","homepage":"https://www.docker.com/products/docker-desktop","installed":"4.45.0"},
 {"token":"raycast","name":["Raycast"],"desc":"Control your tools with a few keystrokes","homepage":"https://www.raycast.com/","installed":"1.103.1"},
 {"token":"figma","name":["Figma"],"desc":"Collaborative team software","homepage":"https://www.figma.com/","installed":"125.7.4"},
 {"token":"google-chrome","name":["Google Chrome"],"desc":"Web browser","homepage":"https://www.google.com/chrome/","installed":"140.0.7339.81"},
 {"token":"rectangle","name":["Rectangle"],"desc":"Move and resize windows using keyboard shortcuts or snap areas","homepage":"https://rectangleapp.com/","installed":"0.91"}
]}
OUT
    else
      cat <<'OUT'
{"formulae":[
 {"name":"gh","full_name":"gh","desc":"GitHub command-line tool","homepage":"https://cli.github.com/","dependencies":[],"installed":[{"version":"2.78.0","installed_on_request":true}]},
 {"name":"git","full_name":"git","desc":"Distributed revision control system","homepage":"https://git-scm.com","dependencies":["gettext","pcre2"],"installed":[{"version":"2.51.0","installed_on_request":true}]},
 {"name":"go","full_name":"go","desc":"Open source programming language to build simple/reliable/efficient software","homepage":"https://go.dev/","dependencies":[],"installed":[{"version":"1.25.1","installed_on_request":true}]},
 {"name":"jq","full_name":"jq","desc":"Lightweight and flexible command-line JSON processor","homepage":"https://jqlang.github.io/jq/","dependencies":["oniguruma"],"installed":[{"version":"1.8.1","installed_on_request":true}]},
 {"name":"fzf","full_name":"fzf","desc":"Command-line fuzzy finder written in Go","homepage":"https://github.com/junegunn/fzf","dependencies":[],"installed":[{"version":"0.65.2","installed_on_request":true}]},
 {"name":"node","full_name":"node","desc":"Open-source, cross-platform JavaScript runtime environment","homepage":"https://nodejs.org/","dependencies":["brotli","c-ares","icu4c@77","libnghttp2","libuv","openssl@3"],"installed":[{"version":"24.6.0","installed_on_request":true}]},
 {"name":"postgresql@17","full_name":"postgresql@17","desc":"Object-relational database system","homepage":"https://www.postgresql.org/","dependencies":["icu4c@77","krb5","openssl@3","readline"],"installed":[{"version":"17.6","installed_on_request":true}]},
 {"name":"python@3.13","full_name":"python@3.13","desc":"Interpreted, interactive, object-oriented programming language","homepage":"https://www.python.org/","dependencies":["mpdecimal","openssl@3","sqlite","xz"],"installed":[{"version":"3.13.6","installed_on_request":true}]},
 {"name":"redis","full_name":"redis","desc":"Persistent key-value database, with built-in net interface","homepage":"https://redis.io/","dependencies":["openssl@3"],"installed":[{"version":"8.2.1","installed_on_request":true}]},
 {"name":"ripgrep","full_name":"ripgrep","desc":"Search tool like grep and The Silver Searcher","homepage":"https://github.com/BurntSushi/ripgrep","dependencies":["pcre2"],"installed":[{"version":"14.1.1","installed_on_request":true}]},
 {"name":"uv","full_name":"uv","desc":"Extremely fast Python package installer and resolver, written in Rust","homepage":"https://docs.astral.sh/uv/","dependencies":[],"installed":[{"version":"0.8.15","installed_on_request":true}]},
 {"name":"wget","full_name":"wget","desc":"Internet file retriever","homepage":"https://www.gnu.org/software/wget/","dependencies":["libidn2","openssl@3"],"installed":[{"version":"1.25.0","installed_on_request":true}]},
 {"name":"brotli","full_name":"brotli","desc":"Generic-purpose lossless compression algorithm by Google","homepage":"https://github.com/google/brotli","dependencies":[],"installed":[{"version":"1.1.0","installed_on_request":false}]},
 {"name":"ca-certificates","full_name":"ca-certificates","desc":"Mozilla CA certificate store","homepage":"https://curl.se/docs/caextract.html","dependencies":[],"installed":[{"version":"2025-09-09","installed_on_request":false}]},
 {"name":"icu4c@77","full_name":"icu4c@77","desc":"C/C++ and Java libraries for Unicode and globalization","homepage":"https://icu.unicode.org/home","dependencies":[],"installed":[{"version":"77.1","installed_on_request":false}]},
 {"name":"libuv","full_name":"libuv","desc":"Multi-platform support library with a focus on asynchronous I/O","homepage":"https://libuv.org/","dependencies":[],"installed":[{"version":"1.51.0","installed_on_request":false}]},
 {"name":"openssl@3","full_name":"openssl@3","desc":"Cryptography and SSL/TLS Toolkit","homepage":"https://openssl-library.org","dependencies":["ca-certificates"],"installed":[{"version":"3.5.2","installed_on_request":false}]},
 {"name":"pcre2","full_name":"pcre2","desc":"Perl compatible regular expressions library with a new API","homepage":"https://www.pcre.org/","dependencies":[],"installed":[{"version":"10.46","installed_on_request":false}]},
 {"name":"readline","full_name":"readline","desc":"Library for command-line editing","homepage":"https://tiswww.case.edu/php/chet/readline/rltop.html","dependencies":[],"installed":[{"version":"8.3.1","installed_on_request":false}]},
 {"name":"sqlite","full_name":"sqlite","desc":"Command-line interface for SQLite","homepage":"https://sqlite.org/index.html","dependencies":["readline"],"installed":[{"version":"3.50.4","installed_on_request":false}]},
 {"name":"xz","full_name":"xz","desc":"General-purpose data compression with high compression ratio","homepage":"https://tukaani.org/xz/","dependencies":[],"installed":[{"version":"5.8.1","installed_on_request":false}]}
]}
OUT
    fi
    ;;
  leaves)
    printf '%s\n' gh git go jq fzf node postgresql@17 python@3.13 redis ripgrep uv wget
    ;;
  outdated)
    cat <<'OUT'
{"formulae":[
 {"name":"node","installed_versions":["24.6.0"],"current_version":"24.8.0","pinned":false},
 {"name":"gh","installed_versions":["2.78.0"],"current_version":"2.79.0","pinned":false},
 {"name":"python@3.13","installed_versions":["3.13.6"],"current_version":"3.13.7","pinned":false},
 {"name":"uv","installed_versions":["0.8.15"],"current_version":"0.8.17","pinned":false}
],"casks":[
 {"name":"visual-studio-code","installed_versions":["1.104.0"],"current_version":"1.104.1"},
 {"name":"docker-desktop","installed_versions":["4.45.0"],"current_version":"4.46.0"}
]}
OUT
    ;;
  services)
    if [[ "$2" == "list" ]]; then
      cat <<'OUT'
[{"name":"postgresql@17","status":"started","user":"alex","file":"/Users/alex/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist"},
 {"name":"redis","status":"started","user":"alex","file":"/Users/alex/Library/LaunchAgents/homebrew.mxcl.redis.plist"},
 {"name":"unbound","status":"none"}]
OUT
    else
      echo "==> Successfully ran $2 for $3"
    fi
    ;;
  tap)
    [[ -z "$2" ]] && printf '%s\n' hashicorp/tap oven-sh/bun
    ;;
  search)
    if [[ "$2" == "--cask" ]]; then
      printf '%s\n' postgres-app postico
    else
      printf '%s\n' postgresql@14 postgresql@15 postgresql@16 postgresql@17 postgresql@18 postgrest pgvector check_postgres
    fi
    ;;
  info)
    name="${*: -1}"
    echo "{\"formulae\":[{\"name\":\"$name\",\"full_name\":\"$name\",\"desc\":\"Object-relational database system\",\"homepage\":\"https://www.postgresql.org/\",\"versions\":{\"stable\":\"17.6\"},\"dependencies\":[\"icu4c@77\",\"krb5\",\"openssl@3\",\"readline\"],\"installed\":[]}],\"casks\":[]}"
    ;;
  doctor)
    echo "Your system is ready to brew."
    ;;
  cleanup)
    cat <<'OUT'
Would remove: /Users/alex/Library/Caches/Homebrew/node--24.5.0.arm64_tahoe.bottle.tar.gz (21.4MB)
Would remove: /opt/homebrew/Cellar/python@3.13/3.13.5 (3,612 files, 66.1MB)
This operation would free approximately 87.5MB of disk space.
OUT
    ;;
  *)
    echo "==> brew $* (demo)"
    ;;
esac
exit 0
