#!/bin/bash

DBNAME=block_bench_results

# get parent directory
ROOTDIR=`realpath $0`
ROOTDIR=`dirname $ROOTDIR`
ROOTDIR=`dirname $ROOTDIR`

echo "top directory: $ROOTDIR"

echo "processing sysstat data"

# remove stale generated files (if any)
rm -f *.tmp

for m in i5 xeon; do

	if [ "$m" == "i5" ]; then
		device="md0"	# RAID
		# device="\(sd[abcdef]1\|md0\)"	# devices + RAID
	else
		device="dev259-1"	# nvme0n1p1
	fi

	# load db stats from all the runs

	for r in `ls $ROOTDIR/$m/`; do

		echo $r

		d=`echo $r | sed 's/results-//'`

		sed "s/^/$d;$m;/g" $ROOTDIR/$m/$r/results.csv >> results.tmp

		for dbs in 1 2 4 8 16 32; do

			for wbs in 1 2 4 8 16 32 64; do

				for wss in 1 16 512; do

					x="pg-$dbs-$wbs-$wss"

					if [ ! -d "$ROOTDIR/$m/$r/logs/$x/" ]; then
						continue
					fi

					for s in `ls $ROOTDIR/$m/$r/logs/$x/ | grep '^[0-9]\+$'`; do

						for t in ro rw; do

							for u in 1 2 3; do

								tail -n +2 $ROOTDIR/$m/$r/logs/$x/$s/run-$t-$u/stat-database.csv | grep -F '|' | sed "s/^/$m|$dbs|$wbs|$wss|$s|$t|$u|/g" >> stat-database.tmp
								tail -n +2 $ROOTDIR/$m/$r/logs/$x/$s/run-$t-$u/stat-bgwriter.csv | grep -F '|' | sed "s/^/$m|$dbs|$wbs|$wss|$s|$t|$u|/g" >> stat-bgwriter.tmp

							done

						done

					done

				done

			done

		done

		for f in `ls $ROOTDIR/$m/$r/sysstat/ | grep gz`; do

			echo "processing sysstat data $m / $f"

			gunzip -c $ROOTDIR/$m/$r/sysstat/$f > sysstat.tmp

			t=`S_TIME_FORMAT=ISO sar -f sysstat.tmp | head -n 1 | awk '{print $4}'`

			S_TIME_FORMAT=ISO sar -f sysstat.tmp -d -p | grep $device | grep -v Average | sed 's/\s\+/\t/g' | sed "s/^/$m	$t /g" | tail -n +4 >> sysstat-disk.tmp

			S_TIME_FORMAT=ISO sar -f sysstat.tmp -u | grep -v Average | sed 's/\s\+/\t/g' | sed "s/^/$m	$t /g" | tail -n +4 >> sysstat-cpu.tmp

			S_TIME_FORMAT=ISO sar -f sysstat.tmp -b | grep -v Average | sed 's/\s\+/\t/g' | sed "s/^/$m	$t /g" | tail -n +4 >> sysstat-io.tmp

			S_TIME_FORMAT=ISO sar -f sysstat.tmp -r | grep -v Average | sed 's/\s\+/\t/g' | sed "s/^/$m	$t /g" | tail -n +4 >> sysstat-mem.tmp

			rm sysstat.tmp

		done

	done

done


dropdb --if-exists $DBNAME
createdb $DBNAME

psql $DBNAME < stats.sql

cat results.tmp | psql $DBNAME -c "copy results (run, machine, start_time, end_time, data_block, wal_block, wal_segment, scale, mode, tps, time, wal_bytes) from stdin with (format csv, delimiter ';')"

# remove incomplete runs (disk space, ...)"
psql $DBNAME -c "delete from results where mode = 'ro' and time < 900"
psql $DBNAME -c "delete from results where mode = 'rw' and time < 1800"

cat stat-bgwriter.tmp | psql $DBNAME -c "copy load_stats_bgwriter from stdin with (format csv, delimiter '|')"
cat stat-database.tmp | psql $DBNAME -c "copy load_stats_database from stdin with (format csv, delimiter '|')"

cat sysstat-cpu.tmp | psql $DBNAME -c "copy load_stats_cpu from stdin with (format csv, delimiter E'\t')"
cat sysstat-io.tmp   | psql $DBNAME -c "copy load_stats_io from stdin with (format csv, delimiter E'\t')"
cat sysstat-disk.tmp | psql $DBNAME -c "copy load_stats_disk from stdin with (format csv, delimiter E'\t')"
cat sysstat-mem.tmp  | psql $DBNAME -c "copy load_stats_mem from stdin with (format csv, delimiter E'\t')"

psql $DBNAME -c "vacuum analyze"

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        ts,
        cpu_number,
        user_time,
        nice_time,
        system_time,
        iowait_time,
        steal_time,
        idle_time
    from load_stats_cpu)
insert into stats_cpu select * from data where run_id is not null
EOF

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        ts,
        device,
        tps,
        rkbps,
        wkbps,
        dkbps,
        areqsz,
        aqusz,
        await,
        util
    from load_stats_disk)
insert into stats_disk select * from data where run_id is not null
EOF

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        ts,
        tps,
        rtps,
        wtps,
        dtps,
        breadps,
        bwrtnps,
        bdscdps
    from load_stats_io)
insert into stats_io select * from data where run_id is not null
EOF

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        ts,
        kbmemfree,
        kbavail,
        kbmemused,
        memused_pct,
        kbbuffers,
        kbcached,
        kbcommit,
        commit_pct,
        kbactive,
        kbinact,
        kbdirty
    from load_stats_mem)
insert into stats_mem select * from data where run_id is not null
EOF

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        epoch,
        ts,
        lsn,
        checkpoints_timed,
        checkpoints_req,
        checkpoint_write_time,
        checkpoint_sync_time,
        buffers_checkpoint,
        buffers_clean,
        maxwritten_clean,
        buffers_backend,
        buffers_backend_fsync,
        buffers_alloc,
        stats_reset
    from load_stats_bgwriter)
insert into stats_bgwriter select * from data where run_id is not null
EOF

psql $DBNAME <<EOF
with data as (
    select
        lookup_run_id(machine, ts) as run_id,
        epoch,
        ts,
        datid,
        datname,
        numbackends,
        xact_commit,
        xact_rollback,
        blks_read,
        blks_hit,
        tup_returned,
        tup_fetched,
        tup_inserted,
        tup_updated,
        tup_deleted,
        conflicts,
        temp_files,
        temp_bytes,
        deadlocks,
        checksum_failures,
        checksum_last_failure,
        blk_read_time,
        blk_write_time,
        session_time,
        active_time,
        idle_in_transaction_time,
        sessions,
        sessions_abandoned,
        sessions_fatal,
        sessions_killed,
        stats_reset
    from load_stats_database)
insert into stats_database select * from data where run_id is not null
EOF

psql $DBNAME -c "vacuum analyze"

psql $DBNAME -A -c "select * from results_with_stats" > results_with_stats.csv
psql $DBNAME -A -c "select * from results_with_stats_agg" > results_with_stats_aggregated.csv
psql $DBNAME -A -c "select * from results_with_stats_agg_corrected" > results_with_stats_aggregated_corrected.csv

# rm *.tmp
