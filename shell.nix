let
  yarn_overlay = import (builtins.fetchTarball https://github.com/PrecisionNutrition/nixpkgs-pn/archive/0.0.3.tar.gz);
  pkgs = import (builtins.fetchTarball {
    name = "nixos-19.09-2020-02-05";  # Descriptive name
    url = https://github.com/nixos/nixpkgs-channels/archive/ea553d8c67c6a718448da50826ff5b6916dc9c59.tar.gz;
    sha256 = "0g9smv36sk42rfyzi8wyq2wl11c5l0qaldij1zjdj60s57cl3wgj";
  }) {
    overlays = [ yarn_overlay ];
  };

  forego = pkgs.buildGoPackage rec {
    name = "forego-${version}";
    version = "20180216151118";

    goPackagePath = "github.com/ddollar/forego";

    src = pkgs.fetchFromGitHub {
      owner = "ddollar";
      repo = "forego";
      rev = "${version}";
      sha256 = "1xypm61b05vsq75807ax0q41z6jr438malrz9z7qkrh4nghmbiww";
    };

    buildFlags = "--tags release";
  };


  # define packagesto install with special handling for OSX
  basePackages = [
    forego
    pkgs.python
    pkgs.nodejs-12_x
    pkgs.yarn
    pkgs.gnumake
    pkgs.gcc
    pkgs.readline
    pkgs.openssl
    pkgs.zlib
    pkgs.curl
    pkgs.libiconv
    pkgs.postgresql_11
    pkgs.bundler
    pkgs.pkgconfig
    pkgs.libxml2
    pkgs.libxslt
    pkgs.ruby_2_6
    pkgs.zlib
    pkgs.libiconv
    pkgs.lzma
    pkgs.redis
    pkgs.git
    pkgs.openssh
  ];

  inputs = if pkgs.system == "x86_64-darwin" then
              basePackages ++ [pkgs.darwin.apple_sdk.frameworks.CoreServices]
           else
              basePackages;


   localPath = ./. + "/local.nix";

   final = if builtins.pathExists localPath then
            inputs ++ (import localPath)
           else
             inputs;

  # define shell startup command with special handling for OSX
  baseHooks = ''
    export PS1='\n\[\033[1;32m\][nix-shell:\w]($(git rev-parse --abbrev-ref HEAD))\$\[\033[0m\] '

    if [ -n "~/.pn_anonymize_creds" ]
      then source ~/.pn_anonymize_creds
    fi

    mkdir -p .nix-gems
    mkdir -p tmp/pids
    export GEM_HOME=$PWD/.nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
    export PATH=$PWD/bin:$PATH
    echo "bundler install check..."
    gem list -i ^bundler$ -v 1.17.3 || gem install bundler --version=1.17.3 --no-document
    bundle config build.nokogiri --use-system-libraries
    bundle config --local path vendor/cache

    pnforego () {
      forego "$@" -e .env
    }
  '';

  hooks = baseHooks + ''
                pncompose () {
                  docker-compose -f docker-compose-minimal.yml "$@"
                }
              '';

in
  pkgs.stdenv.mkDerivation {
    name = "eternal-sledgehammer";
    buildInputs = final;
    shellHook = hooks;
    hardeningDisable = [ "all" ];
  }
