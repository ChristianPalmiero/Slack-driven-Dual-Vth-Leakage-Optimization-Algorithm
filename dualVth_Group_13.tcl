# res leakage_opt -arrivalTime 1 -criticalPaths 300 -slackWin 0.1
proc leakage_opt {-arrivalTime arrivalTime -criticalPaths criticalPaths -slackWin slackWin} {

suppress_message TIM-104

# start time in ms
set startTime [clock milliseconds]

# global vars
global ordered_names
global HVT_lib
global LVT_lib
global hvt_swapped
global newZero

# this procedure extracts the leakage power and convert it in nW
proc extract_leakage {} {
  set report_text ""  ; # Contains the output of the report_power command
  set lnr 3           ; # Leakage info is in the 2nd line from the bottom
  set wnr 5           ; # Leakage info is the 6th word in the $lnr line
  redirect -variable report_text {report_power}
  set report_text [split $report_text "\n"]
  set result [list]
  set number [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] $wnr]
  set unit [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] [expr $wnr + 1]]
  # Convert the number in nW
  switch $unit {
        W {
                set number [expr $number * 10e9]
        }
        uW {
                set number [expr $number * 10e3]
        }
        mW {
                set number [expr $number * 10e6]
        }
  }
  return $number
}

# this procedure extracts the LVT and the HVT cells percentages
proc vth_perc {} {
  set report_text ""   ; # Contains the output of the report_threshold_voltage_grou[ command
  set lnr 13           ; #  info is in the 12th line from the bottom
  set wnr 2            ; #  info is the 3rd word in the $lnr line
  redirect -variable report_text {report_threshold_voltage_group}
  set report_text [split $report_text "\n"]
  set result [list]
  lappend result [regsub -all {\(|\)|%} [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] $wnr] ""]
  lappend result [regsub -all {\(|\)|%} [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - [expr $lnr +1]]]] $wnr] ""]
  return $result
}

# swap n cells from LVT to HVT ( n = end - start )
proc swap {start end} {
	for {set i $start} {$i < $end} {incr i} {
		global ordered_names
		global HVT_lib
		global LVT_lib
		global hvt_swapped
		global newZero
		set cell [lindex $ordered_names $i]
		set cell_refname [get_attribute $cell ref_name]
		set refname_wblanks [regsub -all {\_} $cell_refname " "]
		scan $refname_wblanks %s%s%s refnam reftyp refdim	
	    	set HVtype "_LH_"
		set LVtype "_LL_"
		set new_cell $refnam$HVtype$refdim 
		size_cell $cell $HVT_lib$new_cell
		lappend hvt_swapped $cell
		set full [get_attribute $cell full_name]
		set slack [get_attribute [get_timing_paths -through "${full}/Z"] slack]
		if { $slack < [expr 0 + $newZero]} {
			size_cell $cell $LVT_lib$refnam$LVtype$refdim
			set hvt_swapped [lreplace $hvt_swapped end end]
		}
	}
}

# swap back cells with smaller size
proc backtrack {swin critpath} {
	global LVT_lib
	global hvt_swapped
	global newZero	

	# order hvt_swapped list by decreasing size 
	set cellname_list [list]
	set size_list [list]
	set container [list]
	foreach point $hvt_swapped {
        	lappend cellname_list $point
        	set current_size [lindex [split [get_attribute $point ref_name] 'X'] end]
        	lappend size_list $current_size
		set sub_list [list]
        	lappend sub_list $point
       		lappend sub_list $current_size
        	lappend container $sub_list
	}	
	set sorted_swapped [lsort -real -decreasing -index 1 $container]	
	set hvt_swapped [list]
	foreach point $sorted_swapped {
		lappend hvt_swapped [lindex $point 0]	
	}

	while {1} {
		set cell [lindex $hvt_swapped end]
		set candidate [get_attribute $cell ref_name]
		set refname_wblanks [regsub -all {\_} $candidate " "]
		scan $refname_wblanks %s%s%s refnam reftyp refdim
		set typ "_LL_"
		set new_cell $refnam$typ$refdim
		size_cell $cell $LVT_lib$new_cell
		set hvt_swapped [lreplace $hvt_swapped end end]
		set numCriticalPaths [sizeof_collection [get_timing_paths -slack_greater_than [expr 0 + $newZero] -slack_lesser_than [expr $swin + $newZero] -nworst [expr $critpath + 1]]]
		if { $numCriticalPaths < $critpath } {
			break
		}
	}		
}

## res list will contain the result of the algorithm
set res [list 0 0 0 0]

# new zero
set newZero [expr [get_attribute [get_timing_paths] required] - $arrivalTime]

## check for feasible conditions
# bad option formats 
if {
	${-arrivalTime} != "-arrivalTime"
	|| ${-slackWin} != "-slackWin"
	|| ${-criticalPaths} != "-criticalPaths"
} then {
	return $res
}

# parameters not positive
if {
	$arrivalTime <= 0
	|| $slackWin <= 0
	|| $criticalPaths <= 0
} then {
	return $res	 
}

# if user arrival time is less than the wc_at (all LVTs, so this is the fastest cell config for the critical path) request is unfeasible because no change 
# on the critical path can lower its arrival time to reach such value.
set wc_at [get_attribute [get_timing_paths] arrival]
if {$wc_at > $arrivalTime} {
	return $res
}

# the user requests X paths to be in the slack window but our all-LVT design already has more than X paths in this window
set numCriticalPaths [sizeof_collection [get_timing_paths -slack_greater_than [expr 0 + $newZero] -slack_lesser_than [expr $slackWin + $newZero] -nworst $criticalPaths]]
if {$numCriticalPaths >= $criticalPaths} {
	return $res
}
## end of input checks

# starting leakage power percentage
set leak_start [extract_leakage]
# set various vars/lists we need
set pointcell_list [get_cells]
set LVT_lib  "CORE65LPLVT_nom_1.00V_25C.db:CORE65LPLVT/"
set HVT_lib  "CORE65LPHVT_nom_1.00V_25C.db:CORE65LPHVT/"
set cellname_list [list]
set wc_at_list [list]
set path_list [list]
set container [list]
set hvt_swapped [list]

# order the cell list by worst case arrival time
foreach_in_collection point $pointcell_list {
	set current_cell [get_attribute $point full_name]
	lappend cellname_list $current_cell
	set current_path [get_timing_paths -through "${current_cell}/Z"]
	lappend path_list $current_path
	set wc_at [get_attribute $current_path arrival]
	lappend wc_at_list $wc_at
	set sub_list [list]
	lappend sub_list $current_cell
	lappend sub_list $wc_at
	lappend container $sub_list
}

set sorted_container [lsort -real -index 1 $container]
set ordered_names [list]
set ordered_wcat [list]
foreach bundle $sorted_container {
	lappend ordered_names [lindex $bundle 0]
	lappend ordered_wcat [lindex $bundle 1]
}

# lower bound for ending the script = 90% of input critical paths
set lowerBound [expr $criticalPaths*90/100]
set startIndex 0
# the step of the algorithm is 10% of available cells
set indexStep [expr [llength $ordered_names]/10]
set endIndex $indexStep 

set algo_pass 0

while {1} {	
	swap $startIndex $endIndex
	set startIndex [expr $endIndex + 1]
	set endIndex [expr $endIndex + $indexStep]
	set numCriticalPaths [sizeof_collection [get_timing_paths -slack_greater_than [expr 0 + $newZero] -slack_lesser_than [expr $slackWin + $newZero] -nworst [expr $criticalPaths + 1]]]
	if { $numCriticalPaths > $criticalPaths  } {
		backtrack $slackWin $criticalPaths	
	}

	set numCriticalPaths [sizeof_collection [get_timing_paths -slack_greater_than [expr 0 + $newZero] -slack_lesser_than [expr $slackWin + $newZero] -nworst [expr $criticalPaths + 1]]]
	if { $lowerBound <= $numCriticalPaths && $numCriticalPaths <= $criticalPaths} {
		break
	}
	if { $endIndex > [llength $ordered_names] } {
		return $res
	}
	incr algo_pass
}

## insert data into the return list
# end time in ms
set endTime [clock milliseconds]
# ending leakage power percentage
set leak_end [extract_leakage]
set res [list]
# First parameter: leakage power saving
lappend res [expr double(round(100 * [expr 100 - ($leak_end*100/$leak_start)]))/100]
# Second parameter: execution time in seconds
set total_time [expr ($endTime - $startTime)]
lappend res [expr {double(round(10*[expr {double(round($total_time))/1000}]))/10}]
set percentages [vth_perc]
# Thirs and fourth parameters: LVT %, HVT %
lappend res [expr {double(round(100*[expr [lindex $percentages 0]/100]))/100}]	; # LVT %
lappend res [expr {double(round(100*[expr [lindex $percentages 1]/100]))/100}]  ; # HVT %
return $res
}	
