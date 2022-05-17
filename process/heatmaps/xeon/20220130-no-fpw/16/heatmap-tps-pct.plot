set terminal postscript eps size 6,6 enhanced color font 'Helvetica,12'
set output 'heatmap-tps-pct.eps'

set palette defined (0 "red", 0.5 "white", 1 "web-green")

set key off

# set labels for x/y axis to block sizes"
XTICS="1 2 4 8 16 32"
YTICS="1 2 4 8 16 32 64"

set for [i=1:words(XTICS)] xtics ( word(XTICS,i) i-1 )
set for [i=1:words(YTICS)] ytics ( word(YTICS,i) i-1 )

# don't show color scale next to the heatmap
unset colorbox

set multiplot layout 3, 2 rowsfirst


set title "scale 100, read-only"

plot "100-ro-tps-pct.data" matrix using 1:2:3 with image, \
     "100-ro-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale 100, read-write"

plot "100-rw-tps-pct.data" matrix using 1:2:3 with image, \
     "100-rw-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels


set title "scale 1000, read-only"

plot "1000-ro-tps-pct.data" matrix using 1:2:3 with image, \
     "1000-ro-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale 1000, read-write"

plot "1000-rw-tps-pct.data" matrix using 1:2:3 with image, \
     "1000-rw-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels


set title "scale 7500, read-only"

plot "7500-ro-tps-pct.data" matrix using 1:2:3 with image, \
     "7500-ro-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale 7500, read-write"

plot "7500-rw-tps-pct.data" matrix using 1:2:3 with image, \
     "7500-rw-tps-pct.data" matrix using 1:2:(sprintf("%g",$3)) with labels
