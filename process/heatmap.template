set terminal postscript eps size 6,6 enhanced color font 'Helvetica,12'
set output 'heatmap-DATASET.eps'

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


set title "scale SCALE_A, read-only"

plot "SCALE_A-ro-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_A-ro-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale SCALE_A, read-write"

plot "SCALE_A-rw-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_A-rw-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels


set title "scale SCALE_B, read-only"

plot "SCALE_B-ro-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_B-ro-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale SCALE_B, read-write"

plot "SCALE_B-rw-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_B-rw-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels


set title "scale SCALE_C, read-only"

plot "SCALE_C-ro-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_C-ro-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels

set title "scale SCALE_C, read-write"

plot "SCALE_C-rw-DATASET.data" matrix using 1:2:3 with image, \
     "SCALE_C-rw-DATASET.data" matrix using 1:2:(sprintf("%g",$3)) with labels
