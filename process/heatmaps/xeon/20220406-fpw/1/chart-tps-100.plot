set terminal postscript eps size 6,3 enhanced color font 'Helvetica,12'
set output 'chart-tps-time-100.eps'

set key on

set title "scale 100, read-write"

plot "100-rw-1-8-tps-time.data" using 1:2 with lines title "1kB", \
     "100-rw-2-8-tps-time.data" using 1:2 with lines title "2kB", \
     "100-rw-4-8-tps-time.data" using 1:2 with lines title "4kB", \
     "100-rw-8-8-tps-time.data" using 1:2 with lines title "8kB", \
     "100-rw-16-8-tps-time.data" using 1:2 with lines title "16kB", \
     "100-rw-32-8-tps-time.data" using 1:2 with lines title "32kB"
