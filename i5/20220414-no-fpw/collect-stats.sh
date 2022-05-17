#!/bin/sh

COUNT=$1
OUTDIR=$2
TIME=`date +%s`
END=$(($TIME + $COUNT))
RUN=1

psql test -A -c "select $RUN as run, extract(epoch from now()) AS epoch, now() AS ts, * from pg_stat_database where datname = 'test'" | head -n 2 >> $OUTDIR/stat-database.csv 2>&1
psql test -A -c "select $RUN as run, extract(epoch from now()) AS epoch, now() AS ts, pg_current_wal_lsn() AS lsn, * from pg_stat_bgwriter" | head -n 2 >> $OUTDIR/stat-bgwriter.csv 2>&1

while [ $TIME -lt $END ]; do

	sleep 1

	psql test -t -A -c " select $RUN, extract(epoch from now()) AS epoch, now() AS ts, * from pg_stat_database where datname = 'test'" >> $OUTDIR/stat-database.csv 2>&1
	psql test -t -A -c "select $RUN, extract(epoch from now()) AS epoch, now() AS ts, pg_current_wal_lsn() AS lsn, * from pg_stat_bgwriter" >> $OUTDIR/stat-bgwriter.csv 2>&1

	TIME=`date +%s`
	RUN=$((RUN+1))

done
