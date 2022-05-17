#!/bin/bash

PATH_OLD=$PATH
BUILD_DIR=/var/lib/postgresql/builds
LOG_DIR=/mnt/samsung/block-bench/logs

for dss in 1 4 8; do

	for dbs in 8 1 32 4 16 2; do

		for wbs in 8 1 64 16 4 32 2; do

			pushd ~/postgres

			BUILD="pg-$dbs-$wbs-$dss"
			mkdir $LOG_DIR/$BUILD

			./configure --prefix=$BUILD_DIR/$BUILD --enable-debug CFLAGS="-O2"  --with-blocksize=$dbs --with-wal-blocksize=$wbs --with-segsize=$dss > $LOG_DIR/$BUILD/configure.log 2>&1

			make -s clean > /dev/null 2>&1

			make -s -j4 install > $LOG_DIR/$BUILD/make.log 2>&1

			popd

			PATH=$BUILD_DIR/$BUILD/bin:$PATH_OLD

			for wss in 1 4 8 16 32 64 128; do

				RUNDIR="$BUILD-$wss"
				mkdir $LOG_DIR/$RUNDIR

				killall -9 postgres
				sleep 5

				rm -Rf /mnt/data/data
				pg_ctl -D /mnt/data/data -o "--wal-segsize=$wss" init > $LOG_DIR/$RUNDIR/initdb.log 2>&1

				cp postgresql.conf /mnt/data/data

				pg_ctl -D /mnt/data/data -l $LOG_DIR/$RUNDIR/pg.log -w start 2>&1

				ps ax > $LOG_DIR/$RUNDIR/ps.log 2>&1

				pg_config > $LOG_DIR/$RUNDIR/pg_config.log 2>&1

				dropdb test
				createdb test

				psql test < sql/schema.sql > $LOG_DIR/$RUNDIR/schema.log 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/load.sql > $LOG_DIR/$RUNDIR/load.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;copy;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/indexes.sql > $LOG_DIR/$RUNDIR/indexes.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;indexes;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/pkeys.sql > $LOG_DIR/$RUNDIR/pkeys.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;pkey;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test < sql/fkeys.sql > $LOG_DIR/$RUNDIR/fkeys.log 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;fkey;$d;$w" >> load.csv 2>&1

				s=`psql -t -A test -c "select extract(epoch from now())"`
				w=`psql -t -A test -c "select pg_current_wal_lsn()"`
				psql test -c "vacuum analyze" > /dev/null 2>&1
				d=`psql -t -A test -c "select extract(epoch from now()) - $s"`
				w=`psql -t -A test -c "select pg_wal_lsn_diff(pg_current_wal_lsn(), '$w')"`

				echo "$dbs;$wbs;$dss;$wss;analyze;$d;$w" >> load.csv 2>&1

				# run queries only for 16MB WAL segments
				if [ "$wss" == "16" ]; then

					for q in `ls queries`; do

						for r in `seq 1 3`; do

							s=`psql test -t -A -c "select extract(epoch from now())"`

							psql test < queries/$q >> $LOG_DIR/$RUNDIR/queries.log 2>&1

							t=`psql test -t -A -c "select extract(epoch from now()) - $s"`

							echo "$dbs;$wbs;$dss;$wss;$q;$r;$t" >> queries.csv 2>&1

						done

						echo "===== $q jit=$jit =====" >> $LOG_DIR/$RUNDIR/explain.log 2>&1

						psql test < explain/$q >> $LOG_DIR/$RUNDIR/explain.log 2>&1

					done

				fi

				pg_ctl -D /mnt/data/data -l $LOG_DIR/$RUNDIR/pg.log -w stop

			done

		done

	done

done
