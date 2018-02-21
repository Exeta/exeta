sudo su - postgres <<SUDO
psql <<PSQL
$(< plsh_functions.sql)
PSQL
SUDO
