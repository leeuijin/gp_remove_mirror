#!/bin/bash
# Works only with Greenplum v6 and later.

set -e

check_health()
{
	count=$(psql -t -A -c "select count(*) from gp_segment_configuration where preferred_role <> role and role = 'p' and status = 'u';")
	if [ "$count" -eq "0" ]; then
		echo "Database healthy.  Continuing..."
	else
		echo "ERROR!  Please run gpstate and fix any segments that are down."
	fi
}
start_normal()
{
	counter=$(ps -ef | grep postgres | grep "\-D" | wc -l)

	if [ "$counter" -eq "0" ]; then
		gpstart -a
	else
		echo "Database already started."
	fi
}
stop_normal()
{
	counter=$(ps -ef | grep postgres | grep "\-D" | wc -l)

	if [ "$counter" -eq "0" ]; then
		echo "Database already stopped."
	else
		gpstop -a -M fast
	fi
}
start_admin_mode()
{
	gpstart -am << EOF
y
EOF
}
alter_database()
{
	PGOPTIONS='-c gp_session_role=utility' psql -c "SET allow_system_table_mods=y; delete from gp_segment_configuration where role = 'm';"
	PGOPTIONS='-c gp_session_role=utility' psql -c "SET allow_system_table_mods=y; update gp_segment_configuration set mode = 'n';"
	PGOPTIONS='-c gp_session_role=utility' psql -c "SET allow_system_table_mods=y; update gp_segment_configuration set mode = 's' where content = '-1';"
}
stop_admin_mode()
{
	gpstop -am
}

start_normal
check_health
stop_normal
start_admin_mode
alter_database
stop_admin_mode
start_normal
