set terminal postscript eps size 6,3 enhanced color font 'Helvetica,12'
set output 'chart-wal-time-250.eps'

set key on

set title "scale 250, read-write"

plot "250-rw-1-8-wal-time.data" using 1:2 with lines title "1kB", \
     "250-rw-2-8-wal-time.data" using 1:2 with lines title "2kB", \
     "250-rw-4-8-wal-time.data" using 1:2 with lines title "4kB", \
     "250-rw-8-8-wal-time.data" using 1:2 with lines title "8kB", \
     "250-rw-16-8-wal-time.data" using 1:2 with lines title "16kB", \
     "250-rw-32-8-wal-time.data" using 1:2 with lines title "32kB"
