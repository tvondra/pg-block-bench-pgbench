for wss in 16 1 128; do

        for dbs in 8 1 32 4 16 2; do

                for wbs in 8 1 64 16 4 32 2; do

			echo $RANDOM $wss $dbs $wbs

		done

	done

done
