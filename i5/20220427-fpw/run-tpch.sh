#!/bin/bash

PATH_OLD=$PATH
BUILD_DIR=/var/lib/postgresql/builds
LOG_DIR=/var/lib/postgresql/block-bench-2/logs
DATADIR=/mnt/raid/data-tpch

#for dss in 1; do

#	for dbs in 8 1 32 4 16 2; do

#		for wbs in 8 1 64 16 4 32 2; do


for wss in 16 1 512; do

	while read line; do

        	IFS=" " read -a strarr <<< "$line"

	        dbs="${strarr[0]}"
	        wbs="${strarr[1]}"
		dss=1

	        echo "----- wss $wss dbs $dbs wbs $wbs -----"

			pushd ~/postgres

			BUILD="pg-$dbs-$wbs-$wss"
			mkdir $LOG_DIR/$BUILD

			./configure --prefix=$BUILD_DIR/$BUILD --enable-debug CFLAGS="-O2"  --with-blocksize=$dbs --with-wal-blocksize=$wbs --with-segsize=$dss > $LOG_DIR/$BUILD/configure.log 2>&1

			make -s clean > /dev/null 2>&1

			make -s -j4 install > $LOG_DIR/$BUILD/make.log 2>&1

			popd

			PATH=$BUILD_DIR/$BUILD/bin:$PATH_OLD

#			for wss in 1 16 512; do

				RUNDIR="$BUILD-$wss"
				mkdir $LOG_DIR/$RUNDIR

				killall -9 postgres
				sleep 5

				rm -Rf $DATADIR
				pg_ctl -D $DATADIR -o "--wal-segsize=$wss" init > $LOG_DIR/$RUNDIR/initdb.log 2>&1

				cp postgresql.conf $DATADIR

				pg_ctl -D $DATADIR -l $LOG_DIR/$RUNDIR/pg.log -w start 2>&1

				ps ax > $LOG_DIR/$RUNDIR/ps.log 2>&1

				pg_config > $LOG_DIR/$RUNDIR/pg_config.log 2>&1

				# create temp tablespace
				# rm -Rf /mnt/samsung/bench/temp-tablespace
				# mkdir /mnt/samsung/bench/temp-tablespace

				# psql postgres -c "create tablespace tmptbs location '/mnt/samsung/bench/temp-tablespace'"
				# psql postgres -c "alter system set temp_tablespaces='tmptbs'"
				# psql postgres -c "select pg_reload_conf()"

				dropdb --if-exists test
				createdb test

				psql test < sql/schema.sql > $LOG_DIR/$RUNDIR/schema.log 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/load.sql > $LOG_DIR/$RUNDIR/load.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;copy;$s;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/indexes.sql > $LOG_DIR/$RUNDIR/indexes.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;indexes;$s;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/pkeys.sql > $LOG_DIR/$RUNDIR/pkeys.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;pkey;$s;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/fkeys.sql > $LOG_DIR/$RUNDIR/fkeys.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;fkey;$s;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test -c "vacuum analyze" > /dev/null 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;analyze;$s;$d;$w" >> load.csv 2>&1

				st=`psql -t -A test -c "select sum(pg_table_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
				si=`psql -t -A test -c "select sum(pg_indexes_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
				sd=`psql -t -A test -c "select pg_database_size('test')"`

				echo "$dbs;$wbs;$dss;$wss;$st;$si;$sd" >> size.csv 2>&1

				# run queries only for 16MB WAL segments
				# if [ "$wss" == "16" ]; then

					mkdir -p $LOG_DIR/$RUNDIR/explains $LOG_DIR/$RUNDIR/results

					# run just the 22 standard queries, ignore the flattened variants etc.
					for q in `seq 1 22`; do

						# restart the server before each query, drop caches
                                                pg_ctl -D $DATADIR -l $LOG_DIR/$RUNDIR/pg.log -w restart
						sudo ./drop-caches.sh

						# do the plain explain
						sed 's/EXPLAIN_COMMAND/explain (costs off)/g' explain/$q.sql | psql test >> $LOG_DIR/$RUNDIR/explains/$q.log 2>&1

						# calculate hash of the explain, so that we can compare later
						hp=`md5sum $LOG_DIR/$RUNDIR/explains/$q.log | awk '{print $1}'`

						# restart the server again - some of the explains may create objects etc.
						pg_ctl -D $DATADIR -l $LOG_DIR/$RUNDIR/pg.log -w restart
						sudo ./drop-caches.sh

						# now do three runs for the query
						for r in `seq 1 3`; do

							s=`psql test -t -A -c "select extract(epoch from now())"`

							psql test < queries/$q.sql >> $LOG_DIR/$RUNDIR/results/$q.$r.log 2>&1

							t=`psql test -t -A -c "select extract(epoch from now()) - $s"`

							# calculate hash of the result, so that we can compare later
							hr=`md5sum $LOG_DIR/$RUNDIR/results/$q.$r.log | awk '{print $1}'`

							# we assume the plans do not change
							echo "$dbs;$wbs;$dss;$wss;$q;$r;$s;$t;$hp;$hr" >> queries.csv 2>&1

						done

					done

				# fi

				pg_ctl -D $DATADIR -l $LOG_DIR/$RUNDIR/pg.log -w stop

#			done

#		done

	done < list-tpch.txt

done
