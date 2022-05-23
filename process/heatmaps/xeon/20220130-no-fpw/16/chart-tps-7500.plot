set terminal postscript eps size 6,3 enhanced color font 'Helvetica,12'
set output 'chart-tps-time-7500.eps'

set key on

set title "scale 7500, read-write"

plot "7500-rw-1-8-tps-time.data" using 1:2 with lines title "1kB", \
     "7500-rw-2-8-tps-time.data" using 1:2 with lines title "2kB", \
     "7500-rw-4-8-tps-time.data" using 1:2 with lines title "4kB", \
     "7500-rw-8-8-tps-time.data" using 1:2 with lines title "8kB", \
     "7500-rw-16-8-tps-time.data" using 1:2 with lines title "16kB", \
     "7500-rw-32-8-tps-time.data" using 1:2 with lines title "32kB"
