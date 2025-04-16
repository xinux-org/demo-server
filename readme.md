# Rust, Actix & Diesel Nix Template

This is a starter pack for Nix friendly web server written on Actix and Diesel via Rust ecosystem provided to you
by [Xinux Community] members. The project uses fenix to fetch Rust toolchain from rustup catalogue and unfortunately,
it fetches and patches once (untill you clean cache) the whole rustup toolchain and THEN build the program or run.

This is a starter pack for Nix friendly Rust Actix server with database on Rust ecosystem provided to you by [Xinux Community]
members. The project uses fenix to fetch Rust toolchain from rustup catalogue and unfortunately, it fetches and patches
once (untill you clean cache) the whole rustup toolchain and THEN build the program or run.

> Please, after bootstrapping, rename / change all `example` or `template` keywords in template files.

## Rust Toolchain

Rustup toolchain is utilized and managed by Nix package manager via `rust-toolchain.toml` file which can be found
at the root path of your project. Feel free to modify toolchain file to customize toolchain behaviour.

## Development

The project has `shell.nix` which has development environment preconfigured already for you. Just open your
terminal and at the root of this project:

```bash
# Open in bash by default
nix develop

# If you want other shell
nix develop -c $SHELL

# Upon entering development environment for the first
# time, development environment will bootstrap everything
# for you. You may use the environment as-is or modify
# it to your liking. Also don't forget to generate your own
# config.toml for development purposes.

cargo run config generate ./config.toml

# Please, don't forget to read contents of justfile,
# it will certainly make your DX way better.

just start # replace start with available command

# After entering development environment, inside the
# env, you can open your editor, so your editor will
# read all $PATH and environmental variables, also
# your terminal inside your editor will adopt all
# variables, so, you can close terminal.

# Neovim
vim .

# VSCode
code .

# Zed Editor
zed .
```

The development environment has whatever you may need already, but feel free to add or remove whatever
inside `shell.nix`.

## Building

Well, there are two ways of building your project. You can either go with classic `cargo build` way, but before that, make sure to enter development environment to have cargo and all rust toolchain available in your PATH, you may do like that:

```bash
# Entering development environment
nix develop -c $SHELL

# Compile the project
cargo build --release
```

Or, you can build your project via nix which will do all the dirty work for you. Just, in your terminal:

```bash
# Build in nix environment
nix build

# Executable binary is available at:
./result/bin/server
```

## Deploying (works only for flake based NixOS)

Deploying this project, actix server requires host machine to have its own flake based configuration.

### Activation

In your configuration, add your project repository to `inputs`.

```nix
{
  inputs = {
    # ...

    # Let's imagine name of this project as `tempserver`
    tempserver.url = "github:somewhere/tempserver";
  };
}
```

Ok, now we have your project in repository list and now, we need to make use of options provided by modules of your project. In order to do that, we need to activate our module by importing our module. In your configuration.nix, find where you imported things and then add your project like that:

```nix
# Most of the time it's at the top part of nix configurations
# and written only once in a nix file.
{ ... }: {
  # ... something

  # And here begins like that
  imports = [
    # Imagine here your existing imports

    # Now import your project module like this
    inputs.tempserver.nixosModules.server
  ];
};
```

Alright! Since we imported the module of our project and options are now available, now head into setting up section!

### Set up

Options are available, modules are activated and everything is ready to deploy, but now, we need to explain NixOS how
to deploy our project by writing some Nix configs. I already wrote some options and configurations which will be available
by default after project bootstrap, you are free to modify, add and remove whatever inside `module.nix` to your
liking. If you need list of available default options or explanations for every option, refer to [available default options] section below. In this guide, I'll
be showing you an example set up you may use to get started very fast, you'll find out the rest option by yourself if you
need something else. In your `configuration.nix` or wherever of your configuration:

```nix
{
  # WARNING! `tempserver` shown below changes
  # depending on package name in your Cargo.toml
  # Basically it's generated like that:
  # => "{package.name}"
  # Replace package.name in your Cargo.toml with
  # {package.name}
  services.tempserver = {
    # Enable systemd service
    enable = true;

    # Port to host http server
    port = 25888;

    # Configurations for database
    database = {
      # Path to a file consisting only password for your database
      # Sops and secret manager friendly like:
      # config.sops.secrets."xinux/demo-server".path
      passwordFile = "/srv/tempserver-dbpass";
    };
  };
}
```

This is very basic examples, you can tune other things like user who's going to run this systemd service, change group of user and many more. You can add your own modifications and add more options by yourself.

### Available default options

These are options that are available by default, just put services."${manifest.name}" before the keys:

#### `enable` (required) -> bool

Turn on systemd service of your server project.

#### `address` (optional) -> string

Address where server should listen to while hosting it via service, something like `127.0.0.1` or `0.0.0.0`.

#### `port` (optional) -> integer

Which port should be used to host your server.

#### `threads` (optional) -> integer

How many threads should be initialized for parallel request processing.

#### `proxy-reverse.enable` (optional) -> bool

Enable automatic web proxy configuration for either caddy or nginx. If the value is false, server will be deployed at `localhost` only. This is for people who don't have or want complex web server configurations.

#### `proxy-reverse.domain` (optional) -> string

It will be passed to web proxy to let it know whether to which domain the configurations should be appointed to.

#### `proxy-reverse.proxy` (optional) -> `caddy` or `nginx` as value

Choose which web server software should be integrated with.

#### `database.host` (optional) -> string

Address of host that is hosting database for this server. Local database will be created if not specified using socket connection.

#### `database.socketAuth` (optional) -> string

Whether to use authentication via socket for passworless local connection.

#### `database.socket` (optional) -> string

If socketAuth is true, then location to socket in your system should be specified to which this value is designed for.

#### `database.port` (optional) -> string

If you're using remote database, then specify port where your database is hosted at.

#### `database.name` (optional) -> string

Name of your database.

#### `database.user` (optional) -> string

Owner of database.

#### `database.passwordFile` (requried) -> string

Database password to pass to server, it should be a file that can be placed almost anywhere. Inside the file, there should be only database password as whole content. Don't type password directly as value for this option, it was done like that to don't expose your password openly in your public repository or expose it at /nix/store. Also, you can chain it with secret manager like `sops-nix` like that:

```nix
{
  sops.secrets = {
    "dbPass" = {
      owner = config.services.tempserver.user;
    };
  };

  services.tempserver.database.passwordFile = config.sops.secrets."dbPass".path;
}
```

#### `user` (optional) -> string

The user that will run the your server. It's defaulted to "{package.name}".

#### `group` (optional) -> string

Name of a group to which the user that's going to run your server should be added to. It's defaulted to the name of the user.

#### `dataDir` (optional) -> path

A location where working directory should be set to before starting your server. If you have a code to write something in current working directory, the value to this option is where it will be written. It's defaulted to "/var/lib/{package.name}".

#### `package` (optional) -> nix package

The packaged server with pre-compiled binaries and whatever. Defaulted to current project's build output and highly suggested to not change value of this option unless you know what you're doing.

## Working productions

There are bunch of servers that are using this template and are deployed to which you may refer as working examples:

- [Floss Registry](https://reg.floss.uz) - [GitHub](https://github.com/floss-uz/registrar) / To be deployed

## FAQ

### Why not use default.nix for devShell?

There's been cases when I wanted to reproduce totally different behaviors in development environment and
production build. This occurs quite a lot lately for some reason and because of that, I tend to keep
both shell.nix and default.nix to don't mix things up.

### Error when building or entering development environment

If you see something like that in the end:

```
error: hash mismatch in fixed-output derivation '/nix/store/fsrachja0ig5gijrkbpal1b031lzalf0-channel-rust-stable.toml.drv':
  specified: sha256-vMlz0zHduoXtrlu0Kj1jEp71tYFXyymACW8L4jzrzNA=
     got:    sha256-Hn2uaQzRLidAWpfmRwSRdImifGUCAb9HeAqTYFXWeQk=
```

Just know that something in that version of rustup changed or sha is outdated, so, just copy whatever
shown in `got` and place that in both `default.nix` and `shell.nix` at:

```
  # Rust Toolchain via fenix
  toolchain = fenix.packages.${pkgs.system}.fromToolchainFile {
    file = ./rust-toolchain.toml;

    # Bla bla bla bla bla, bla bla bla.
    #                     REPLACE THIS LONG THING!
    sha256 = "sha256-Hn2uaQzRLidAWpfmRwSRdImifGUCAb9HeAqTYFXWeQk=";
  };
```

[Xinux Community]: https://github.com/xinux-org
[available default options]: #available-default-options
