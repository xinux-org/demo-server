####################################################################
# Create a diretory for the generated artifacts
####################################################################

mkdir .nix-shell
export NIX_SHELL_DIR=$PWD/.nix-shell

####################################################################
# Put the PostgreSQL databases in the project diretory.
####################################################################

export PGDATA=$NIX_SHELL_DIR/db

####################################################################
# Clean up after exiting the Nix shell using `trap`.
# ------------------------------------------------------------------
# Idea taken from
# https://unix.stackexchange.com/questions/464106/killing-background-processes-started-in-nix-shell
# and the answer provides a way more sophisticated solution.
#
# The main syntax is `trap ARG SIGNAL` where ARG are the commands to
# be executed when SIGNAL crops up. See `trap --help` for more.
####################################################################

trap \
  "
    ######################################################
    # Stop PostgreSQL
    ######################################################

    pg_ctl -D $PGDATA stop

    ######################################################
    # Delete `.nix-shell` directory
    # ----------------------------------
    # The first  step is going  back to the  project root,
    # otherwise `.nix-shell`  won't get deleted.  At least
    # it didn't for me when exiting in a subdirectory.
    ######################################################

    cd $PWD
    rm -rf "$NIX_SHELL_DIR"
  " \
  EXIT

####################################################################
# If database is  not initialized (i.e., $PGDATA  directory does not
# exist), then set  it up. Seems superfulous given  the cleanup step
# above, but handy when one gets to force reboot the iron.
####################################################################

if ! test -d $PGDATA
then

  ######################################################
  # Init PostgreSQL
  ######################################################

  pg_ctl initdb -D  $PGDATA

  ######################################################
  # PORT ALREADY IN USE
  ######################################################
  # If another `nix-shell` is  running with a PostgreSQL
  # instance,  the logs  will show  complaints that  the
  # default port 5432  is already in use.  Edit the line
  # below with  a different  port number,  uncomment it,
  # and try again.
  ######################################################

  # sed -i "s|^#port.*$|port = 5433|" $PGDATA/postgresql.conf

fi

####################################################################
# Start PostgreSQL
# ==================================================================
# Setting all  necessary configuration  options via  `pg_ctl` (which
# is  basically  a wrapper  around  `postgres`)  instead of  editing
# `postgresql.conf` directly with `sed`. See docs:
#
# + https://www.postgresql.org/docs/current/app-pg-ctl.html
# + https://www.postgresql.org/docs/current/app-postgres.html
#
# See more on the caveats at
# https://discourse.nixos.org/t/how-to-configure-postgresql-declaratively-nixos-and-non-nixos/4063/1
# but recapping out of paranoia:
#
# > use `SHOW`  commands to  check the  options because  `postgres -C`
# > "_returns values  from postgresql.conf_" (which is  not changed by
# > supplying  the  configuration options  on  the  command line)  and
# > "_it does  not reflect  parameters supplied  when the  cluster was
# > started._"
#
# OPTION SUMMARY
# --------------------------------------------------------------------
#
#  + `unix_socket_directories`
#
#    > PostgreSQL  will  attempt  to create  a  pidfile  in
#    > `/run/postgresql` by default, but it will fail as it
#    > doesn't exist. By  changing the configuration option
#    > below, it will get created in $PGDATA.
#
#   + `listen_addresses`
#
#     > In   tandem  with   edits   in  `pg_hba.conf`   (see
#     > `HOST_COMMON`  below), it  configures PostgreSQL  to
#     > allow remote connections (otherwise only `localhost`
#     > will get  authenticated and the rest  of the traffic
#     > discarded).
#     >
#     > NOTE: the  edit  to  `pga_hba.conf`  needs  to  come
#     >       **before**  `pg_ctl  start`  (or  the  service
#     >       needs to be restarted otherwise), because then
#     >       the changes are not being reloaded.
#     >
#     > More info  on setting up and  troubleshooting remote
#     > PosgreSQL connections (these are  all mirrors of the
#     > same text; again, paranoia):
#     >
#     >   + https://stackoverflow.com/questions/24504680/connect-to-postgres-server-on-google-compute-engine
#     >   + https://stackoverflow.com/questions/47794979/connecting-to-postgres-server-on-google-compute-engine
#     >   + https://medium.com/scientific-breakthrough-of-the-afternoon/configure-postgresql-to-allow-remote-connections-af5a1a392a38
#     >   + https://gist.github.com/toraritte/f8c7fe001365c50294adfe8509080201#file-configure-postgres-to-allow-remote-connection-md

HOST_COMMON="host\s\+all\s\+all"
sed -i "s|^$HOST_COMMON.*127.*$|host all all 0.0.0.0/0 trust|" $PGDATA/pg_hba.conf
sed -i "s|^$HOST_COMMON.*::1.*$|host all all ::/0 trust|"      $PGDATA/pg_hba.conf

  #  + `log*`
  #
  #    > Setting up basic logging,  to see remote connections
  #    > for example.
  #    >
  #    > See the docs for more:
  #    > https://www.postgresql.org/docs/current/runtime-config-logging.html

pg_ctl                                                  \
  -D $PGDATA                                            \
  -l $PGDATA/postgres.log                               \
  -o "-c unix_socket_directories='$PGDATA'"             \
  -o "-c listen_addresses='*'"                          \
  -o "-c log_destination='stderr'"                      \
  -o "-c logging_collector=on"                          \
  -o "-c log_directory='log'"                           \
  -o "-c log_filename='postgresql-%Y-%m-%d_%H%M%S.log'" \
  -o "-c log_min_messages=info"                         \
  -o "-c log_min_error_statement=info"                  \
  -o "-c log_connections=on"                            \
  start

####################################################################
# Create necessary databases & users.
# ------------------------------------------------------------------
# Basically, for this config, I set all credentials to "temp",
# you're welcomed to change it to what the fuckever as you wish.
#
# Also, before bootstrapping credentials, it creates database
# for current running user as it doesn't get done by default.
####################################################################

export DB_USERNAME=temp
export DB_PASSWORD=temp
export DB_DATABASE=temp

createdb $(whoami) --host=$PGDATA

createdb $DB_DATABASE --host=$PGDATA
createuser $DB_USERNAME --host=$PGDATA
psql --host=$PGDATA --username=$(whoami) --dbname=$(whoami) --port=5432 \
  -c "alter user $DB_USERNAME with encrypted password '$DB_PASSWORD';"
psql --host=$PGDATA --username=$(whoami) --dbname=$(whoami) --port=5432 \
  -c "grant all privileges on database $DB_DATABASE to $DB_USERNAME;"

####################################################################
# Prepare .env file for the server
####################################################################

if [ ! -f .env ]; then

  ######################################################
  # Generate and warn user about defaulted .env file
  ######################################################

  touch .env
  echo "I'm setting temporary local dev settings for now."
  echo "If any changes wanted, feel free to change or do what the fuckever you want with .env file!";

  ######################################################
  # Write defaulted settings to .env file
  ######################################################

  echo "# Generated with shell.nix (L251 for more)" > .env;
  echo "URL=127.0.0.1" > .env;
  echo "PORT=8001" > .env;
  echo "DATABASE_URL=postgres://$(whoami):$(whoami)@localhost/temp" > .env;

else
  source .env;
fi
