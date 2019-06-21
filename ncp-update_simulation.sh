#!/bin/bash

  # Latest checkpoint is the version right before the latest cleanup of update.sh
  #latest_checkpoint="1.10.11" # Static insert now, fix later
  # Get the array of updates dir
  i=0
  while read line ; do
    updates_list[ $i ]="$line"
    (( i++ ))
  done < <( ls -1 updates_simulator | sort -V )

 echo "Updates directory:"
 for i in ${updates_list[*]} ; do
	 echo "${i}"
 done

  # The latest checkpoint is the newer version in updates dir
  en=${#updates_list[@]} # don't mind the names here
  ena=$(expr $en - 1) # They're fixed in ncp-update
  latest_checkpoint=${updates_list[$ena]}
  echo -e "\n===Latest Checkpoint is ${latest_checkpoint}==="
  # Compare current version with latest checkpoint to see if we need backwards updates
  MAJOR=$(echo ${latest_checkpoint} | cut -d'_' -f2 )
  MINOR=$(echo ${latest_checkpoint} | cut -d'_' -f3 )
  PATCH=$(echo ${latest_checkpoint} | cut -d'_' -f4 )

  # Test dynamically - the input is only for testing
  echo -e "\nInsert current version (example: 1.10.2)"
  read version
  
  MAJ=$( echo ${version} | cut -d. -f1 )
  MIN=$( echo ${version} | cut -d. -f2 )
  PAT=$( echo ${version} | cut -d. -f3 )

  # If the system is beyond the latest checkpoint there is no need to get in the loop
  BACKWARDS_UPDATES=false

  if [ "$MAJOR" -gt "$MAJ" ]; then
    BACKWARDS_UPDATES=true
  elif [ "$MAJOR" -eq "$MAJ" ] && [ "$MINOR" -gt "$MIN" ]; then
    BACKWARDS_UPDATES=true
  elif [ "$MAJOR" -eq "$MAJ" ] && [ "$MINOR" -eq "$MIN" ] && [ "$PATCH" -gt "$PAT" ]; then
    BACKWARDS_UPDATES=true
  fi

  if $BACKWARDS_UPDATES ; then
    echo -e "\nBackwards Updates Needed"
    # Execute a series of updates of older versions

    # Binary search to find the right checkpoint to begin the updates
    
    starting_checkpoint=0
    len=${#updates_list[@]}
    end_of_list=$(expr $len - 1)
    
    lower_bound=0
    upper_bound=$end_of_list
    while [ $lower_bound -le $upper_bound ]; do
      x=$(expr $upper_bound + $lower_bound)
      mid=$(expr $x / 2 )
      #Compare mid's version with current version
      MAJOR=$( echo ${updates_list[$mid]} | cut -d'_' -f2 )
      MINOR=$( echo ${updates_list[$mid]} | cut -d'_' -f3 )
      PATCH=$( echo ${updates_list[$mid]} | cut -d'_' -f4 )
      
      apply_update=false
      if [ "$MAJOR" -gt "$MAJ" ]; then
        apply_update=true
      elif [ "$MAJOR" -eq "$MAJ" ] && [ "$MINOR" -gt "$MIN" ]; then
        apply_update=true
      elif [ "$MAJOR" -eq "$MAJ" ] && [ "$MINOR" -eq "$MIN" ] && [ "$PATCH" -gt "$PAT" ]; then
        apply_update=true
      fi

      if $apply_update ; then 
      # Mid's version update is applicable to the current version
      # Check if the previous checkpoint (mid-1) has already been applied
        previous=$(expr $mid - 1)
        if [ "$mid" -gt 0 ] ; then
          #Compare previous's version with current version
          MAJOR_=$( echo ${updates_list[$previous]} | cut -d'_' -f2 )
          MINOR_=$( echo ${updates_list[$previous]} | cut -d'_' -f3 )
          PATCH_=$( echo ${updates_list[$previous]} | cut -d'_' -f4 )
      
          applied=true
          if [ "$MAJOR_" -gt "$MAJ" ]; then
            applied=false
          elif [ "$MAJOR_" -eq "$MAJ" ] && [ "$MINOR_" -gt "$MIN" ]; then
            applied=false
          elif [ "$MAJOR_" -eq "$MAJ" ] && [ "$MINOR_" -eq "$MIN" ] && [ "$PATCH_" -gt "$PAT" ]; then
            applied=false
          fi

	  # If the previous checkpoint has already been applied then mid is the beggining checkpoint for the current version
	  if $applied ; then
            starting_checkpoint=$mid
	    break
	  fi
        else
          # mid is at 0
	  starting_checkpoint=$mid
	  break
	fi
	# Continue searching
	upper_bound=$(expr $mid - 1)

      else #[ $item -gt ${arr[$mid]} ] ; then
	# Mid's version update is not applicable to the current version (has already been applied)
        # Check if the next checkpoint (mid+1) has already been applied
	next=$(expr $mid + 1)
        #Compare next's version with current version
        MAJOR_=$( echo ${updates_list[$next]} | cut -d'_' -f2 )
        MINOR_=$( echo ${updates_list[$next]} | cut -d'_' -f3 )
        PATCH_=$( echo ${updates_list[$next]} | cut -d'_' -f4 )
        
        applied=true
        if [ "$MAJOR_" -gt "$MAJ" ]; then
          applied=false
        elif [ "$MAJOR_" -eq "$MAJ" ] && [ "$MINOR_" -gt "$MIN" ]; then
          applied=false
        elif [ "$MAJOR_" -eq "$MAJ" ] && [ "$MINOR_" -eq "$MIN" ] && [ "$PATCH_" -gt "$PAT" ]; then
          applied=false
        fi

	if $applied ; then
	  # Continue searching
          lower_bound=$(expr $mid + 1)
	else
          # The next version is the starting checkpoint
	  starting_checkpoint=$next
	  break
	fi
      fi
    done


    echo -e "\n===Starting checkpoint is ${starting_checkpoint}: ${updates_list[${starting_checkpoint}]} ==="
    for(( i=${starting_checkpoint}; i<=${end_of_list}; i++)); do
      update_file=${updates_list[i]}
      #tag_update="v${MAJ}.${MIN}.${PAT}"
      #git checkout ${tag_update}
      #./updates/${update_file} || exit 1

      echo "Running ${update_file} . . ."
    done
  else
    # Up to date system updates
    echo "No backwards updates needed. Just update.sh. "
   # ./update.sh || exit 1
  fi

