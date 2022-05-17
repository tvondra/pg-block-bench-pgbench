#!/bin/bash

PATH_OLD=$PATH
BUILD_DIR=/var/lib/postgresql/builds
LOG_DIR=/mnt/samsung/block-bench/logs

JOBS=8
CLIENTS=32
DURATION_RO=900
DURATION_RW=1800
RUNS_RO=3
RUNS_RW=3

for wss in 16 1 512; do

	while read line; do

		IFS=" " read -a strarr <<< "$line"

		dbs="${strarr[0]}"
		wbs="${strarr[1]}"
		dss=1

		echo "----- wss $wss dbs $dbs wbs $wbs dss $dss -----"

			pushd ~/postgres

			BUILD="pg-$dbs-$wbs-$wss"
			mkdir $LOG_DIR/$BUILD

			./configure --prefix=$BUILD_DIR/$BUILD --enable-debug CFLAGS="-O2"  --with-blocksize=$dbs --with-wal-blocksize=$wbs > $LOG_DIR/$BUILD/configure.log 2>&1

			make -s clean > /dev/null 2>&1

			make -s -j4 install > $LOG_DIR/$BUILD/make.log 2>&1

			popd

			PATH=$BUILD_DIR/$BUILD/bin:$PATH_OLD


			killall -9 postgres
			sleep 5

			rm -Rf /mnt/data/data
			pg_ctl -D /mnt/data/data -o "--wal-segsize=$wss" init > $LOG_DIR/$BUILD/initdb.log 2>&1

			cp postgresql.conf /mnt/data/data

			pg_ctl -D /mnt/data/data -l $LOG_DIR/$BUILD/pg.log -w start 2>&1

			ps ax > $LOG_DIR/$BUILD/ps.log 2>&1

			pg_config > $LOG_DIR/$BUILD/pg_config.log 2>&1

			rm -Rf /mnt/samsung/bench/temp-tablespace
			mkdir /mnt/samsung/bench/temp-tablespace

			psql postgres -c "create tablespace tmptbs location '/mnt/samsung/bench/temp-tablespace'"
			psql postgres -c "alter system set temp_tablespaces='tmptbs'"
			psql postgres -c "select pg_reload_conf()"

			for scale in 100 1000 7500; do

				dropdb test
				createdb test

				mkdir $LOG_DIR/$BUILD/$scale

				t1=`date +%s`
				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				pgbench -i -s $scale test > $LOG_DIR/$BUILD/$scale/init.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`
				t2=`date +%s`

				echo "$t1;$t2;$dbs;$wbs;$wss;$scale;init;$d;$w" >> init.csv 2>&1

				t1=`date +%s`
				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				vacuumdb --freeze --min-xid-age=1 test > $LOG_DIR/$BUILD/$scale/vacuum.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`
				t2=`date +%s`

				echo "$t1;$t2;$dbs;$wbs;$wss;$scale;vacuum;$d;$w" >> init.csv 2>&1

				# read-only runs

				for r in `seq -s ' ' 1 $RUNS_RO`; do

					rm -f pgbench_log.*

					mkdir $LOG_DIR/$BUILD/$scale/run-ro-$r

					t1=`date +%s`
					st=`psql -t -A test -c "select sum(pg_table_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					si=`psql -t -A test -c "select sum(pg_indexes_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					sd=`psql -t -A test -c "select pg_database_size('test')"`

					echo "before;$st;$si;$sd" > $LOG_DIR/$BUILD/$scale/run-ro-$r/sizes.csv 2>&1

					ps ax | grep collect-stats | awk '{print $1}' | xargs kill > /dev/null 2>&1
					./collect-stats.sh $DURATION_RO $LOG_DIR/$BUILD/$scale/run-ro-$r &

					s=`psql -t -A test -c "select extract(epoch from now())"`
					w=`psql -t -A test -c "select pg_current_wal_lsn()"`

					if [ "$r" == "$RUNS_RO" ]; then
						# get sample of transactions from last run
						pgbench -n -M prepared -S -j $JOBS -c $CLIENTS -T $DURATION_RO -l --sampling-rate=0.01 test > $LOG_DIR/$BUILD/$scale/run-ro-$r/pgbench.log 2>&1

						tar -czf $LOG_DIR/$BUILD/$scale/run-ro-$r/pgbench_log.tgz pgbench_log.*
						rm -f pgbench_log.*
					else
						pgbench -n -M prepared -S -j $JOBS -c $CLIENTS -T $DURATION_RO test > $LOG_DIR/$BUILD/$scale/run-ro-$r/pgbench.log 2>&1
					fi

					d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
					w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`
					t2=`date +%s`

					tps=`cat $LOG_DIR/$BUILD/$scale/run-ro-$r/pgbench.log | grep 'without initial' | awk '{print $3}'`

					echo "$t1;$t2;$dbs;$wbs;$wss;$scale;ro;$tps;$d;$w" >> results.csv 2>&1

					st=`psql -t -A test -c "select sum(pg_table_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					si=`psql -t -A test -c "select sum(pg_indexes_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					sd=`psql -t -A test -c "select pg_database_size('test')"`

					echo "after;$st;$si;$sd" >> $LOG_DIR/$BUILD/$scale/run-ro-$r/sizes.csv 2>&1

					sleep 60

				done

				# sync before the read-write phase
				psql test -c checkpoint > /dev/null 2>&1

				# read-write runs
				for r in `seq -s ' ' 1 $RUNS_RW`; do

					rm -f pgbench_log.*

					mkdir $LOG_DIR/$BUILD/$scale/run-rw-$r

					t1=`date +%s`
					st=`psql -t -A test -c "select sum(pg_table_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					si=`psql -t -A test -c "select sum(pg_indexes_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					sd=`psql -t -A test -c "select pg_database_size('test')"`

					echo "before;$st;$si;$sd" > $LOG_DIR/$BUILD/$scale/run-rw-$r/sizes.csv 2>&1

					ps ax | grep collect-stats | awk '{print $1}' | xargs kill > /dev/null 2>&1
					./collect-stats.sh $DURATION_RW $LOG_DIR/$BUILD/$scale/run-rw-$r &

					s=`psql -t -A test -c "select extract(epoch from now())"`
					w=`psql -t -A test -c "select pg_current_wal_lsn()"`

					if [ "$r" == "$RUNS_RW" ]; then
						# get sample of transactions from last run
						pgbench -n -M prepared -N -j $JOBS -c $CLIENTS -T $DURATION_RW -l --sampling-rate=0.01 test > $LOG_DIR/$BUILD/$scale/run-rw-$r/pgbench.log 2>&1

						tar -czf $LOG_DIR/$BUILD/$scale/run-rw-$r/pgbench_log.tgz pgbench_log.*
						rm -f pgbench_log.*
					else
						pgbench -n -M prepared -N -j $JOBS -c $CLIENTS -T $DURATION_RW test > $LOG_DIR/$BUILD/$scale/run-rw-$r/pgbench.log 2>&1
					fi

					d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
					w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`
					t2=`date +%s`

					tps=`cat $LOG_DIR/$BUILD/$scale/run-rw-$r/pgbench.log | grep 'without initial' | awk '{print $3}'`

					echo "$t1;$t2;$dbs;$wbs;$wss;$scale;rw;$tps;$d;$w" >> results.csv 2>&1

					st=`psql -t -A test -c "select sum(pg_table_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					si=`psql -t -A test -c "select sum(pg_indexes_size(oid)) from pg_class where relnamespace = 2200 and relkind = 'r'"`
					sd=`psql -t -A test -c "select pg_database_size('test')"`

					echo "after;$st;$si;$sd" >> $LOG_DIR/$BUILD/$scale/run-rw-$r/sizes.csv 2>&1

					sleep 60

				done

			done

			pg_ctl -D /mnt/data/data -l $LOG_DIR/$BUILD/pg.log -w stop

	done < list-pgbench.txt

done
