#!/usr/bin/bash

DBNAME=block_bench_results

# get parent directory
ROOTDIR=`realpath $0`
ROOTDIR=`dirname $ROOTDIR`
ROOTDIR=`dirname $ROOTDIR`

echo "top directory: $ROOTDIR"

echo "generating heatmaps"

# remove stale generated files (if any)
rm -Rf heatmaps
mkdir heatmaps

#
psql $DBNAME -c "create extension tablefunc"

for m in xeon; do

	for r in `ls $ROOTDIR/$m/`; do

		d=$r

		for wss in 1 16 512; do

			outdir="heatmaps/$m/$d/$wss"
			mkdir -p $outdir

			cp heatmap.template heatmap.plot

			rm -f scales.txt

			x="pg-8-8-$wss"

			# ignore cases not included in the run
			# echo "SELECT COUNT(*) FROM results WHERE machine = '$m' AND run = '$d' AND wal_segment = '$wss' LIMIT 1";
			c=`psql -t -A $DBNAME -c "SELECT COUNT(*) FROM results WHERE machine = '$m' AND run = '$d' AND wal_segment = '$wss' LIMIT 1"`
			if [ "$c" == "0" ]; then
				continue;
			fi;

			for s in `ls $ROOTDIR/$m/$r/logs/$x/ | grep '^[0-9]\+$'`; do

				echo $s >> scales.txt

				for t in ro rw; do

					psql -t -A -F ' ' $DBNAME > $s-$t-tps.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  tps::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-tps-pct.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  ((100.0 * tps) / base_tps)::int::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-wal.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  (wal_diff/1024/1024/1024)::int::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-wal-per-tps.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  (wal_diff/tps/seconds)::int::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-cache-hit-ratio.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  blks_hit_ratio::int::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-checkpoints.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  checkpoints_all::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-device-tps.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  dev_tps::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-device-kbps.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  dev_kbps::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-io-tps.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  io_tps::text as value
 FROM results_with_stats_agg
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF


					psql -t -A -F ' ' $DBNAME > $s-$t-wal-corrected.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  (wal_diff/1024/1024/1024)::int::text as value
 FROM results_with_stats_agg_corrected
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg_corrected ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-checkpoints-corrected.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  checkpoints_all::text as value
 FROM results_with_stats_agg_corrected
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg_corrected ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-device-tps-corrected.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  dev_tps::text as value
 FROM results_with_stats_agg_corrected
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg_corrected ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-device-kbps-corrected.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  dev_kbps::text as value
 FROM results_with_stats_agg_corrected
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg_corrected ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

					psql -t -A -F ' ' $DBNAME > $s-$t-io-tps-corrected.data <<EOF
SELECT " 1", " 2", " 4", " 8", "16", "32" FROM crosstab('SELECT
  lpad(wal_block::text,2) AS row_name,
  lpad(data_block::text,2) as category,
  io_tps::text as value
 FROM results_with_stats_agg_corrected
WHERE mode = ''$t'' AND machine = ''$m'' AND scale = $s AND run = ''$d'' AND wal_segment = ''$wss''
ORDER BY 1,2',
'SELECT DISTINCT lpad(data_block::text,2) FROM results_with_stats_agg_corrected ORDER BY 1'
) AS ct(category text, " 1" text, " 2" text, " 4" text, " 8" text, "16" text, "32" text)
EOF

				done

			done

			sort -n scales.txt > scales.sorted

			# first scale
			s=`cat scales.sorted | head -n 1`
			sed "s/SCALE_A/$s/g" heatmap.plot > heatmap.plot.tmp
			mv heatmap.plot.tmp heatmap.plot

			# second scale
			s=`cat scales.sorted | head -n 2 | tail -n 1`
			sed "s/SCALE_B/$s/g" heatmap.plot > heatmap.plot.tmp
			mv heatmap.plot.tmp heatmap.plot

			# third scale
			s=`cat scales.sorted | tail -n 1`
			sed "s/SCALE_C/$s/g" heatmap.plot > heatmap.plot.tmp
			mv heatmap.plot.tmp heatmap.plot

			for ds in "tps" "tps-pct" "wal" "wal-corrected" "wal-per-tps" "cache-hit-ratio" "checkpoints" "checkpoints-corrected" "device-tps" "device-tps-corrected" "device-kbps" "device-kbps-corrected" "io-tps" "io-tps-corrected"; do
				echo "===== $ds ====="
				sed "s/DATASET/$ds/g" heatmap.plot > heatmap-$ds.plot
				gnuplot heatmap-$ds.plot
			done

			mv *.data *.plot *.eps $outdir/

		done

	done

done
